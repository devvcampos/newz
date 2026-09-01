# Newz

Ferramenta visual em Luau para diagnóstico autorizado de jogadores e entidades em um ambiente Roblox controlado.

## Estado atual

A versão `0.4.3` mantém a arquitetura modular e as otimizações anteriores e adiciona Local Illusion para inspeção visual de um cadáver selecionado sem mover o objeto replicado pelo servidor.

Recursos atuais:

- Player ESP com box `Corner` ou `Full`;
- nome, vida, arma equipada e distância;
- visibility check e team check;
- Corpse ESP com box, nome e distância;
- seleção periódica dos cadáveres mais próximos;
- limite configurável de cadáveres ativos;
- Local Illusion com seleção de cadáver por nick, refresh da lista e distância visual configurável;
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
│     ├─ CorpseIllusion.lua
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

`Profiler.lua` mede custo CPU-side do Newz, incluindo `Newz.Render`, bounds, visibility, visuals e seleção de cadáveres.

### Modules

`PlayerESP.lua` é responsável pelo lifecycle e renderização dos jogadores, incluindo streaming, humanoid, arma equipada e visibility.

`CorpseESP.lua` acompanha todos os Models em `Workspace.Corpses`, porém apenas os cadáveres mais próximos dentro de `MaxDistance` entram no conjunto ativo de renderização, limitado por `MaxCorpses`.

`CorpseIllusion.lua` cria uma cópia visual exclusivamente local do cadáver escolhido. A cópia é ancorada, sem colisão/interação e fica fora de `Workspace.Corpses`, portanto não entra novamente no Corpse ESP.

`ESP.lua` funciona como facade/orquestrador. Ele cria o `ScreenGui`, instancia o Core, inicializa Player/Corpse ESP e coordena o `RenderStepped`.

## Corpse selection

Por padrão:

```text
MaxDistance = 500 studs
MaxCorpses = 8
SelectionInterval = 0.25 s
```

O tracker continua conhecendo todos os cadáveres da pasta, mas a cada intervalo seleciona os mais próximos. Cadáveres fora do conjunto ativo não executam o caminho caro de bounds/visuals.

O profiler diferencia:

```text
Tracked: players X | corpses Y | active Z
Corpse select
Corpse update
Corpse bounds
Corpse visuals
```


## Local Illusion

Na aba `Corpses`, a seção `Local Illusion` permite:

```text
Target Corpse       [ BopBlx_YT ▼ ]
Illusion Distance   [ 5 ]
[ Refresh Corpses ]
[ Show Local Illusion ]
[ Clear Local Illusion ]
```

`Show Local Illusion` não altera o Model original em `Workspace.Corpses`. O módulo clona apenas a representação disponível no cliente, remove scripts/interações e `Loot_Corpse`, ancora as partes e posiciona a cópia visual na frente do personagem local.

A ilusão é destruída ao usar `Clear Local Illusion` ou ao descarregar o Newz.

## Hot-path optimization

PlayerESP, CorpseESP e o facade fazem binding local das funções usadas nos loops críticos. O scheduler reutiliza callbacks estáveis e a posição da câmera é calculada uma vez por `Step`.

A projection engine acumula os oito cantos de cada parte usando variáveis locais antes de escrever o resultado de volta no estado de bounds.

## Projection Engine

A projection engine mantém os mesmos oito cantos por parte usados originalmente, mas evita executar `WorldToViewportPoint` para cada canto.

A câmera é calibrada uma vez por frame com três projeções nativas. Os cantos são então projetados em camera-space. Um caminho legado continua disponível automaticamente para estados de câmera inválidos.

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
