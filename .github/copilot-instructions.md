# MonopolyProbability – Project Instructions

## Scope
These instructions apply to the entire repository.

## Core Rules
- Keep changes minimal, focused, and consistent with existing Julia style.
- Do not refactor unrelated code.
- Do not rename public functions or move files unless explicitly requested.

## Notebook Safety Rule (Important)
- **Never modify files in `notebooks/` unless the user explicitly asks for notebook edits.**
- If a task can be solved in `src/`, prefer `src/` changes only.
- If notebook edits are requested, change only the specific cells needed.

## Julia Code Guidelines
- Prefer small, composable functions with clear names.
- Validate inputs and throw `ArgumentError` for invalid user-facing arguments.
- Keep public API stable and export only intended functions.
- Avoid adding new dependencies unless they are necessary for the requested feature.

## Documentation
- When behavior changes, update `README.md` or inline usage examples if needed.
- Keep documentation and comments in English.
