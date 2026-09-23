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
