# Instaladores de Pacotes Lazarus para ACBr no Linux

Este repositório reúne scripts para preparar uma instalação do Lazarus no Linux com pacotes usados em projetos ACBr. A ideia é automatizar o trabalho repetitivo de baixar bibliotecas, compilar pacotes `.lpk`, registrar pacotes de design-time e recompilar a IDE Lazarus ao final de cada etapa.

O script principal é o `install.sh`, que abre um menu para instalar os pacotes básicos do Lazarus e bibliotecas auxiliares como Zeos, FortesReport-CE, fpStax, PowerPDF e ACBr (Synapse vem embutido no ACBr).

## Objetivo

Estes scripts foram criados para facilitar a montagem de um ambiente Lazarus/FPC voltado a desenvolvimento com ACBr em distribuições Linux, especialmente ambientes instalados com `fpcupdeluxe`.

Eles ajudam a:

- localizar a instalação do Lazarus e o executável `lazbuild`;
- baixar ou atualizar bibliotecas externas via Git, SVN ou OPM (`packages.lazarus-ide.org`);
- compilar pacotes de runtime;
- instalar pacotes de design-time na IDE;
- recompilar o Lazarus para atualizar a paleta de componentes;
- escolher o widgetset da recompilação quando aplicável (`gtk`, `qt5` ou `qt6`);
- evitar a execução com a IDE Lazarus aberta, reduzindo risco de conflito durante a recompilação.

## Pacotes atendidos

- `lpkinstall-builtin.sh`: pacotes nativos (LazReport, FPReport, OPM, memdslaz, datetimectrlsdsgn, iconfinder, todolistlaz, lazdatadict) + docking (AnchorDocking + DockedFormEditor).
- `lpkinstall-docking.sh`: docking da IDE (AnchorDocking + DockedFormEditor); útil se quiser só o docking sem os demais básicos.
- `download-lazideexportsettings.sh`: baixa o utilitário [lazIdeExportSettings](https://github.com/DomingoGP/lazIdeExportSettings) em Documentos; instalação/compilação opcional + atalho na Área de Trabalho.
- `lpkinstall-ideajustes.sh`: reaplica o perfil pessoal `ide-ajustes-editor` (fonte, atalhos, Code Tools, Desktops, etc.) no PCP.
- `lpkinstall-curadoria.sh`: curadoria do editor (14 pacotes OPM incl. HtmlViewer + nativos memdslaz/datetimectrls); após extrair, instala todos os `.lpk` runtime/design.
- `lpkinstall-zeos.sh`: ZeosLib (Git).
- `lpkinstall-frce.sh`: FortesReport-CE (Git).
- `lpkinstall-stax.sh`: fpStax (OPM `FpStax.zip`).
- `lpkinstall-powerpdf.sh`: PowerPDF (OPM `PowerPDF.zip`).
- `lpkinstall-acbr.sh`: ACBr (SVN; fallback Git `MirrorProjetoACBr`); Synapse embutido (`synalist`).

## Fontes de download

| Pacote | Fonte principal | Fallback |
|--------|-----------------|----------|
| ACBr | SVN SourceForge (`trunk2`) | Git `https://github.com/MirrorProjetoACBr/ACBr.git` |
| Synapse | Embutido no ACBr (`synalist`) | — |
| FortesReport-CE | Git | — |
| Zeos | Git | — |
| PowerPDF | OPM `PowerPDF.zip` | — |
| Stax | OPM `FpStax.zip` | — |
| Curadoria | OPM (14 pacotes) + nativos Lazarus | — |

## Requisitos

- Linux com Bash.
- Lazarus/FPC já instalados.
- `lazbuild` funcional dentro da pasta do Lazarus.
- A IDE Lazarus deve estar fechada antes de executar os instaladores.
- `git` (Zeos, Fortes, fallback do ACBr) e/ou `svn` (ACBr).
- `curl` e `unzip` para pacotes OPM.
- Rede para `https://packages.lazarus-ide.org/` (Stax, PowerPDF, curadoria).
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

Também há detecção parcial para instalações do Lazarus em `~/lazarus`. Se seu ambiente for diferente, revise os caminhos sugeridos pelos scripts antes de confirmar a instalação.

## Como usar

```bash
git clone https://github.com/gladiston/acbr_install_linux.git
cd acbr_install_linux
chmod +x *.sh
./install.sh
```

Menu:

1. Pacotes básicos
2. Zeos
3. Fortes CE
4. Stax
5. PowerPDF
6. ACBr (inclui Synapse embutido)
7. Instalar pacotes selecionados pelo curador (OPM)
8. Instalar tudo (nessa ordem)

9. Docking
A. Reperguntar docking no próximo start do Lazarus
B. Download do lazIdeExportSettings
C. Ajustes do curador na IDE
X. Sair

A instalação completa inclui a curadoria e segue a ordem de dependências antes do ACBr.

Para um instalador específico:

```bash
./lpkinstall-zeos.sh
./lpkinstall-curadoria.sh
./lpkinstall-acbr.sh /caminho/para/lazarus
```

## Observações importantes

- Não execute os scripts com a IDE Lazarus aberta.
- Não execute o instalador do ACBr como `root` ou com `sudo`; ele solicitará `sudo` apenas quando precisar instalar dependências do sistema.
- Os repositórios das bibliotecas são baixados dentro de `components` da própria instalação do Lazarus.
- O ACBr é mantido em `components/acbr`.
- O instalador do ACBr faz todas as perguntas primeiro (grupos, widgetset, atualizar ou não), confirma o resumo e só então baixa/instala sem novas perguntas.
- Os scripts recompilam a IDE Lazarus para que os componentes instalados apareçam na paleta.
- Ao final, abra novamente o Lazarus para conferir os pacotes instalados.

## Licença

Este projeto é licenciado sob a Licença MIT. Consulte o arquivo `LICENSE`.

## Autor

Gladiston Santana <gladiston.santana[at]gmail[dot]com>
