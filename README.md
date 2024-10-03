
# Script de Instalação de Pacotes ACBr no Lazarus

## Visão Geral

Este script automatiza a instalação de pacotes ACBr no Lazarus e recompila a IDE do Lazarus. Ele garante que as dependências necessárias sejam instaladas, realiza a instalação dos pacotes ACBr e recompila a IDE do Lazarus utilizando `qt5` como widgetset.

## Requisitos

- O pacote `mingw-w64` deve estar instalado. O script verifica isso e o instala automaticamente, caso não esteja presente.
- Uma instalação válida do Lazarus e dos pacotes ACBr.

## Uso

1. **Clonar o Repositório**:
   ```
   git clone https://github.com/gladiston/acbr_install_linux.git
   cd acbr_install_linux
   chmod a+x acbr_install.sh
   ```

2. **Executar o Script**:

   O script requer dois parâmetros:
   - O primeiro parâmetro é o caminho para o diretório do Lazarus.
   - O segundo parâmetro é o caminho para o diretório dos pacotes ACBr.

   Exemplo:
   ```
   ./acbr_install.sh /caminho/para/lazarus /caminho/para/acbr
   ```

   O script irá:
   - Verificar o pacote `mingw-w64` e instalá-lo, se necessário.
   - Criar um link simbólico para `/usr/bin/windres` se ele não existir.
   - Instalar todos os pacotes ACBr e recompilar a IDE do Lazarus utilizando o widgetset `qt5`.

## Notas

- Após a execução bem-sucedida do script, abra o Lazarus e vá até `Pacotes -> Instalar/Desinstalar Pacotes`, depois selecione e instale os pacotes ACBr no painel da direita.
- O script utiliza `eval` para executar comandos com tratamento adequado para argumentos que contêm espaços.

## Licença

Este projeto é licenciado sob a Licença MIT.

## Autor

- Gladiston Santana <gladiston.santana[at]gmail[dot]com>
