
# Script de Instalação de Pacotes ACBr no Lazarus

## Visão Geral

Este script automatiza a instalação de pacotes ACBr no Lazarus e recompila a IDE do Lazarus. Ele garante que as dependências necessárias sejam instaladas, realiza a instalação dos pacotes ACBr e recompila a IDE do Lazarus, também pode recompilar utilizando `qt5`, basta ajustar dentro do script. O script é altamente comentado caso queira acertar alguns parametros à sua necessidade.

## Requisitos

- O pacote `mingw-w64` deve estar instalado. O script verifica isso e o instala automaticamente, caso não esteja presente.
- Uma instalação válida do Lazarus e dos pacotes ACBr.

## Uso

1. **Clonar o Repositório**:
   ```
   git clone https://github.com/gladiston/acbr_install_linux.git
   cd acbr_install_linux
   chmod a+x lpkinstall-acbr.sh
   ```

2. **Executar o Script**:

   O script requer dois parâmetros:
   - O primeiro parâmetro é o caminho para o diretório do Lazarus.
   - O segundo parâmetro é o caminho para o diretório dos pacotes ACBr.

   Exemplo:
   ```
   ./lpkinstall-acbr.sh /caminho/para/lazarus /caminho/para/acbr
   ```

   O script irá:
   - Verificar o pacote `mingw-w64` e instalá-lo, se necessário.
   - Criar um link simbólico para `/usr/bin/windres` se ele não existir.
   - Instalar todos os pacotes ACBr e recompilar a IDE do Lazarus utilizando o widgetset `qt5`.

## Scripts adicionais
Também foram adicionados os seguintes scripts:  
* lpkinstall-zeos.sh: Caso tenha baixado o zeos via git, use este script para executá-lo.
* lpkinstall-fortesreport-ce.sh: Caso tenha baixado o fortesreports-ce via git, use este script para executá-lo.
Uma sugestão para organização melhor de pasta de trabalho:
/work/pascal_lib
├── acbr
├── fortesreport-ce
└── zeoslib
(...)
lpkinstall-acbr.sh
lpkinstall-fortesreport-ce.sh
lpkinstall-zeos.sh

**DICA**: Voce pode baixar novos pacotes do tipo `lpk` via git na mesma pasta `pascal_lib`, então use o script `lpkinstall-zeos.sh` para adaptá-lo ao novo pacote, este script é autoexplicativo com uma lista de pacotes que devem ser compilados(runtime) e o que devem ser instalados(design). O script para instalação do `lpkinstall-fortesreport-ce.sh` também pode ser instalado, no entanto, ele é mais simples porque é um único pacote de design-time.  

## Notas

- Após a execução bem-sucedida do script, abra o Lazarus e vá até `Pacotes -> Instalar/Desinstalar Pacotes`, depois selecione e instale os pacotes ACBr no painel da direita.
- Novos pacotes possivelmente deverão ser acrescentados, até a data deste script tentei acrescentar todos os pacotes que não tinham como dependencia algo que não fosse opensource, por exemplo, pacotes dependentes do FastReport, RaveReports e ReportBuilder.

## Licença

Este projeto é licenciado sob a Licença MIT.

## Autor

- Gladiston Santana <gladiston.santana[at]gmail[dot]com>
