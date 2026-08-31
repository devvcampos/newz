# Newz

Ferramenta visual em Luau para diagnóstico autorizado de jogadores e entidades em um ambiente Roblox controlado.

## Estado atual

A versão `0.4.1` mantém a arquitetura modular, otimiza os hot paths entre módulos e adiciona visualização event-driven do loot existente em cadáveres.

O tracker de jogadores continua baseado em `Players.Player.Character`, com suporte a R6/R15 e `Workspace.StreamingEnabled`. O tracker de cadáveres continua observando `Workspace.Corpses` por eventos.

Recursos atuais:

- Player ESP com box `Corner` ou `Full`;
- nome, vida, arma equipada e distância;
- visibility check e team check;
- Corpse ESP com box, nome, distância e loot opcional;
- profiler em tempo real;
- projection engine calibrada por frame;
- scheduler round-robin a 30 Hz por entidade;
- build reproduzível em `dist/newz.lua`.

A identificação da arma equipada continua usando um `Tool` diretamente no `Player.Character` com `Type == "Gun"` ou `GunBound == true`.

## Arquitetura

```text
newz/
├─ src/
│  ├─ Main.lua
│  ├─ Config.lua
│  ├─ Ui.lua
│  │
│  ├─ Core/
│  │  ├─ Profiler.lua
│  │  ├─ Bounds.lua
│  │  ├─ Visuals.lua
│  │  └─ Scheduler.lua
│  │
│  └─ Modules/
│     ├─ PlayerESP.lua
│     ├─ CorpseESP.lua
│     ├─ LootESP.lua
│     └─ ESP.lua
│
├─ vendor/
│  └─ NeverLose.lua
│
├─ scripts/
│  ├─ build.py
│  └─ check.py
│
├─ dist/
│  └─ newz.lua
│
├─ THIRD_PARTY_NOTICES.md
└─ README.md
```

### Core

`Bounds.lua` concentra cache de partes corporais, root fallback de cadáveres e a projection engine otimizada.

`Visuals.lua` concentra criação, atualização, ocultação e destruição de boxes/textos.

`Scheduler.lua` implementa o round-robin compartilhado usado pelos trackers.

`Profiler.lua` mede custo CPU-side do Newz, incluindo `Newz.Render`, bounds, visibility e visuals.

### Modules

`PlayerESP.lua` é responsável somente pelo lifecycle e renderização dos jogadores, incluindo streaming, humanoid, arma equipada e visibility.

`CorpseESP.lua` é responsável somente pelo lifecycle e renderização de `Workspace.Corpses`.

`LootESP.lua` observa `Loot_Corpse` somente quando o loot está habilitado e o cadáver está ativo no tracker visual. A lista é atualizada por eventos `ChildAdded`/`ChildRemoved`, sem varredura do Workspace por frame.

`ESP.lua` virou um facade/orquestrador. Ele cria o `ScreenGui`, instancia o Core, inicializa Player/Corpse ESP e coordena o `RenderStepped`.

## Hot-path optimization

PlayerESP, CorpseESP e o facade fazem binding local das funções usadas nos loops críticos. O scheduler reutiliza callbacks estáveis em vez de criar closures a cada frame e a posição da câmera é calculada uma vez por `Step`.

A projection engine também acumula os oito cantos de cada parte usando variáveis locais antes de escrever o resultado de volta no estado de bounds.

## Corpse Loot

O loot é opcional e fica desligado por padrão. Na aba `Corpses`, ative `Loot` e escolha `Loot Max Items`.

O tracker usa por padrão:

```text
Workspace.Corpses
└─ <Corpse>
   └─ Loot_Corpse
      ├─ <item>
      ├─ <item>
      └─ Corpse   # marcador ignorado
```

Itens repetidos são agrupados (`2x Item`) e o excedente é resumido como `+N items`.

## Projection Engine

A projection engine mantém os mesmos oito cantos por parte usados originalmente, mas evita executar `WorldToViewportPoint` para cada canto.

A câmera é calibrada uma vez por frame com três projeções nativas. Os cantos são então projetados em camera-space. Um caminho legado continua disponível automaticamente para estados de câmera inválidos.

No profiling que motivou essa arquitetura, o custo médio de bounds caiu aproximadamente de `0.33 ms` para `0.04 ms` por atualização de jogador, mantendo o comportamento visual.

## Carregamento de desenvolvimento

`src/Main.lua` resolve `main` para um SHA de commit uma única vez e carrega todos os módulos usando o mesmo snapshot imutável.

Também é possível fornecer explicitamente um commit ou tag:

```lua
getgenv().NEWZ_SOURCE_REF = "<commit-ou-tag>"
```

Para distribuição, prefira `dist/newz.lua`.

## Build

```powershell
python scripts/build.py
python scripts/check.py --require-dist
```

O build incorpora Main, Config, Core, Modules, UI e NeverLose em um artefato autocontido.

## Profiler

Na interface:

```text
Settings
└─ Diagnostics
   ├─ Profiler
   ├─ Profiler Overlay
   └─ Report Interval
```

O profiler mede trabalho CPU-side do Newz. Ele não representa o custo total de GPU, física, renderização ou scripts internos da experiência.

## Terceiros

A NeverLose vendorizada declara licença MIT em seu cabeçalho. Consulte `THIRD_PARTY_NOTICES.md`.

## Uso

Este projeto deve ser usado somente em experiências, ambientes e servidores nos quais o operador tenha autorização para desenvolvimento, diagnóstico ou teste.
