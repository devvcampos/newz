# Newz

Ferramenta visual em Luau para diagnóstico autorizado de jogadores e entidades em um ambiente Roblox controlado.

## Estado atual

A versão `0.5.0` mantém o Player ESP e o Corpse ESP modularizados e adiciona uma Freecam independente do sistema de ESP.

Recursos atuais:

- Player ESP com box `Corner` ou `Full`;
- nome, vida, arma equipada e distância;
- visibility check e team check;
- Corpse ESP com box, nome e distância;
- seleção periódica dos cadáveres mais próximos;
- limite configurável de cadáveres ativos;
- Freecam com tecla configurável;
- movimento por WASD, Space/Ctrl e boost com Shift;
- velocidade, boost e sensibilidade configuráveis;
- opção de mover o personagem para a posição final da câmera ao sair;
- opção de procurar o chão abaixo da câmera antes do reposicionamento;
- profiler em tempo real;
- projection engine calibrada por frame;
- scheduler round-robin a 30 Hz por entidade;
- build reproduzível em `dist/newz.lua`.

O antigo módulo de ações/preview de cadáveres foi removido. O projeto mantém apenas o Corpse ESP.

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
│     ├─ Freecam.lua
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

## Modules

`PlayerESP.lua` é responsável pelo lifecycle e renderização dos jogadores, incluindo streaming, humanoid, arma equipada e visibility.

`CorpseESP.lua` acompanha os Models em `Workspace.Corpses`, mas apenas os cadáveres mais próximos dentro de `MaxDistance` entram no conjunto ativo de renderização, limitado por `MaxCorpses`.

`Freecam.lua` controla uma câmera `Scriptable` sem mover continuamente o personagem. Ao sair normalmente, `TeleportOnExit` pode reposicionar o personagem uma única vez para a posição final da câmera.

`ESP.lua` funciona como facade/orquestrador do Player ESP e Corpse ESP.

## Freecam

Configuração padrão:

```lua
Config.Freecam = {
    Keybind = "V",
    Speed = 55,
    BoostMultiplier = 3,
    MouseSensitivity = 0.12,
    TeleportOnExit = true,
    SnapToGround = true,
}
```

Controles:

```text
V                 liga/desliga por padrão
WASD              movimentação horizontal
Space             subir
Ctrl              descer
Shift             boost
Mouse             olhar
```

A tecla pode ser alterada pela interface.

Enquanto a Freecam está ativa, o módulo usa `ContextActionService` para consumir os controles de movimento e evita que WASD mova o personagem ao mesmo tempo.

Quando a Freecam é desligada normalmente com `TeleportOnExit = true`, o módulo tenta mover o personagem para a posição final da câmera. Com `SnapToGround = true`, um raycast procura uma superfície abaixo da câmera antes do reposicionamento.

O reposicionamento é iniciado no cliente. Uma experiência com autoridade/correção server-side pode rejeitar ou corrigir essa mudança.

Ao descarregar o Newz, a câmera é restaurada sem reposicionar o personagem.

## Corpse selection

Por padrão:

```text
MaxDistance = 500 studs
MaxCorpses = 8
SelectionInterval = 0.25 s
```

O tracker continua conhecendo os cadáveres da pasta, mas apenas o conjunto ativo executa o caminho mais caro de bounds/visuals.

## Build

`src/Main.lua` é bundle-only. Para gerar a distribuição:

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
