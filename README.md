# Instaladores de Pacotes Lazarus para ACBr no Linux

Este repositório reúne scripts para preparar uma instalação do Lazarus no Linux com pacotes usados em projetos ACBr. A ideia é automatizar o trabalho repetitivo de baixar bibliotecas, compilar pacotes `.lpk`, registrar pacotes de design-time e recompilar a IDE Lazarus ao final de cada etapa.

O script principal é o `install.sh`, que abre um menu para instalar os pacotes básicos do Lazarus e bibliotecas auxiliares como Zeos, FortesReport-CE, fpStax, PowerPDF, Synapse e ACBr.

## Objetivo

Estes scripts foram criados para facilitar a montagem de um ambiente Lazarus/FPC voltado a desenvolvimento com ACBr em distribuições Linux, especialmente ambientes instalados com `fpcupdeluxe`.

Eles ajudam a:

- localizar a instalação do Lazarus e o executável `lazbuild`;
- baixar ou atualizar bibliotecas externas via Git ou SVN;
- compilar pacotes de runtime;
- instalar pacotes de design-time na IDE;
- recompilar o Lazarus para atualizar a paleta de componentes;
- escolher o widgetset da recompilação quando aplicável (`gtk`, `qt5` ou `qt6`);
- evitar a execução com a IDE Lazarus aberta, reduzindo risco de conflito durante a recompilação.

## Pacotes atendidos

- `lpkinstall-builtin.sh`: instala pacotes nativos úteis do Lazarus, como LazReport, FPReport, Online Package Manager e opcionais de docking.
- `lpkinstall-zeos.sh`: baixa/atualiza o ZeosLib, compila os pacotes de runtime e instala o pacote de design-time.
- `lpkinstall-frce.sh`: baixa/atualiza o FortesReport-CE, permite escolher a branch e instala o pacote no Lazarus.
- `lpkinstall-stax.sh`: baixa/atualiza e instala o fpStax.
- `lpkinstall-powerpdf.sh`: baixa/atualiza e instala o PowerPDF a partir do Lazarus CCR.
- `lpkinstall-synapse.sh`: baixa/atualiza e compila o pacote runtime Synapse.
- `lpkinstall-acbr.sh`: baixa/atualiza o ACBr, compila os pacotes selecionados, instala os pacotes de design-time e recompila a IDE.

## Requisitos

- Linux com Bash.
- Lazarus/FPC já instalados.
- `lazbuild` funcional dentro da pasta do Lazarus.
- A IDE Lazarus deve estar fechada antes de executar os instaladores.
- `git` para bibliotecas obtidas por Git.
- `svn` para ACBr e PowerPDF.
- `sudo` disponível para instalar dependências quando algum script solicitar.
- Em alguns pacotes do ACBr pode ser necessário `mingw-w64`, usado para disponibilizar o utilitário `windres`.

## Ambiente testado

Os scripts foram pensados e testados tendo como referência ambientes Linux compatíveis com Debian, como Debian, Ubuntu e Linux Mint.

Ambiente usado como base:

- Lazarus/FPC instalado pelo `fpcupdeluxe`;
- Lazarus em `~/fpcupdeluxe/lazarus`;
- configuração do Lazarus em `~/fpcupdeluxe/config_lazarus`, usada via parâmetro `--pcp`;
- Bash como shell;
- `git` e `svn` disponíveis no sistema;
- recompilação da IDE Lazarus com widgetset padrão ou, quando selecionado, `gtk`, `qt5` ou `qt6`.

Também há detecção parcial para instalações do Lazarus em `~/lazarus`. Se seu ambiente for diferente, por exemplo outra distribuição, Lazarus instalado por pacote da distribuição, outro caminho de instalação ou outro widgetset, revise os caminhos sugeridos pelos scripts antes de confirmar a instalação.

O uso mais comum pressupõe uma instalação do Lazarus em:

```bash
~/fpcupdeluxe/lazarus
```

Alguns scripts também detectam:

```bash
~/lazarus
```

Quando a instalação estiver em outro local, execute o script individual informando o caminho do Lazarus como primeiro parâmetro.

## Como usar

Clone o repositório e dê permissão de execução aos scripts:

```bash
git clone https://github.com/gladiston/acbr_install_linux.git
cd acbr_install_linux
chmod +x *.sh
```

Para usar o menu principal:

```bash
./install.sh
```

O menu permite instalar cada grupo separadamente ou executar a instalação completa. A instalação completa segue a ordem esperada para atender dependências antes de instalar o ACBr:

1. pacotes básicos do Lazarus;
2. Zeos;
3. FortesReport-CE;
4. fpStax;
5. PowerPDF;
6. Synapse;
7. ACBr.

Para executar apenas um instalador específico:

```bash
./lpkinstall-zeos.sh
./lpkinstall-frce.sh
./lpkinstall-acbr.sh
```

Se o Lazarus estiver fora do caminho padrão:

```bash
./lpkinstall-zeos.sh /caminho/para/lazarus
./lpkinstall-frce.sh /caminho/para/lazarus
./lpkinstall-acbr.sh /caminho/para/lazarus
```

## Observações importantes

- Não execute os scripts com a IDE Lazarus aberta.
- Não execute o instalador do ACBr como `root` ou com `sudo`; ele solicitará `sudo` apenas quando precisar instalar dependências do sistema.
- Os repositórios das bibliotecas são baixados dentro de `components` da própria instalação do Lazarus.
- O ACBr é mantido em `components/acbr`.
- O instalador do ACBr pergunta quais grupos de componentes devem ser incluídos, como comércio, financeiro, fiscal e relatórios.
- Os scripts recompilam a IDE Lazarus para que os componentes instalados apareçam na paleta.
- Ao final, abra novamente o Lazarus para conferir os pacotes instalados.

## Licença

Este projeto é licenciado sob a Licença MIT. Consulte o arquivo `LICENSE`.

## Autor

Gladiston Santana <gladiston.santana[at]gmail[dot]com>
