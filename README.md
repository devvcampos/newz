# Newz

Ferramenta visual/modular em Luau para desenvolvimento e diagnóstico em ambiente Roblox controlado.

## Versão 0.6.0

A 0.6.0 mantém a interface NeverLose já usada pelo projeto e incorpora, na arquitetura do Newz, o conjunto de recursos que conseguimos reconstruir com alta confiança do projeto analisado.

### Recursos existentes preservados

- Player ESP modular;
- Corpse ESP;
- Freecam;
- profiler;
- projection/bounds engine;
- scheduler;
- build bundle-only em `dist/newz.lua`;
- UI NeverLose vendorizada.

### Recursos adicionados

#### Advanced ESP

- Outlines;
- Health Bar;
- porcentagem de vida opcional;
- Skeleton;
- flags de movimento (`Idle`, `Moving`, `Jumping`);
- Off-Screen Arrows;
- Highlight Chams;
- texto avançado de nome/distância;
- posição `Bottom`, `Top` ou `Side`.

#### Player Tools

- seleção de player;
- atualização automática da lista;
- nome/display name;
- vida;
- distância;
- friend status;
- visibilidade;
- team;
- Spectate;
- Stop Spectate.

#### Aim Assist

- tecla padrão `E`;
- modo Hold ou Toggle;
- seleção por FOV;
- alvo configurável (`Head`, `HumanoidRootPart`, `UpperTorso`, `Torso`);
- Max Distance;
- Team Check;
- Visibility Check;
- círculo de FOV;
- resposta determinística de câmera.

Não existe randomização/humanização de input ou lógica adicionada para esconder o recurso de sistemas de detecção.

#### Character / Movement

- Zoom, tecla padrão `Z`;
- Invisible local, tecla padrão `I`;
- Noclip, tecla padrão `B`;
- Freecam permanece em `V` por padrão.

`Invisible` usa `LocalTransparencyModifier`, portanto é um efeito visual local. `Noclip` altera colisão das partes do personagem no cliente.

## Estrutura

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
│  ├─ Modules/
│  │  ├─ PlayerESP.lua
│  │  ├─ CorpseESP.lua
│  │  ├─ Freecam.lua
│  │  └─ ESP.lua
│  │
│  └─ Features/
│     ├─ AdvancedESP.lua
│     ├─ PlayerTools.lua
│     ├─ AimAssist.lua
│     ├─ CharacterFeatures.lua
│     └─ FeatureInput.lua
│
├─ vendor/
│  └─ NeverLose.lua
│
├─ scripts/
│  ├─ build.py
│  └─ check.py
│
└─ dist/
   └─ newz.lua
```

## Arquitetura

`ESP.lua` continua sendo o orquestrador do Player ESP e Corpse ESP existentes.

`AdvancedESP.lua` é uma camada visual adicional. Isso evita transformar `PlayerESP.lua` num monólito e permite ligar apenas os recursos extras quando necessário.

`PlayerTools.lua` concentra seleção de player, informações e spectate.

`AimAssist.lua` concentra seleção de alvo, FOV e resposta da câmera.

`CharacterFeatures.lua` concentra Zoom, Noclip e Invisible local.

`FeatureInput.lua` é o roteador de teclas das features novas.

## UI

A biblioteca de UI não foi trocada. A NeverLose continua sendo usada pelo `Ui.lua`; apenas novas seções e controles foram adicionados ao layout existente.

Principais áreas:

```text
Players
├─ ESP
├─ Filters
├─ Appearance
├─ Advanced ESP
├─ Advanced Colors
└─ Player Tools

Movement
├─ Freecam
├─ Exit Behavior
├─ Aim Assist
├─ Aim Filters
└─ Character

Corpses
├─ Corpse ESP
└─ Appearance

Settings
├─ Interface
├─ Diagnostics
└─ Project
```

## Freecam

A Freecam mantém o personagem real parado enquanto a câmera está livre. O reposicionamento opcional ao sair é uma tentativa cliente comum e pode ser corrigido pelo servidor da experiência.

Controles padrão:

```text
V          Freecam
WASD       movimento
Space      subir
Ctrl       descer
Shift      boost
Mouse      olhar
```

## Build

Na raiz do projeto:

```powershell
python scripts/build.py
python scripts/check.py --require-dist
```

Se tudo passar:

```powershell
git status
git add .
git commit -m "Add reconstructed feature suite"
git push origin main
```

## Nota sobre a reconstrução

As features foram implementadas no padrão arquitetural do Newz a partir dos comportamentos que conseguimos recuperar do projeto analisado. Isso não significa que nomes de variáveis, divisão original de arquivos ou implementação interna sejam idênticos ao código-fonte pré-ofuscação.

Também não foi copiado o loader remoto do projeto analisado. As funcionalidades foram implementadas localmente dentro do Newz, mantendo o bundle autocontido.
