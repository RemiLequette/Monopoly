# Monopoly Probability (Julia)

Scaffold for computing the probability of being on each Monopoly property using a Julia notebook.

## Structure

- `Project.toml`: Julia project definition
- `src/MonopolyProbability.jl`: Base module and board definition
- `notebooks/monopoly_probability.ipynb`: Starter notebook

## Quick start

1. Open `notebooks/monopoly_probability.ipynb`.
2. Run the first code cell to activate and instantiate the project environment.
3. Run the second code cell to load the module and inspect the board.
4. Continue by implementing the transition matrix and stationary distribution.

## Next implementation targets

- Add dice-roll transition probabilities (2d6)
- Handle doubles and jail rules
- Build Markov transition matrix (40x40)
- Compute stationary distribution
- Report landing probabilities by property
