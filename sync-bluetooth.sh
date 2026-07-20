#!/bin/bash

# If NOT root, try to re-execute the script requesting elevated privileges via GUI or terminal
if [ "$EUID" -ne 0 ]; then
  echo "🔐 Requesting administrator privileges..."

  # 1. Try pkexec (works on most modern distros in graphical mode)
  if [ -x "$(command -v pkexec)" ] && [ -n "$DISPLAY" ]; then
    pkexec "$0" "$@"
    exit $?
  # 2. If pkexec fails or doesn't exist, try kdialog (native to KDE/Steam Deck)
  elif [ -x "$(command -v kdialog)" ] && [ -n "$DISPLAY" ]; then
    kdialog --password "This script needs root privileges to access the Windows registry. Enter your password:" | sudo -S "$0" "$@"
    exit $?
  # 3. If running purely via terminal, prompt the user to use classic sudo
  else
    echo "❌ Please run this script in the terminal using: sudo $0"
    exit 1
  fi
fi

echo "🔍 Checking dependencies..."

# Function to attempt installing chntpw based on the distro
install_chntpw() {
    echo "⚙️ Attempting to install 'chntpw' automatically..."
    if [ -x "$(command -v pacman)" ]; then
        # Arch Linux / SteamOS (Read-only filesystem warning)
        if command -v steamos-readonly &>/dev/null; then
            echo "ℹ️ SteamOS detected. Temporarily disabling read-only protection..."
            steamos-readonly disable
        fi
        pacman -Sy --noconfirm chntpw
    elif [ -x "$(command -v apt-get)" ]; then
        # Debian / Ubuntu / Mint
        apt-get update && apt-get install -y chntpw
    elif [ -x "$(command -v dnf)" ]; then
        # Fedora / RHEL
        dnf install -y chntpw
    elif [ -x "$(command -v zypper)" ]; then
        # openSUSE
        zypper install -y chntpw
    else
        echo "❌ Could not identify the package manager."
        echo "   Please install the 'chntpw' package manually and run the script again."
        exit 1
    fi
}

# Check if chntpw is installed
if ! [ -x "$(command -v chntpw)" ]; then
    echo "⚠️ The 'chntpw' tool was not found on your system."
    read -p "🔄 Would you like the script to try installing it now? (y/n): " RESP_DEP
    if [[ "$RESP_DEP" =~ ^[YySs]$ ]]; then
        install_chntpw
        # Double-check after installation attempt
        if ! [ -x "$(command -v chntpw)" ]; then
            echo "❌ Failed to install 'chntpw'. Please install it manually."
            exit 1
        fi
        echo "✅ 'chntpw' installed successfully!"
    else
        echo "❌ The script cannot continue without 'chntpw'."
        exit 1
    fi
else
    echo "✅ Dependency 'chntpw' detected."
fi

echo -e "\n🔍 1. Detecting Windows partition..."
# Look for a typical Windows directory in mounted partitions
WIN_PATH=$(find /run/media/ /media/ /mnt/ -type d -path "*/Windows/System32/config" 2>/dev/null | head -n 1)

if [ -z "$WIN_PATH" ]; then
    echo "❌ Error: Windows Registry not found."
    echo "   Make sure your Windows partition is mounted in /run/media, /media, or /mnt."
    exit 1
fi
echo "✅ Windows found at: $WIN_PATH"

echo -e "\n🔍 2. Checking Bluetooth adapters in Linux..."
LINUX_BT_DIR="/var/lib/bluetooth"

if [ ! -d "$LINUX_BT_DIR" ]; then
    echo "❌ BlueZ directory ($LINUX_BT_DIR) does not exist. Is Bluetooth enabled on this distro?"
    exit 1
fi

ADAPTERS=($(ls $LINUX_BT_DIR | grep -E '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}'))

if [ ${#ADAPTERS[@]} -eq 0 ]; then
    echo "❌ No paired Bluetooth adapters found in Linux."
    exit 1
elif [ ${#ADAPTERS[@]} -gt 1 ]; then
    echo "⚠️ Multiple adapters found. Select the one you want to use:"
    select SELECTED_ADAPTER in "${ADAPTERS[@]}"; do
        if [ -n "$SELECTED_ADAPTER" ]; then
            break
        fi
    done
else
    SELECTED_ADAPTER=${ADAPTERS[0]}
    echo "✅ Single adapter detected: $SELECTED_ADAPTER"
fi

# Convert adapter MAC to Windows format (lowercase and no ":")
WIN_ADAPT_MAC=$(echo "$SELECTED_ADAPTER" | tr '[:upper:]' '[:lower:]' | tr -d ':')

echo -e "\n🔍 3. Extracting keys from Windows Registry..."
REG_KEY="ControlSet001\\Services\\BTHPORT\\Parameters\\Keys\\$WIN_ADAPT_MAC"

# Run chntpw non-interactively to list devices and keys
CHNP_OUT=$(echo -e "cd $REG_KEY\nls\nq" | chntpw -e "$WIN_PATH/SYSTEM" 2>/dev/null)

# Extract MACs of devices paired in Windows
DEVICES=$(echo "$CHNP_OUT" | grep "REG_BINARY" | awk -F'<' '{print $2}' | awk -F'>' '{print $1}')

if [ -z "$DEVICES" ]; then
    echo "❌ No paired devices found in Windows for adapter $SELECTED_ADAPTER."
    exit 1
fi

echo "📌 Devices found in Windows:"
for DEV in $DEVICES; do
    # Format device MAC to Linux standard (XX:XX:XX:XX:XX:XX)
    LINUX_DEV_MAC=$(echo "$DEV" | tr '[:lower:]' '[:upper:]' | sed 's/../&:/g;s/:$//')

    echo "⚙️ Processing: $LINUX_DEV_MAC"

    # Capture hex line of the Link Key
    HEX_LINE=$(echo -e "cd $REG_KEY\nhex $DEV\nq" | chntpw -e "$WIN_PATH/SYSTEM" 2>/dev/null | grep -A 1 "Value <$DEV>" | tail -n 1)

    # Clean Hexadecimal removing headers and spaces
    LINK_KEY=$(echo "$HEX_LINE" | awk -F' ' '{print $2$3$4$5$6$7$8$9$10$11$12$13$14$15$16$17}' | tr '[:lower:]' '[:upper:]')

    if [ -z "$LINK_KEY" ] || [ ${#LINK_KEY} -ne 32 ]; then
        echo "   ❌ Could not extract a valid Link Key for $LINUX_DEV_MAC."
        continue
    fi

    TARGET_DIR="$LINUX_BT_DIR/$SELECTED_ADAPTER/$LINUX_DEV_MAC"

    echo "📂 Checking device folder in Linux..."
    if [ ! -d "$TARGET_DIR" ]; then
        echo "   ⚠️ Folder $TARGET_DIR does not exist in Linux (Device paired in Windows, but not in Linux)."
        read -p "   Do you want to create the folder and generate the 'info' file from scratch? (y/n): " RESP_FOLDER
        if [[ "$RESP_FOLDER" =~ ^[YySs]$ ]]; then
            mkdir -p "$TARGET_DIR"
            echo -e "[General]\nName=Synced Device\n\n[LinkKey]\nKey=$LINK_KEY\nType=4\nPINLength=0" > "$TARGET_DIR/info"
            chmod 600 "$TARGET_DIR/info"
            echo "   ✅ 'info' file created and key injected!"
        else
            echo "   ⏭️ Skipping device."
            continue
        fi
    else
        INFO_FILE="$TARGET_DIR/info"

        # Inject or update LinkKey cleanly in the 'info' file
        if grep -q "\[LinkKey\]" "$INFO_FILE"; then
            sed -i "/\[LinkKey\]/,/^$/ s/Key=.*/Key=$LINK_KEY/" "$INFO_FILE"
        else
            echo -e "\n[LinkKey]\nKey=$LINK_KEY\nType=4\nPINLength=0" >> "$INFO_FILE"
        fi
        chmod 600 "$INFO_FILE"
        echo "   ✅ LinkKey updated successfully!"
    fi
done

echo -e "\n🔄 5. Restarting Linux Bluetooth service..."
if [ -x "$(command -v systemctl)" ]; then
    systemctl restart bluetooth
    echo "🎉 Done! Bluetooth service restarted via systemctl."
elif [ -x "$(command -v service)" ]; then
    service bluetooth restart
    echo "🎉 Done! Bluetooth service restarted via service."
else
    echo "⚠️ Could not restart Bluetooth automatically. Please restart the service or your PC manually."
fi
