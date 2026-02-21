module MonopolyProbability

using Printf
using TOML

export BOARD_SIZE, standard_board, standard_board_us, initial_probability_distribution, dice_transition_matrix, update_probability_after_throw, simulate_n_throws, convergent_probabilities, board_square, print_board_square

const BOARD_SIZE = 40
const _CARD_RULES_CACHE = Dict{String, Dict{String, Any}}()

"""
Create an initial probability vector with all mass on `start_square`.

Returns a `Vector{Float64}` of length `BOARD_SIZE`.
"""
function initial_probability_distribution(; start_square::Int=1)
    if !(1 <= start_square <= BOARD_SIZE)
        throw(ArgumentError("start_square must be between 1 and $(BOARD_SIZE), got $(start_square)."))
    end

    probabilities = zeros(Float64, BOARD_SIZE)
    probabilities[start_square] = 1.0
    return probabilities
end

"""
Return a one-hot distribution for `square` on a board of size `board_size`.
"""
function _one_hot_square(square::Int, board_size::Int)
    distribution = zeros(Float64, board_size)
    distribution[square] = 1.0
    return distribution
end

"""
Validate that `card_rules` is one of the supported rule sets (`:fr`, `:us`).
"""
function _validate_card_rules(card_rules::Symbol)
    if card_rules ∉ (:fr, :us)
        throw(ArgumentError("card_rules must be :fr or :us, got $(card_rules)."))
    end
end

"""
Return the default TOML card-rule file path for the given rule set.
"""
function _default_card_rules_file(card_rules::Symbol)
    if card_rules == :fr
        return joinpath(@__DIR__, "..", "docs", "cards_transition_reference_fr.toml")
    elseif card_rules == :us
        return joinpath(@__DIR__, "..", "docs", "cards_transition_reference_us.toml")
    end
    return nothing
end

"""
Load and cache TOML card rules configuration.

If `card_rules_file` is provided, it overrides the default file path.
"""
function _load_card_rules_config(card_rules::Symbol, card_rules_file::Union{Nothing,AbstractString})
    file_path = card_rules_file === nothing ? _default_card_rules_file(card_rules) : String(card_rules_file)
    if file_path === nothing
        return nothing
    end

    absolute_path = isabspath(file_path) ? file_path : normpath(joinpath(@__DIR__, "..", file_path))
    if !isfile(absolute_path)
        throw(ArgumentError("card_rules file not found: $(absolute_path)"))
    end

    if haskey(_CARD_RULES_CACHE, absolute_path)
        return _CARD_RULES_CACHE[absolute_path]
    end

    parsed = TOML.parsefile(absolute_path)
    _CARD_RULES_CACHE[absolute_path] = parsed
    return parsed
end

"""
Return the next target square clockwise from `square` among `targets`.
"""
function _next_clockwise_square(square::Int, targets::Vector{Int})
    sorted_targets = sort(unique(targets))
    for target in sorted_targets
        if target > square
            return target
        end
    end
    return sorted_targets[1]
end

"""
Return the nearest railroad square clockwise from `square`.
"""
function _nearest_railroad(square::Int)
    return _next_clockwise_square(square, [6, 16, 26, 36])
end

"""
Return the nearest utility square clockwise from `square`.
"""
function _nearest_utility(square::Int)
    return _next_clockwise_square(square, [13, 29])
end

"""
Legacy helper for fixed railroad destination in Chance fallback rules.
"""
function _chance_fixed_railroad(card_rules::Symbol)
    if card_rules == :fr
        return 16
    end
    return 6
end

"""
Resolve a single card effect into a landing distribution.

Used by TOML-driven deck resolution.
"""
function _apply_card_effect_distribution(
    card::Dict{String, Any},
    square::Int,
    board_size::Int;
    include_cards::Bool,
    card_rules::Symbol,
    cards_config::Dict{String, Any},
    depth::Int
)
    effect = String(get(card, "effect", "none"))

    if effect == "none"
        return _one_hot_square(square, board_size)
    elseif effect == "move_to"
        target = Int(card["target"])
        return _one_hot_square(target, board_size)
    elseif effect == "goto_jail"
        return _one_hot_square(11, board_size)
    elseif effect == "move_nearest_railroad"
        return _one_hot_square(_nearest_railroad(square), board_size)
    elseif effect == "move_nearest_utility"
        return _one_hot_square(_nearest_utility(square), board_size)
    elseif effect == "move_relative"
        steps = Int(get(card, "steps", 0))
        target = mod1(square + steps, board_size)
        return _resolve_landing_distribution(target, board_size; include_cards=include_cards, card_rules=card_rules, cards_config=cards_config, depth=depth + 1)
    elseif effect == "draw_chance"
        return _deck_distribution("chance", square, board_size; include_cards=include_cards, card_rules=card_rules, cards_config=cards_config, depth=depth + 1)
    end

    throw(ArgumentError("Unsupported card effect: $(effect)"))
end

"""
Resolve one draw deck (`chance` or `community`) into a landing distribution.

The function computes expected movement over all cards and their weights.
"""
function _deck_distribution(
    deck_name::String,
    square::Int,
    board_size::Int;
    include_cards::Bool,
    card_rules::Symbol,
    cards_config::Dict{String, Any},
    depth::Int
)
    deck = cards_config[deck_name]
    deck_size = Int(deck["deck_size"])
    cards = get(deck, "cards", Dict{String, Any}[])

    distribution = zeros(Float64, board_size)
    used_weight = 0

    for raw_card in cards
        card = Dict{String, Any}(raw_card)
        weight = Int(get(card, "weight", 1))
        used_weight += weight
        card_distribution = _apply_card_effect_distribution(card, square, board_size; include_cards=include_cards, card_rules=card_rules, cards_config=cards_config, depth=depth)
        distribution .+= (weight / deck_size) .* card_distribution
    end

    remaining = deck_size - used_weight
    if remaining < 0
        throw(ArgumentError("Deck $(deck_name) has total card weights $(used_weight) > deck_size $(deck_size)."))
    end

    if remaining > 0
        distribution[square] += remaining / deck_size
    end

    return distribution
end

"""
Resolve landing distribution using external TOML config deck/square definitions.
"""
function _resolve_landing_distribution_from_config(
    square::Int,
    board_size::Int;
    include_cards::Bool,
    card_rules::Symbol,
    cards_config::Dict{String, Any},
    depth::Int
)
    if !include_cards
        return _one_hot_square(square, board_size)
    end

    chance_squares = Set(Int.(cards_config["chance"]["squares"]))
    community_squares = Set(Int.(cards_config["community"]["squares"]))

    if square in community_squares
        return _deck_distribution("community", square, board_size; include_cards=include_cards, card_rules=card_rules, cards_config=cards_config, depth=depth)
    end

    if square in chance_squares
        return _deck_distribution("chance", square, board_size; include_cards=include_cards, card_rules=card_rules, cards_config=cards_config, depth=depth)
    end

    return _one_hot_square(square, board_size)
end

"""
Resolve the final landing distribution after applying board and card effects.

Starting from a landed `square`, this function applies:
- board rule `Go To Jail` (31 -> 11),
- Chance/Community effects from TOML config when available,
- or a legacy fallback card model if no config is provided.

Recursive calls are used for chained effects (for example `move_relative`
or drawing another card), with a depth guard to prevent infinite loops.

Returns:
- `Vector{Float64}` of length `board_size`, where each entry is the probability
    of ending the turn on that square.
"""
function _resolve_landing_distribution(square::Int, board_size::Int; include_cards::Bool, card_rules::Symbol, cards_config::Union{Nothing,Dict{String, Any}}=nothing, depth::Int=0)
    # Guard against infinite recursion when cards chain into other cards
    # (e.g., move_relative -> Chance/Community -> draw_chance).
    if depth > 6
        return _one_hot_square(square, board_size)
    end

    # This module currently models special Monopoly rules only for the standard 40-square board.
    if board_size != BOARD_SIZE
        return _one_hot_square(square, board_size)
    end

    # Board rule: landing on "Go To Jail" sends the player directly to Jail.
    if square == 31
        return _one_hot_square(11, board_size)
    end

    # Preferred path: resolve Chance/Community behavior from external TOML configuration.
    if include_cards && cards_config !== nothing
        return _resolve_landing_distribution_from_config(square, board_size; include_cards=include_cards, card_rules=card_rules, cards_config=cards_config, depth=depth)
    end

    # Fallback legacy behavior when no TOML configuration is provided.
    if include_cards && square in (3, 18, 34)
        distribution = zeros(Float64, board_size)
        distribution[1] += 1 / 16
        distribution[11] += 1 / 16
        distribution[square] += 14 / 16
        return distribution
    end

    if include_cards && square in (8, 23, 37)
        distribution = zeros(Float64, board_size)

        distribution[1] += 1 / 16
        distribution[11] += 1 / 16
        distribution[12] += 1 / 16
        distribution[25] += 1 / 16
        distribution[40] += 1 / 16
        distribution[_chance_fixed_railroad(card_rules)] += 1 / 16
        distribution[_nearest_railroad(square)] += 2 / 16
        distribution[_nearest_utility(square)] += 1 / 16

        # "Go back 3 spaces" can trigger another special square, so resolve recursively.
        go_back_distribution = _resolve_landing_distribution(mod1(square - 3, board_size), board_size; include_cards=include_cards, card_rules=card_rules, cards_config=cards_config, depth=depth + 1)
        distribution .+= (1 / 16) .* go_back_distribution

        distribution[square] += 6 / 16
        return distribution
    end

    return _one_hot_square(square, board_size)
end

"""
Build the one-turn transition matrix for Monopoly movement.

The returned matrix `T` is column-stochastic: `T[to, from]` is the probability
to be on square `to` after one throw starting from square `from`.

Behavior:
- Applies 2d6 roll probabilities.
- Applies board effect `Go To Jail`.
- Applies Chance/Community card effects when `include_cards=true`.
- Loads card definitions from TOML when available:
    - `card_rules=:fr` -> `docs/cards_transition_reference_fr.toml`
    - `card_rules=:us` -> `docs/cards_transition_reference_us.toml`
- If no TOML file is provided/found through defaults, legacy fallback rules are used.

Keyword arguments:
- `board_size`: board size (default 40).
- `include_cards`: enable/disable card effects.
- `card_rules`: `:fr` or `:us` (selects default card reference file).
- `card_rules_file`: optional custom TOML path overriding the default.
"""
function dice_transition_matrix(; board_size::Int=BOARD_SIZE, include_cards::Bool=true, card_rules::Symbol=:fr, card_rules_file::Union{Nothing,AbstractString}=nothing)
    if board_size <= 0
        throw(ArgumentError("board_size must be > 0, got $(board_size)."))
    end
    _validate_card_rules(card_rules)
    cards_config = include_cards ? _load_card_rules_config(card_rules, card_rules_file) : nothing

    transition = zeros(Float64, board_size, board_size)
    roll_probabilities = (
        2 => 1 / 36,
        3 => 2 / 36,
        4 => 3 / 36,
        5 => 4 / 36,
        6 => 5 / 36,
        7 => 6 / 36,
        8 => 5 / 36,
        9 => 4 / 36,
        10 => 3 / 36,
        11 => 2 / 36,
        12 => 1 / 36,
    )

    for from_square in 1:board_size
        for (roll_sum, probability) in roll_probabilities
            landed_square = mod1(from_square + roll_sum, board_size)
            resolved_distribution = _resolve_landing_distribution(landed_square, board_size; include_cards=include_cards, card_rules=card_rules, cards_config=cards_config)
            transition[:, from_square] .+= probability .* resolved_distribution
        end
    end

    return transition
end

"""
Apply one turn update to a probability vector using `transition_matrix`.
"""
function update_probability_after_throw(
    probabilities::AbstractVector{<:Real};
    transition_matrix::AbstractMatrix{<:Real}=dice_transition_matrix(board_size=length(probabilities))
)
    if length(probabilities) != size(transition_matrix, 2)
        throw(ArgumentError("Expected probabilities length $(size(transition_matrix, 2)), got $(length(probabilities))."))
    end
    if size(transition_matrix, 1) != size(transition_matrix, 2)
        throw(ArgumentError("transition_matrix must be square, got $(size(transition_matrix))."))
    end

    return transition_matrix * Float64.(probabilities)
end

"""
Iteratively apply turn updates `n` times.

Returns the probability vector after `n` throws.
"""
function simulate_n_throws(
    probabilities::AbstractVector{<:Real},
    n::Integer;
    transition_matrix::AbstractMatrix{<:Real}=dice_transition_matrix(board_size=length(probabilities))
)
    if n < 0
        throw(ArgumentError("n must be >= 0, got $(n)."))
    end

    updated = Float64.(probabilities)
    for _ in 1:n
        updated = update_probability_after_throw(updated; transition_matrix=transition_matrix)
    end

    return updated
end

"""
Return the French classic board labels (40 squares).
"""
function standard_board()
    return [
        "Départ", "Boulevard de Belleville", "Caisse de communauté", "Rue Lecourbe", "Impôt sur le revenu",
        "Gare Montparnasse", "Rue de Vaugirard", "Chance", "Rue de Courcelles", "Avenue de la République",
        "Prison / Simple visite", "Boulevard de la Villette", "Compagnie d'électricité", "Avenue de Neuilly", "Rue de Paradis",
        "Gare de Lyon", "Avenue Mozart", "Caisse de communauté", "Boulevard Saint-Michel", "Place Pigalle",
        "Parc Gratuit", "Avenue Matignon", "Chance", "Boulevard Malesherbes", "Avenue Henri-Martin",
        "Gare du Nord", "Faubourg Saint-Honoré", "Place de la Bourse", "Compagnie des eaux", "Rue La Fayette",
        "Allez en prison", "Avenue de Breteuil", "Avenue Foch", "Caisse de communauté", "Boulevard des Capucines",
        "Gare Saint-Lazare", "Chance", "Avenue des Champs-Élysées", "Taxe de luxe", "Rue de la Paix"
    ]
end

"""
Return the US Atlantic City board labels (40 squares).
"""
function standard_board_us()
    return [
        "GO", "Mediterranean Avenue", "Community Chest", "Baltic Avenue", "Income Tax",
        "Reading Railroad", "Oriental Avenue", "Chance", "Vermont Avenue", "Connecticut Avenue",
        "Jail / Just Visiting", "St. Charles Place", "Electric Company", "States Avenue", "Virginia Avenue",
        "Pennsylvania Railroad", "St. James Place", "Community Chest", "Tennessee Avenue", "New York Avenue",
        "Free Parking", "Kentucky Avenue", "Chance", "Indiana Avenue", "Illinois Avenue",
        "B&O Railroad", "Atlantic Avenue", "Ventnor Avenue", "Water Works", "Marvin Gardens",
        "Go To Jail", "Pacific Avenue", "North Carolina Avenue", "Community Chest", "Pennsylvania Avenue",
        "Short Line", "Chance", "Park Place", "Luxury Tax", "Boardwalk"
    ]
end


include("convergent_probabilities.jl")

end
