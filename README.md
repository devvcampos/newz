# newz

Ferramenta visual em Luau para diagnóstico autorizado de entidades em um ambiente Roblox controlado.

## Escopo

O projeto rastreia modelos em uma pasta configurável do `Workspace`, calcula limites de tela e apresenta nome, vida, distância e visibilidade. Ele deve ser usado somente em experiências e servidores nos quais o operador tenha autorização.

## Estrutura

- `src/Main.lua`: bootstrap, carregamento dos módulos e ciclo de vida global.
- `src/Config.lua`: configurações de runtime, interface e ESP.
- `src/Modules/ESP.lua`: descoberta de entidades, projeção e renderização.
- `src/Ui.lua`: controles da interface e persistência de configurações.
- `dist/newz.lua`: artefato de distribuição; ainda precisa ser gerado pelo processo de build.
- `vendor/Compkiller.lua`: dependência local; ainda precisa ser preenchida e fixada em uma versão conhecida.

## Identidade das entidades

Modelos associados a jogadores devem usar a referência oficial `Player.Character` ou possuir o atributo numérico `UserId`. `DisplayName` não é usado como identidade porque não é único.

## Configuração de runtime

`Config.Runtime` controla:

- `EntitiesFolder`: pasta de entidades dentro de `Workspace`;
- `EntityFolderTimeout`: tempo máximo de inicialização;
- `UpdateFrequency`: frequência de atualização visual;
- `VisibilityInterval`: intervalo entre raycasts de visibilidade por entidade.

## Estado atual

O bootstrap e a CompKiller ainda são carregados por URLs mutáveis. O próximo passo de empacotamento deve preencher `vendor/`, gerar `dist/newz.lua` e fixar as dependências por versão ou commit.
