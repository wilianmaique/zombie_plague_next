# Project Instructions for Codex

## Project Context
- This is a Counter-Strike 1.6 project using AMX Mod X.
- The main programming language is Pawn.
- The target environment is CS 1.6 / HLDS / ReHLDS / AMXX.

## Workflow Rules
- Avoid compiling the project. The user compiles it manually.
- Do not run build scripts, compilers, or packaging commands unless explicitly requested.
- When editing Pawn code, follow the existing project style whenever possible.
- Target the project's configured Counter-Strike 1.6, AMXX, and ReAPI runtime.
- Prefer focused changes that are easy to review; refactor affected code when that produces a cleaner structure.

## APIs and Includes
- Use ReAPI whenever appropriate. It is newer, safer, and preferred for supported features.
- Before creating custom wrappers or manual logic, check whether AMXX or ReAPI already provides a suitable native, forward, or helper.
- When there is any doubt, verify native and forward signatures, parameters, and return values before using them.

## Reference Research
- If AMXX API research is needed, check this source first: https://amxx-api.csrevo.com/search.json?q=`name func etc...`
- For historical context, examples, plugin behavior, or troubleshooting, search Google with `alliedmodders` included in the query.
- Prefer official documentation and well-established examples over assumptions about native behavior.

## Project Evolution
- This project is under active development. Do not add migrations, aliases, fallback paths, or compatibility layers for earlier project versions or old configuration formats unless the user explicitly requests them.
- When changing an API or configuration, update its callers, includes, configuration files, and documentation together, and remove superseded code.
- Preserve compatibility with the target CS 1.6 / AMXX / ReAPI runtime, but do not preserve obsolete project behavior solely for backward compatibility.

## Code Safety
- Avoid introducing new dependencies unless there is a clear need.
- Avoid large refactors when the request is narrow.
- Remove obsolete code when replacing it with the intended structure.
- When editing includes, natives, or forwards, verify they work with the project's target AMXX and ReAPI versions.
- Not edit README.md

## Player-facing Text and Localization
- Keep all player-visible text in AMXX dictionaries under `cstrike/addons/amxmodx/data/lang/`, with complete, natural Brazilian Portuguese `[bp]` and English `[en]` translations. This includes chat, HUDs, menus, class/item/mode names and descriptions, ranks, and in-game admin command output/help.
- Organize ZPN dictionaries by responsibility: `zpn_gamemodes.txt`, `zpn_items.txt`, `zpn_classes.txt`, `zpn_levels.txt`, and `zpn_menus.txt`. Keep the core HUD and countdown in `zpn_main.txt`, first-zombie helper messages in `zpn_first_zombie_helper.txt`, camera text in `amx_camera.txt`, and NPC administration/mapping in `advanced_npc_admin.txt` / `advanced_npc_mapper.txt` respectively. Add a separate dictionary for a distinct feature when appropriate; avoid miscellaneous catch-all files.
- Whenever adding, changing, or removing player-visible text, update its dictionary keys, both translations, and all callers together. Remove unused keys and superseded text; do not leave obsolete translations or hardcoded display text.
- Give each key exactly one owning dictionary; do not duplicate it across files. When moving keys, update all registrations and references together and remove dictionaries left empty.
- Register every dictionary a plugin needs, including keys received dynamically through class/item/gamemode properties. The main core registers class and gamemode dictionaries; menus register class and item dictionaries. Translate for the actual recipient when displaying text; never cache a player's translated text for other players or translate broadcasts once in the server language.
- Use `%L` with an explicit client/server target in menus and formatting. `zpn_print_color` sets the target for `%l` separately for each recipient, including broadcasts; use `%l` there or `%L` with an explicit target. Reserve `LANG_PLAYER` for AMXX output natives that establish that target themselves.
- Class `NAME`/`INFO`, item `NAME`, and gamemode `NAME`/`NOTICE` properties store translation keys. Keep configuration identifiers, find names, command names, resource paths and protocol strings language-independent. Class JSON display settings are `name_key` and `description_key`.
- Preserve placeholder types/order, chat/menu color codes, line breaks, UTF-8 encoding without BOM, and CS message limits in both languages. Treat already formatted text and player/config names as data (`"%s"`).
- Validate `[bp]` / `[en]` key parity, unique dictionary ownership, references, registrations (including dynamic metadata), and formatting arguments with read-only checks after localization changes. Preserve existing translations when reorganizing files. Do not compile unless the user explicitly requests it.
