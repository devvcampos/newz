# Newz

Ferramenta visual em Luau para diagnóstico autorizado de jogadores em um ambiente Roblox controlado.

## Estado atual

O Newz rastreia jogadores por `Players.Player.Character`, com suporte a personagens R6/R15 e a experiências com `Workspace.StreamingEnabled` ativo. O ESP mantém o jogador registrado mesmo quando partes físicas são temporariamente removidas do cliente pelo streaming e volta a renderizar quando elas reaparecem.

Recursos atuais:

- box `Corner` ou `Full`;
- nome;
- vida;
- distância;
- arma equipada;
- checagem de visibilidade;
- filtro por time;
- cores configuráveis para visível, oculto e texto;
- cor dinâmica de vida.

A identificação de arma equipada usa um `Tool` diretamente no `Player.Character` com `Type == "Gun"` ou `GunBound == true`.

## Estrutura

```text
newz/
├─ src/
│  ├─ Main.lua
│  ├─ Config.lua
│  ├─ Ui.lua
│  └─ Modules/
│     └─ ESP.lua
├─ vendor/
│  └─ NeverLose.lua
├─ scripts/
│  ├─ build.py
│  └─ check.py
├─ dist/
│  └─ newz.lua
├─ THIRD_PARTY_NOTICES.md
└─ README.md
```

## Carregamento de desenvolvimento

`src/Main.lua` resolve a branch `main` para um SHA de commit uma única vez e carrega `Config`, `ESP`, `Ui` e `NeverLose` usando esse mesmo snapshot imutável. Isso evita misturar arquivos de commits diferentes durante uma execução.

Também é possível fornecer explicitamente um commit ou tag:

```lua
getgenv().NEWZ_SOURCE_REF = "<commit-ou-tag>"
```

Para distribuição, prefira `dist/newz.lua`.

## Build

O build gera um artefato único e autocontido. Ele incorpora `Main`, `Config`, `ESP`, `Ui` e `vendor/NeverLose.lua`, portanto a execução do `dist` não depende de downloads mutáveis em runtime.

```powershell
python scripts/build.py
python scripts/check.py --require-dist
```

Depois do build, `dist/newz.lua` pode ser versionado como artefato de distribuição.

## Verificação

`scripts/check.py` valida arquivos obrigatórios, procura configurações antigas conhecidas e, quando `luau-analyze` está instalado no `PATH`, executa a análise estática de `src/`.

## Configuração de runtime

`Config.Runtime` contém apenas configurações efetivamente usadas pelo tracker atual:

- `UpdateFrequency`: frequência de atualização visual;
- `VisibilityInterval`: intervalo mínimo entre raycasts de visibilidade por jogador.

## Interface

A interface usa a NeverLose vendorizada em `vendor/NeverLose.lua`. `UI.Init` recebe essa dependência explicitamente e executa a criação da janela/controles dentro de uma transação com cleanup. Se a construção da UI falhar depois que a biblioteca estiver disponível, o código tenta cancelar threads, desconectar recursos temporários e executar `NeverLose:Unload()` antes de propagar o erro.

## Terceiros

A NeverLose vendorizada declara licença MIT em seu cabeçalho. Consulte `THIRD_PARTY_NOTICES.md` para atribuição e texto da licença.

## Uso

Este projeto deve ser usado somente em experiências, ambientes e servidores nos quais o operador tenha autorização para desenvolvimento, diagnóstico ou teste.
