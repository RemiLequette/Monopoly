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

- Handle doubles and jail multi-turn rules
- Markov transition matrix (`dice_transition_matrix`) for 2d6 moves and board effects
- One-step and multi-step updates (`update_probability_after_throw`, `simulate_n_throws`)
- Long-run convergent probabilities via power iteration (`convergent_probabilities`)
- Probability reporting in notebook with board heatmap and ranked squares

## Current movement model

- Dice-roll transition probabilities (2d6)
- `Go To Jail` square impact (square 31 → 11)
- Chance and Community Chest effects from TOML card references (`card_rules=:fr` or `:us`)
- Supported card effects: move to square, go to jail, nearest railroad, nearest utility, relative move (e.g., back 3), draw-chained effects
- Weighted deck modeling with deck-size normalization and remaining “no movement” mass

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
