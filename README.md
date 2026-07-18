# dualboot-bluetooth-sync
Automação para sincronizar chaves de pareamento Bluetooth entre Windows e Linux/Steam Deck.
---

# 🎮 Bluetooth Dualboot Auto-Sync (Windows ➡️ Linux / Steam Deck)

Estou compartilhando esse script automatizado depois de descobrir o porre que é parear o bluetooth dualboot manualmente toda vez que despareava o meu controle.

Esse script resolve isso de forma **totalmente automatizada** em poucos segundos!

### 💡 Como ele funciona e o que ele faz:

* **Copia TODOS os pareamentos de uma vez:** Ele entra direto no Registro do Windows (`SYSTEM`), localiza o seu adaptador Bluetooth, captura os hexadecimais de **todos** os dispositivos que você tiver pareado lá e limpa a chave automaticamente.
* **Injeção Cirúrgica:** Ele converte os endereços MAC para o formato do Linux, vai até as pastas do BlueZ (`/var/lib/bluetooth`) e atualiza os arquivos `info` com as chaves certas. Se o dispositivo ainda não existir no Linux, ele se oferece para criar a pasta do zero para você.
* **Super Portátil:** Ele foi desenhado sob medida para as rotas do **Steam Deck (SteamOS)**, mas conta com um detector inteligente de dependências e gerenciadores de pacotes. Isso significa que ele vai tentar instalar o `chntpw` sozinho se você levá-lo para o **Ubuntu, Fedora, Arch, openSUSE**, etc.

---

### ⚠️ (LEIA ANTES DE RODAR!)

> **IMPORTANTE:** O script serve para copiar as chaves do Windows para o Linux. Por isso, **você precisa parear os seus dispositivos no Windows PRIMEIRO**.
> Se você resetar ou parear o controle de novo no Linux depois, a chave vai mudar e eles vão parar de sincronizar. A ordem é sempre: Parear no Windows ➡️ Rodar o Script no Linux.

---

### 🚀 Como Usar no Linux

1. Certifique-se de que a sua partição do Windows **está montada** (no Steam Deck, basta abrir o gerenciador de arquivos Dolphin e clicar no seu SSD/HD do Windows para montá-lo).
2. Baixe o script `sync-bluetooth.sh`
3. Abra as Propriedades do script `.sh`, vá na aba Permissões e marque a opção **"É executável"** (ou rode `chmod +x sync-bluetooth.sh` no terminal).
Ele vai abrir o terminal Konsole sozinho, pedir a sua senha de `sudo` e fazer todo o trabalho sozinho.

---

Sinta-se livre para clonar, abrir Issues ou mandar Pull Requests para melhorar o script! Não esqueça de deixar uma ⭐️ no repositório!
