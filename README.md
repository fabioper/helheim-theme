# Helheim

Tema escuro para IDEs da JetBrains, baseado em Islands Dark.

## Instalar

1. Baixe `helheim-VERSAO.zip` ou `helheim-VERSAO.jar` na página **Releases** do repositório.
2. Na IDE, abra **Settings → Plugins → engrenagem → Install Plugin from Disk…** e selecione o arquivo baixado, sem descompactar.
3. Reinicie a IDE se solicitado e selecione **Helheim** em **Settings → Appearance & Behavior → Appearance → Theme**.

Ao selecionar o tema Helheim, seu esquema de cores do editor também é aplicado, sem importar um `.icls` manualmente. O esquema incluído no plugin fica em `resources/helheim.xml` e preserva as cores e fontes do esquema original.

O `plugin.xml` registra esse recurso como `bundledColorScheme` com identificador `Helheim`. O campo `editorScheme` do tema referencia esse identificador, que deve corresponder ao nome dentro do XML. O empacotamento valida essa associação antes de gerar os arquivos.

O plugin declara compatibilidade a partir do build `251` (2025.1). Para a aparência baseada em Islands Dark, use uma IDE que disponibilize esse tema base.

## Publicar um release

Cada push na branch `main` executa a Action **Release theme** no Ubuntu 24.04, valida os scripts Bash e os pacotes e publica um release com o JAR e o ZIP:

```sh
git push origin main
```

A versão é `1.0.N`, onde `N` é o número da execução da Action (`github.run_number`). A tag `v1.0.N` é criada no commit exato do push. Essa versão é gravada no `plugin.xml` empacotado, sem alterar o arquivo fonte ou criar commits automáticos. Execuções que falharem podem deixar lacunas na numeração.

Reexecutar a mesma execução mantém a versão e substitui os anexos do release existente. Se a tag já apontar para outro commit, a publicação falha. Pushes próximos têm execuções independentes, sem cancelamento entre elas. Os releases são publicados com `--latest=false`, sem alterar a indicação de release mais recente quando execuções terminam fora de ordem.

## Empacotar localmente

Para editar o tema no IntelliJ IDEA, habilite **Plugin DevKit** e configure um **IntelliJ Platform Plugin SDK** em **File → Project Structure → SDKs**, apontando para a instalação da IDE. Para a plataforma 2026.2, selecione Java 25 como plataforma Java interna e `out/idea-sandbox` como sandbox. Selecione esse SDK no projeto; o módulo herda o SDK do projeto. Um Java SDK isolado não fornece as definições das extensões usadas no `plugin.xml`.

As configurações do SDK e seus caminhos são locais e não são versionados. O workflow Bash continua independente desse SDK.

Execute no Ubuntu (no Windows, use Ubuntu via WSL). Instale as dependências:

```bash
sudo apt-get update
sudo apt-get install -y zip unzip jq xmlstarlet shellcheck
bash scripts/package-theme.sh --version 1.0.1
```

Os arquivos são gerados em `dist/`. O JAR contém os recursos do plugin; o ZIP contém `helheim/lib/helheim-1.0.1.jar`.

Para validar os scripts e os cenários de publicação sem criar releases reais:

```bash
for script in scripts/*.sh; do bash -n "$script"; done
shellcheck scripts/*.sh
bash scripts/test-release.sh
```

A publicação usa Git e GitHub CLI (`gh`), disponíveis no runner, com `GH_TOKEN` e `GH_REPO` configurados pelo workflow. Os scripts PowerShell foram substituídos pelos scripts Bash.
