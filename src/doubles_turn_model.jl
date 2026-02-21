const _DICE_OUTCOMES = Tuple{Int, Bool, Float64}[
    (d1 + d2, d1 == d2, 1 / 36) for d1 in 1:6 for d2 in 1:6
]

"""
Compute end-of-turn distribution and expected in-turn landing counts from
`start_square` with `doubles_count` consecutive doubles already rolled in this turn.

Returns `(end_distribution, expected_landings)`.
"""
function _turn_end_and_landings_with_doubles(
    start_square::Int,
    doubles_count::Int,
    board_size::Int;
    include_cards::Bool,
    card_rules::Symbol,
    cards_config::Union{Nothing,Dict{String, Any}},
    cache::Dict{Tuple{Int, Int}, Tuple{Vector{Float64}, Vector{Float64}}}
)
    key = (start_square, doubles_count)
    if haskey(cache, key)
        return cache[key]
    end

    end_distribution = zeros(Float64, board_size)
    expected_landings = zeros(Float64, board_size)

    for (roll_sum, is_double, roll_probability) in _DICE_OUTCOMES
        if is_double && doubles_count == 2
            end_distribution[11] += roll_probability
            expected_landings[11] += roll_probability
            continue
        end

        landed_square = mod1(start_square + roll_sum, board_size)
        resolved_distribution = _resolve_landing_distribution(
            landed_square,
            board_size;
            include_cards=include_cards,
            card_rules=card_rules,
            cards_config=cards_config,
        )

        for target_square in 1:board_size
            target_probability = resolved_distribution[target_square]
            if target_probability == 0.0
                continue
            end

            path_probability = roll_probability * target_probability
            expected_landings[target_square] += path_probability

            forced_jail = landed_square == 31 || (target_square == 11 && landed_square != 11)

            if is_double && !forced_jail
                downstream_end, downstream_landings = _turn_end_and_landings_with_doubles(
                    target_square,
                    doubles_count + 1,
                    board_size;
                    include_cards=include_cards,
                    card_rules=card_rules,
                    cards_config=cards_config,
                    cache=cache,
                )

                end_distribution .+= path_probability .* downstream_end
                expected_landings .+= path_probability .* downstream_landings
            else
                end_distribution[target_square] += path_probability
            end
        end
    end

    cache[key] = (end_distribution, expected_landings)
    return cache[key]
end

"""
Compute expected square-landing counts over one full turn (including extra rolls from doubles).

`start_probabilities` is the distribution at turn start. The returned vector gives
expected number of landings on each square during that turn.
"""
function expected_landings_per_turn(
    start_probabilities::AbstractVector{<:Real};
    include_cards::Bool=true,
    include_doubles::Bool=true,
    card_rules::Symbol=:fr,
    card_rules_file::Union{Nothing,AbstractString}=nothing,
)
    board_size = length(start_probabilities)
    if board_size <= 0
        throw(ArgumentError("start_probabilities must not be empty."))
    end

    _validate_card_rules(card_rules)
    cards_config = include_cards ? _load_card_rules_config(card_rules, card_rules_file) : nothing

    start_distribution = Float64.(start_probabilities)
    total_mass = sum(start_distribution)
    if total_mass <= 0
        throw(ArgumentError("start_probabilities must have strictly positive total mass."))
    end
    start_distribution ./= total_mass

    if !include_doubles
        transition = dice_transition_matrix(
            board_size=board_size,
            include_cards=include_cards,
            include_doubles=false,
            card_rules=card_rules,
            card_rules_file=card_rules_file,
        )
        return transition * start_distribution
    end

    if board_size != BOARD_SIZE
        throw(ArgumentError("include_doubles=true currently supports board_size=$(BOARD_SIZE), got $(board_size)."))
    end

    cache = Dict{Tuple{Int, Int}, Tuple{Vector{Float64}, Vector{Float64}}}()
    expected_counts = zeros(Float64, board_size)

    for from_square in 1:board_size
        start_weight = start_distribution[from_square]
        if start_weight == 0.0
            continue
        end

        _, landing_counts = _turn_end_and_landings_with_doubles(
            from_square,
            0,
            board_size;
            include_cards=include_cards,
            card_rules=card_rules,
            cards_config=cards_config,
            cache=cache,
        )

        expected_counts .+= start_weight .* landing_counts
    end

    return expected_counts
end
