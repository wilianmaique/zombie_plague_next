# Project Instructions for Codex

## Project Context
- This is a Counter-Strike 1.6 project using AMX Mod X.
- The main programming language is Pawn.
- The target environment is CS 1.6 / HLDS / ReHLDS / AMXX.

## Workflow Rules
- Avoid compiling the project. The user compiles it manually.
- Do not run build scripts, compilers, or packaging commands unless explicitly requested.
- When editing Pawn code, follow the existing project style whenever possible.
- Preserve compatibility with AMXX and Counter-Strike 1.6.
- Prefer small, focused changes that are easy to review.

## APIs and Includes
- Use ReAPI whenever appropriate. It is newer, safer, and preferred for supported features.
- Before creating custom wrappers or manual logic, check whether AMXX or ReAPI already provides a suitable native, forward, or helper.
- When there is any doubt, verify native and forward signatures, parameters, and return values before using them.

## Reference Research
- If AMXX API research is needed, check this source first: https://amxx-api.csrevo.com/search.json?q=`name func etc...`
- For historical context, examples, plugin behavior, or troubleshooting, search Google with `alliedmodders` included in the query.
- Prefer official documentation and well-established examples over assumptions about native behavior.

## Code Safety
- Avoid introducing new dependencies unless there is a clear need.
- Avoid large refactors when the request is narrow.
- Do not remove existing functionality unless it is confirmed to be obsolete or incorrect.
- When editing includes, natives, or forwards, consider compatibility differences between standard AMXX, ReAPI, and older builds.
- If a change may affect compatibility, explain the tradeoff and why the change was made.
