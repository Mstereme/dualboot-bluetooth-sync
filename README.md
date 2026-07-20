# dualboot-bluetooth-sync
Automation to sync Bluetooth pairing keys between Windows and Linux/Steam Deck.

---

```bash
if [ -d ~/dualboot-bluetooth-sync ]; then cd ~/dualboot-bluetooth-sync && git fetch origin && git reset --hard origin/main; else git clone https://github.com/Mstereme/dualboot-bluetooth-sync.git ~/dualboot-bluetooth-sync; fi && chmod +x ~/dualboot-bluetooth-sync/sync-bluetooth.sh && sudo ~/dualboot-bluetooth-sync/sync-bluetooth.sh
```
---

🎮 Bluetooth Dualboot Auto-Sync (Windows ➡️ Linux / Steam Deck)

I'm sharing this automated script after discovering what a total hassle it is to manually pair Bluetooth on dual-boot every time my controller would unpair.

This script fixes that in a fully automated way in just a few seconds!

💡 How it works and what it does:

* Copies ALL pairings at once: It accesses the Windows Registry (SYSTEM) directly, locates your Bluetooth adapter, extracts the hex keys for all your paired devices, and automatically cleans up the Link Keys.

* Surgical Injection: It converts MAC addresses to the Linux format, navigates to the BlueZ folders (/var/lib/bluetooth), and updates the info files with the correct keys. If a device doesn't exist on Linux yet, it offers to create the directory structure from scratch for you.

* Portability: It was custom-designed with Steam Deck (SteamOS) paths in mind, but features a smart dependency and package manager detector. This means it will automatically try to install chntpw if you run it on Ubuntu, Fedora, Arch, openSUSE, etc.

---

⚠️ (READ BEFORE RUNNING!)

IMPORTANT: This script copies keys from Windows to Linux. Therefore, you MUST pair your devices in Windows FIRST.
If you reset or pair the controller again in Linux afterward, the key will change and they will stop syncing. The order is always: Pair in Windows ➡️ Run Script in Linux.

---

🚀 How to Use on Linux

Make sure your Windows partition is mounted (on Steam Deck, just open the Dolphin file manager and click on your Windows drive to mount it).

Paste the command above into the terminal to clone and execute it automatically.

Feel free to clone, open Issues, or submit Pull Requests to improve the script! Don't forget to leave a ⭐️ on the repository!
