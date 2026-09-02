from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    ROOT / "src" / "Main.lua",
    ROOT / "src" / "Config.lua",
    ROOT / "src" / "Ui.lua",

    ROOT / "src" / "Core" / "Profiler.lua",
    ROOT / "src" / "Core" / "Bounds.lua",
    ROOT / "src" / "Core" / "Visuals.lua",
    ROOT / "src" / "Core" / "Scheduler.lua",

    ROOT / "src" / "Modules" / "PlayerESP.lua",
    ROOT / "src" / "Modules" / "CorpseESP.lua",
    ROOT / "src" / "Modules" / "Freecam.lua",
    ROOT / "src" / "Modules" / "ESP.lua",

    ROOT / "vendor" / "NeverLose.lua",
    ROOT / "scripts" / "build.py",

    ROOT / "README.md",
    ROOT / "THIRD_PARTY_NOTICES.md",
]

STALE_TOKENS = {
    "src/Config.lua": [
        "EntitiesFolder",
        "EntityFolderTimeout",
        "PlayersOnly",
        "LootContainerName",
        "LootMarkerName",
        "LootMaxItems",
        "CorpseIllusion",
        "TeleportDistance",
        "TeleportHeight",
    ],

    "src/Ui.lua": [
        "EntitiesFolder",
        "EntityFolderTimeout",
        "PlayersOnly",
        "Compkiller",
        "CompKiller",
        "corpses_loot",
        "Loot Max Items",
        "CorpseIllusion",
        "BringCorpseToMe",
        "Go To Corpse",
        "Trazer Corpo",
        "Local Illusion",
    ],

    "src/Main.lua": [
        "LootESPModule",
        "src/Modules/LootESP.lua",
        "CorpseActionsModule",
        "src/Modules/CorpseActions.lua",
        "CorpseIllusionModule",
        "CorpseIllusionController",

        "game:HttpGet",
        "game.HttpGet",
        "raw.githubusercontent.com",
        "api.github.com",
        "ResolveSourceRef",
        "LoadModuleFromRef",
        "NEWZ_SOURCE_REF",
        "CacheBust",
    ],

    "scripts/build.py": [
        "CorpseIllusion",
    ],

    "src/Modules/ESP.lua": [
        "LootESPModule",
        "LootModule",
    ],

    "src/Modules/CorpseESP.lua": [
        "LootModule",
        "LootPrepare",
        "LootSync",
        "LootSuspend",
        "LootDestroyData",
    ],

    "README.md": [
        "vendor/Compkiller.lua",
        "LootESP.lua",
        "Loot Max Items",
        "CorpseIllusion.lua",
        "Local Illusion",
        "NEWZ_SOURCE_REF",
    ],
}

FORBIDDEN_MONOLITH_TOKENS = [
    "local function RegisterEntity(",
    "local function RegisterCorpse(",
    "local function ProjectPartFast(",
    "local function UpdateCornerBox(",
]

FORBIDDEN_OLD_PATHS = [
    ROOT / "src" / "Modules" / "CorpseActions.lua",
    ROOT / "src" / "Modules" / "CorpseIllusion.lua",
    ROOT / "server" / "CorpseActions.server.lua",
    ROOT / "REMOVE_OLD_CORPSE_ACTIONS.txt",
]


def main() -> int:
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--require-dist",
        action="store_true",
        help="Fail if dist/newz.lua is missing or empty.",
    )

    args = parser.parse_args()

    failed = False

    for path in REQUIRED:
        if (
            not path.is_file()
            or not path.read_text(
                encoding="utf-8"
            ).strip()
        ):
            print(
                f"FAIL missing/empty: {path.relative_to(ROOT)}"
            )

            failed = True

    for path in FORBIDDEN_OLD_PATHS:
        if path.exists():
            print(
                "FAIL obsolete file still exists: "
                f"{path.relative_to(ROOT)}"
            )

            failed = True

    for relative, tokens in STALE_TOKENS.items():
        path = ROOT / relative

        if not path.is_file():
            continue

        text = path.read_text(
            encoding="utf-8"
        )

        for token in tokens:
            if token in text:
                print(
                    f"FAIL stale token {token!r} in {relative}"
                )

                failed = True

    facade = (
        ROOT
        / "src"
        / "Modules"
        / "ESP.lua"
    )

    if facade.is_file():
        facade_text = facade.read_text(
            encoding="utf-8"
        )

        for token in FORBIDDEN_MONOLITH_TOKENS:
            if token in facade_text:
                print(
                    "FAIL ESP facade contains implementation token "
                    f"{token!r}"
                )

                failed = True

    freecam = (
        ROOT
        / "src"
        / "Modules"
        / "Freecam.lua"
    )

    if freecam.is_file():
        freecam_text = freecam.read_text(
            encoding="utf-8"
        )

        for token in [
            "Enum.CameraType.Scriptable",
            "BindActionAtPriority",
            "TeleportOnExit",
            "SetKeybind",
        ]:
            if token not in freecam_text:
                print(
                    f"FAIL Freecam missing expected token {token!r}"
                )

                failed = True

    dist = ROOT / "dist" / "newz.lua"

    if args.require_dist:
        if (
            not dist.is_file()
            or not dist.read_text(
                encoding="utf-8"
            ).strip()
        ):
            print(
                "FAIL dist/newz.lua was not generated"
            )

            failed = True

    analyzer = shutil.which(
        "luau-analyze"
    )

    if analyzer:
        print(
            "Running luau-analyze..."
        )

        result = subprocess.run(
            [
                analyzer,
                "src",
            ],
            cwd=ROOT,
            check=False,
        )

        if result.returncode != 0:
            failed = True
    else:
        print(
            "INFO luau-analyze not found; static analysis skipped"
        )

    if failed:
        return 1

    print(
        "Checks passed"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(
        main()
    )
