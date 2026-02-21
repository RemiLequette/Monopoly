const _DICE_OUTCOMES = Tuple{Int, Bool, Float64}[
    (d1 + d2, d1 == d2, 1 / 36) for d1 in 1:6 for d2 in 1:6
]

_expanded_state_index(square::Int, in_jail::Bool, board_size::Int) = in_jail ? (board_size + square) : square

"""
Compute end-of-turn distribution and expected in-turn landing counts from
`start_square` with `doubles_count` consecutive doubles already rolled in this turn.

Returns `(end_distribution, expected_landings)`.
"""
function _turn_end_and_landings_with_doubles(
    start_square::Int,
    doubles_count::Int,
    start_in_jail::Bool,
    board_size::Int;
    include_cards::Bool,
    jail_policy::Symbol,
    card_rules::Symbol,
    cards_config::Union{Nothing,Dict{String, Any}},
    cache::Dict{Tuple{Int, Int, Bool}, Tuple{Vector{Float64}, Vector{Float64}}}
)
    key = (start_square, doubles_count, start_in_jail)
    if haskey(cache, key)
        return cache[key]
    end

    end_distribution = zeros(Float64, 2 * board_size)
    expected_landings = zeros(Float64, board_size)

    if doubles_count == 0 && start_in_jail && start_square == 11 && jail_policy == :try_doubles_then_pay
        for (roll_sum, is_double, roll_probability) in _DICE_OUTCOMES
            if !is_double
                end_distribution[_expanded_state_index(11, true, board_size)] += roll_probability
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
                end_distribution[_expanded_state_index(target_square, forced_jail, board_size)] += path_probability
            end
        end

        cache[key] = (end_distribution, expected_landings)
        return cache[key]
    end

    for (roll_sum, is_double, roll_probability) in _DICE_OUTCOMES
        if is_double && doubles_count == 2
            end_distribution[_expanded_state_index(11, true, board_size)] += roll_probability
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
                    false,
                    board_size;
                    include_cards=include_cards,
                    jail_policy=jail_policy,
                    card_rules=card_rules,
                    cards_config=cards_config,
                    cache=cache,
                )

                end_distribution .+= path_probability .* downstream_end
                expected_landings .+= path_probability .* downstream_landings
            else
                end_distribution[_expanded_state_index(target_square, forced_jail, board_size)] += path_probability
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
    jail_policy::Symbol=:pay_immediately,
    card_rules::Symbol=:fr,
    card_rules_file::Union{Nothing,AbstractString}=nothing,
)
    state_count = length(start_probabilities)
    if state_count <= 0
        throw(ArgumentError("start_probabilities must not be empty."))
    end

    has_expanded_jail_state = state_count == 2 * BOARD_SIZE
    board_size = has_expanded_jail_state ? BOARD_SIZE : state_count

    _validate_card_rules(card_rules)
    _validate_jail_policy(jail_policy)
    cards_config = include_cards ? _load_card_rules_config(card_rules, card_rules_file) : nothing

    start_distribution = Float64.(start_probabilities)
    total_mass = sum(start_distribution)
    if total_mass <= 0
        throw(ArgumentError("start_probabilities must have strictly positive total mass."))
    end
    start_distribution ./= total_mass

    if has_expanded_jail_state && !include_doubles
        throw(ArgumentError("expanded jail-state start_probabilities require include_doubles=true."))
    end

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

    if !has_expanded_jail_state && jail_policy == :try_doubles_then_pay
        throw(ArgumentError("jail_policy=:try_doubles_then_pay requires an expanded jail-state start distribution (length $(2 * BOARD_SIZE)). Use expand_turn_start_distribution(...) to build one."))
    end

    cache = Dict{Tuple{Int, Int, Bool}, Tuple{Vector{Float64}, Vector{Float64}}}()
    expected_counts = zeros(Float64, board_size)

    if has_expanded_jail_state
        for from_square in 1:board_size
            for from_in_jail in (false, true)
                from_index = _expanded_state_index(from_square, from_in_jail, board_size)
                start_weight = start_distribution[from_index]
                if start_weight == 0.0
                    continue
                end

                _, landing_counts = _turn_end_and_landings_with_doubles(
                    from_square,
                    0,
                    from_in_jail && from_square == 11,
                    board_size;
                    include_cards=include_cards,
                    jail_policy=jail_policy,
                    card_rules=card_rules,
                    cards_config=cards_config,
                    cache=cache,
                )

                expected_counts .+= start_weight .* landing_counts
            end
        end
    else
        for from_square in 1:board_size
            start_weight = start_distribution[from_square]
            if start_weight == 0.0
                continue
            end

            _, landing_counts = _turn_end_and_landings_with_doubles(
                from_square,
                0,
                false,
                board_size;
                include_cards=include_cards,
                jail_policy=jail_policy,
                card_rules=card_rules,
                cards_config=cards_config,
                cache=cache,
            )

            expected_counts .+= start_weight .* landing_counts
        end
    end

    return expected_counts
end

"""
Expand a 40-square turn-start distribution into `(square, in_jail)` state space.

The returned vector has length `2*BOARD_SIZE` and ordering:
- indices `1:BOARD_SIZE`: `(square, in_jail=false)`
- indices `BOARD_SIZE+1:2*BOARD_SIZE`: `(square, in_jail=true)`

Only square 11 can carry in-jail mass; all other in-jail states remain zero.
"""
function expand_turn_start_distribution(
    square_probabilities::AbstractVector{<:Real};
    jail_probability_at_11::Real=0.0,
)
    if length(square_probabilities) != BOARD_SIZE
        throw(ArgumentError("square_probabilities must have length $(BOARD_SIZE), got $(length(square_probabilities))."))
    end
    if !(0.0 <= jail_probability_at_11 <= 1.0)
        throw(ArgumentError("jail_probability_at_11 must be between 0 and 1, got $(jail_probability_at_11)."))
    end

    square_distribution = Float64.(square_probabilities)
    total_mass = sum(square_distribution)
    if total_mass <= 0
        throw(ArgumentError("square_probabilities must have strictly positive total mass."))
    end
    square_distribution ./= total_mass

    expanded = zeros(Float64, 2 * BOARD_SIZE)
    expanded[1:BOARD_SIZE] .= square_distribution

    mass_on_11 = square_distribution[11]
    jail_mass_11 = mass_on_11 * Float64(jail_probability_at_11)
    expanded[11] -= jail_mass_11
    expanded[BOARD_SIZE + 11] = jail_mass_11

    return expanded
end

"""
Collapse an expanded `(square, in_jail)` distribution back to 40 board squares.
"""
function collapse_turn_state_distribution(expanded_probabilities::AbstractVector{<:Real})
    if length(expanded_probabilities) != 2 * BOARD_SIZE
        throw(ArgumentError("expanded_probabilities must have length $(2 * BOARD_SIZE), got $(length(expanded_probabilities))."))
    end

    expanded_distribution = Float64.(expanded_probabilities)
    return expanded_distribution[1:BOARD_SIZE] .+ expanded_distribution[(BOARD_SIZE + 1):(2 * BOARD_SIZE)]
end

"""
Build the one-turn transition matrix on expanded `(square, in_jail)` state space.

The returned matrix has shape `(2*BOARD_SIZE, 2*BOARD_SIZE)`.
"""
function dice_transition_matrix_with_jail_state(
    ;
    include_cards::Bool=true,
    include_doubles::Bool=true,
    jail_policy::Symbol=:try_doubles_then_pay,
    card_rules::Symbol=:fr,
    card_rules_file::Union{Nothing,AbstractString}=nothing,
)
    if !include_doubles
        throw(ArgumentError("dice_transition_matrix_with_jail_state requires include_doubles=true."))
    end

    _validate_card_rules(card_rules)
    _validate_jail_policy(jail_policy)
    cards_config = include_cards ? _load_card_rules_config(card_rules, card_rules_file) : nothing

    board_size = BOARD_SIZE
    transition = zeros(Float64, 2 * board_size, 2 * board_size)
    cache = Dict{Tuple{Int, Int, Bool}, Tuple{Vector{Float64}, Vector{Float64}}}()

    for from_square in 1:board_size
        for from_in_jail in (false, true)
            from_index = _expanded_state_index(from_square, from_in_jail, board_size)

            end_distribution, _ = _turn_end_and_landings_with_doubles(
                from_square,
                0,
                from_in_jail && from_square == 11,
                board_size;
                include_cards=include_cards,
                jail_policy=jail_policy,
                card_rules=card_rules,
                cards_config=cards_config,
                cache=cache,
            )

            transition[:, from_index] .= end_distribution
        end
    end

    return transition
end
