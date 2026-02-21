# Monopoly Probability (Julia)

Compute Monopoly landing probabilities with a Julia Markov model and notebook workflow.

## Structure

- `Project.toml`: Julia project definition
- `src/MonopolyProbability.jl`: Base module and board definition
- `notebooks/monopoly_probability.ipynb`: Starter notebook
- `docs/cards_transition_reference.md`: Documentation of the card rules file format
- `docs/cards_transition_reference_fr.toml`: Machine-readable FR card rules used for transition generation
- `docs/cards_transition_reference_us.toml`: Machine-readable US card rules used for transition generation

## Quick start

1. Open `notebooks/monopoly_probability.ipynb`.
2. Run the first code cell to activate the project environment.
3. Run the second code cell to load the module and inspect the board.
4. Run the following cells to simulate finite throws and compute long-run convergent probabilities.

## Implemented features

- Markov transition matrix (`dice_transition_matrix`) for 2d6 moves and board effects
- Optional doubles-aware transition matrix with in-turn doubles state (`dice_transition_matrix(include_doubles=true)`)
- One-step and multi-step updates (`update_probability_after_throw`, `simulate_n_throws`)
- Long-run convergent probabilities via power iteration (`convergent_probabilities`)
- Rentability-oriented expected landing counts per full turn (`expected_landings_per_turn`)
- Probability reporting in notebook with board heatmap and ranked squares

## Current movement model

- Dice-roll transition probabilities (2d6)
- `Go To Jail` square impact (square 31 → 11)
- Chance and Community Chest effects from TOML card references (`card_rules=:fr` or `:us`)
- Supported card effects: move to square, go to jail, nearest railroad, nearest utility, relative move (e.g., back 3), draw-chained effects
- Weighted deck modeling with deck-size normalization and remaining “no movement” mass
- Optional doubles rule with in-turn state `(square, doubles_count)` and third-consecutive-double jail rule
- Configurable jail strategy in doubles-aware mode with explicit jail-state support

### Card rule sets

- `card_rules=:fr` (default): fixed Chance railroad destination goes to square 16 (Gare de Lyon)
- `card_rules=:us`: fixed Chance railroad destination goes to square 6 (Reading Railroad)

## Stationary (convergent) algorithm

The long-run distribution is computed with power iteration on the transition matrix `T`:

1. Start from an initial probability vector `p₀` (default: all mass on square 1).
2. Repeatedly apply `pₖ₊₁ = T * pₖ`.
3. Stop when `maximum(abs.(pₖ₊₁ .- pₖ)) < tol` (default `1e-13`) or when `max_iter` is reached.

API:

- `convergent_probabilities(transition_matrix; tol=1e-13, max_iter=50_000, initial=nothing)`
- Returns `(probabilities, iterations, converged)`.

This method is efficient for this dense 40x40 chain and provides a numerically stable estimate of the stationary probabilities used in the notebook visualizations.

## Doubles-aware rentability model

To approximate rentability (how often opponents can land on payable squares), the project can model a full turn with doubles:

- State augmentation uses `(square, doubles_count)` where `doubles_count ∈ {0,1,2}` within a turn.
- A double grants an extra roll in the same turn.
- On a third consecutive double, the turn ends in Jail (square 11).

APIs:

- `dice_transition_matrix(; include_doubles=true, ...)`: turn-boundary transition matrix including doubles behavior.
- `dice_transition_matrix(; include_doubles=true, jail_policy=:pay_immediately, ...)`: 40x40 turn-boundary transition matrix on square-only states.
- `dice_transition_matrix_with_jail_state(; include_doubles=true, jail_policy=:try_doubles_then_pay, ...)`: 80x80 transition matrix on expanded `(square, in_jail)` states.
- `expand_turn_start_distribution(square_probabilities; jail_probability_at_11=...)`: lift a 40-square distribution into expanded state space.
- `collapse_turn_state_distribution(expanded_probabilities)`: project expanded distribution back to 40 squares.
- `expected_landings_per_turn(start_probabilities; include_doubles=true, jail_policy=:pay_immediately, ...)`: expected number of landings on each square during one full turn (including extra rolls from doubles). Supports expanded start distributions (length 80) when modeling explicit jail state.

Supported jail strategies:

- `:pay_immediately` (default): when starting from Jail, movement follows regular doubles-aware turn logic.
- `:try_doubles_then_pay`: when starting from Jail, a non-double keeps the player in Jail for turn end; a double leaves Jail, moves, and ends the turn.

Important modeling note:

- The 40-square state cannot distinguish `Jail` vs `Just Visiting` on square 11.
- Therefore `dice_transition_matrix(..., jail_policy=:try_doubles_then_pay)` is intentionally rejected.
- Use expanded-state workflow for this policy:
  1. Build `T80 = dice_transition_matrix_with_jail_state(jail_policy=:try_doubles_then_pay, ...)`
  2. Compute stationary expanded state with `convergent_probabilities(T80)`
  3. Collapse to 40 squares using `collapse_turn_state_distribution(...)`

Recommended workflow for rentability:

1. Compute the doubles-aware stationary distribution with `dice_transition_matrix(include_doubles=true)` + `convergent_probabilities(...)`.
2. Use that stationary distribution as input to `expected_landings_per_turn(...)`.
3. Rank squares by returned expected landing counts.
