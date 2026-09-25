# Helheim

Tema escuro para IDEs da JetBrains, baseado em Islands Dark.

## Instalar

1. Baixe `helheim-VERSAO.zip` ou `helheim-VERSAO.jar` na página **Releases** do repositório.
2. Na IDE, abra **Settings → Plugins → engrenagem → Install Plugin from Disk…** e selecione o arquivo baixado, sem descompactar.
3. Reinicie a IDE se solicitado e selecione **Helheim** em **Settings → Appearance & Behavior → Appearance → Theme**.

Ao selecionar o tema Helheim, seu esquema de cores do editor também é aplicado, sem importar um `.icls` manualmente. O esquema incluído no plugin fica em `resources/theme/Helheim.xml` e preserva as cores e fontes do esquema original.

O plugin declara compatibilidade a partir do build `251` (2025.1). Para a aparência baseada em Islands Dark, use uma IDE que disponibilize esse tema base.

## Publicar um release

Cada push na branch `main` executa a Action **Release theme** e publica um release com o JAR e o ZIP:

```sh
git push origin main
```

A versão é `1.0.N`, onde `N` é o número da execução da Action (`github.run_number`). A tag `v1.0.N` é criada no commit exato do push. Essa versão é gravada no `plugin.xml` empacotado, sem alterar o arquivo fonte ou criar commits automáticos. Execuções que falharem podem deixar lacunas na numeração.

Reexecutar a mesma execução mantém a versão e substitui os anexos do release existente. Se a tag já apontar para outro commit, a publicação falha. Pushes próximos têm execuções independentes, sem cancelamento entre elas. Os releases são publicados com `--latest=false`, sem alterar a indicação de release mais recente quando execuções terminam fora de ordem.

## Empacotar localmente

Execute no PowerShell:

```powershell
./scripts/package-theme.ps1 -Version 1.0.1
```

Os arquivos são gerados em `dist/`. O JAR contém os recursos do plugin; o ZIP contém `helheim/lib/helheim-1.0.1.jar`.
