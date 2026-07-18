#!/bin/bash

# Se NÃO for root, tenta reexecutar o script pedindo privilégios graficamente ou via terminal
if [ "$EUID" -ne 0 ]; then
  echo "🔐 Solicitando privilégios de administrador..."

  # 1. Tenta usar o pkexec (funciona na maioria das distros modernas em modo gráfico)
  if [ -x "$(command -v pkexec)" ] && [ -n "$DISPLAY" ]; then
    pkexec "$0" "$@"
    exit $?
  # 2. Se o pkexec falhar ou não existir, tenta o kdialog (nativo do KDE/Steam Deck)
  elif [ -x "$(command -v kdialog)" ] && [ -n "$DISPLAY" ]; then
    kdialog --password "Este script precisa de privilégios root para acessar o registro do Windows. Digite sua senha:" | sudo -S "$0" "$@"
    exit $?
  # 3. Se estiver rodando puramente pelo terminal, avisa para usar o sudo clássico
  else
    echo "❌ Por favor, execute este script no terminal usando: sudo $0"
    exit 1
  fi
fi

echo "🔍 Verificando dependências..."

# Função para tentar instalar o chntpw baseado na distro
instalar_chntpw() {
    echo "⚙️ Tentando instalar 'chntpw' automaticamente..."
    if [ -x "$(command -v pacman)" ]; then
        # Arch Linux / SteamOS (modo leitura-escrita necessário se não for nativo)
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
        echo "❌ Não foi possível identificar o gerenciador de pacotes."
        echo "   Por favor, instale o pacote 'chntpw' manualmente e execute o script novamente."
        exit 1
    fi
}

# Verifica se o chntpw está instalado
if ! [ -x "$(command -v chntpw)" ]; then
    echo "⚠️ A ferramenta 'chntpw' não foi encontrada no sistema."
    read -p "🔄 Deseja que o script tente instalá-la agora? (s/n): " RESP_DEP
    if [[ "$RESP_DEP" =~ ^[Ss]$ ]]; then
        instalar_chntpw
        # Dupla checagem após a tentativa de instalação
        if ! [ -x "$(command -v chntpw)" ]; then
            echo "❌ Falha ao instalar 'chntpw'. Instale-o manualmente."
            exit 1
        fi
        echo "✅ 'chntpw' instalado com sucesso!"
    else
        echo "❌ O script não pode continuar sem o 'chntpw'."
        exit 1
    fi
else
    echo "✅ Dependência 'chntpw' detectada."
fi

echo -e "\n🔍 1. Detectando a partição do Windows..."
# Procura por uma pasta típica do Windows nas partições montadas pelo sistema
WIN_PATH=$(find /run/media/ /media/ /mnt/ -type d -path "*/Windows/System32/config" 2>/dev/null | head -n 1)

if [ -z "$WIN_PATH" ]; then
    echo "❌ Erro: Registro do Windows não encontrado."
    echo "   Certifique-se de que a partição do Windows está montada em /run/media, /media ou /mnt."
    exit 1
fi
echo "✅ Windows encontrado em: $WIN_PATH"

echo -e "\n🔍 2. Verificando adaptadores Bluetooth no Linux..."
LINUX_BT_DIR="/var/lib/bluetooth"

if [ ! -d "$LINUX_BT_DIR" ]; then
    echo "❌ O diretório do BlueZ ($LINUX_BT_DIR) não existe. O Bluetooth está ativo nessa distro?"
    exit 1
fi

ADAPTADORES=($(ls $LINUX_BT_DIR | grep -E '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}'))

if [ ${#ADAPTADORES[@]} -eq 0 ]; then
    echo "❌ Nenhum adaptador Bluetooth pareado encontrado no Linux."
    exit 1
elif [ ${#ADAPTADORES[@]} -gt 1 ]; then
    echo "⚠️ Múltiplos adaptadores encontrados. Escolha qual deseja usar:"
    select ADAPT_ESCOLHIDO in "${ADAPTADORES[@]}"; do
        if [ -n "$ADAPT_ESCOLHIDO" ]; then
            break
        fi
    done
else
    ADAPT_ESCOLHIDO=${ADAPTADORES[0]}
    echo "✅ Adaptador único detectado: $ADAPT_ESCOLHIDO"
fi

# Converte o MAC do adaptador para o formato do Windows (tudo minúsculo e sem ":")
WIN_ADAPT_MAC=$(echo "$ADAPT_ESCOLHIDO" | tr '[:upper:]' '[:lower:]' | tr -d ':')

echo -e "\n🔍 3. Extraindo chaves do Registro do Windows..."
REG_KEY="ControlSet001\\Services\\BTHPORT\\Parameters\\Keys\\$WIN_ADAPT_MAC"

# Executa o chntpw de forma não-interativa para listar os dispositivos e chaves
CHNP_OUT=$(echo -e "cd $REG_KEY\nls\nq" | chntpw -e "$WIN_PATH/SYSTEM" 2>/dev/null)

# Extrai os MACs dos dispositivos pareados no Windows
DISPOSITIVOS=$(echo "$CHNP_OUT" | grep "REG_BINARY" | awk -F'<' '{print $2}' | awk -F'>' '{print $1}')

if [ -z "$DISPOSITIVOS" ]; then
    echo "❌ Nenhum dispositivo pareado encontrado no Windows para o adaptador $ADAPT_ESCOLHIDO."
    exit 1
fi

echo "📌 Dispositivos encontrados no Windows:"
for DISP in $DISPOSITIVOS; do
    # Formata o MAC do dispositivo para o padrão Linux (XX:XX:XX:XX:XX:XX)
    LINUX_DISP_MAC=$(echo "$DISP" | tr '[:lower:]' '[:upper:]' | sed 's/../&:/g;s/:$//')

    echo "⚙️ Processando: $LINUX_DISP_MAC"

    # Captura a linha hexadecimal da Link Key
    HEX_LINE=$(echo -e "cd $REG_KEY\nhex $DISP\nq" | chntpw -e "$WIN_PATH/SYSTEM" 2>/dev/null | grep -A 1 "Value <$DISP>" | tail -n 1)

    # Limpa o Hexadecimal retirando cabeçalhos e espaços
    LINK_KEY=$(echo "$HEX_LINE" | awk -F' ' '{print $2$3$4$5$6$7$8$9$10$11$12$13$14$15$16$17}' | tr '[:lower:]' '[:upper:]')

    if [ -z "$LINK_KEY" ] || [ ${#LINK_KEY} -ne 32 ]; then
        echo "  ❌ Não foi possível extrair uma Link Key válida para $LINUX_DISP_MAC."
        continue
    fi

    TARGET_DIR="$LINUX_BT_DIR/$ADAPT_ESCOLHIDO/$LINUX_DISP_MAC"

    echo "📂 Verificando pasta do dispositivo no Linux..."
    if [ ! -d "$TARGET_DIR" ]; then
        echo "  ⚠️ Pasta $TARGET_DIR não existe no Linux (Dispositivo pareado no Windows, mas não no Linux)."
        read -p "  Deseja criar a pasta e gerar o arquivo 'info' do zero? (s/n): " RESP_PASTA
        if [[ "$RESP_PASTA" =~ ^[Ss]$ ]]; then
            mkdir -p "$TARGET_DIR"
            echo -e "[General]\nName=Synced Device\n\n[LinkKey]\nKey=$LINK_KEY\nType=4\nPINLength=0" > "$TARGET_DIR/info"
            echo "  ✅ Arquivo info criado e chave injetada!"
        else
            echo "  ⏭️ Pulando dispositivo."
            continue
        fi
    else
        INFO_FILE="$TARGET_DIR/info"

        # Injeta ou atualiza a LinkKey de forma limpa no arquivo 'info'
        if grep -q "\[LinkKey\]" "$INFO_FILE"; then
            sed -i "/\[LinkKey\]/,/^$/ s/Key=.*/Key=$LINK_KEY/" "$INFO_FILE"
        else
            echo -e "\n[LinkKey]\nKey=$LINK_KEY\nType=4\nPINLength=0" >> "$INFO_FILE"
        fi
        echo "  ✅ LinkKey atualizada com sucesso!"
    fi
done

echo -e "\n🔄 5. Reiniciando o serviço de Bluetooth do Linux..."
if [ -x "$(command -v systemctl)" ]; then
    systemctl restart bluetooth
    echo "🎉 Concluído! Serviço Bluetooth reiniciado via systemctl."
elif [ -x "$(command -v service)" ]; then
    service bluetooth restart
    echo "🎉 Concluído! Serviço Bluetooth reiniciado via service."
else
    echo "⚠️ Não foi possível reiniciar o Bluetooth automaticamente. Reinicie o serviço ou o PC manualmente."
fi
