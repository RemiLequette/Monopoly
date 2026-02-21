# FR/US card references (machine-readable format)

This document describes the **source-of-truth format** used by the code:

- FR file: [docs/cards_transition_reference_fr.toml](docs/cards_transition_reference_fr.toml)
- US file: [docs/cards_transition_reference_us.toml](docs/cards_transition_reference_us.toml)
- Automatically loaded by `dice_transition_matrix(card_rules=:fr)` or `dice_transition_matrix(card_rules=:us)`

## Why TOML

- Easy for humans to read and edit.
- Native Julia parsing (`TOML.parsefile`) with no extra dependency.
- Stable structure for code (sections + card lists).

## File structure

- `[metadata]`: version, edition, language.
- `[board]`: key squares (`go_square`, `jail_square`, etc.).
- `[chance]` and `[community]`:
	- `squares`: draw-square positions.
	- `deck_size`: deck size (usually 16).
	- `[[...cards]]`: one entry per card.

## Card fields

- `id`: stable identifier (snake_case).
- `text`: human-readable card text.
- `effect`: effect type supported by the code:
	- `none`
	- `move_to` (+ `target`)
	- `goto_jail`
	- `move_nearest_railroad`
	- `move_nearest_utility`
	- `move_relative` (+ `steps`)
	- `draw_chance`
- `weight` (optional, default `1`): draw weight for the card.

## Maintenance rule

- If the number of declared cards is lower than `deck_size`, the code treats missing cards as **no movement** on draw.
- For full fidelity to a specific edition, define cards up to `deck_size`.
