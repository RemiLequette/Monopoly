module MonopolyInvestment

using Printf
using TOML
using Unicode

export load_property_financials_fr, property_financial_rows_fr, board_labels_fr, roi_streets_naked_fr, roi_railroads_fr, roi_utilities_fr, print_basic_roi_report_fr, roi_streets_naked_from_probabilities_fr, roi_railroads_from_probabilities_fr, roi_utilities_from_probabilities_fr, print_basic_roi_report_from_probabilities_fr

const _PROPERTY_RULES_CACHE = Dict{String, Dict{String, Any}}()

"""
Return French board labels used for ROI mapping (40 squares).
"""
function board_labels_fr()
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

function _normalize_label(label::AbstractString)
    folded = Unicode.normalize(lowercase(String(label)), :NFD)
    stripped = replace(folded, r"\p{Mn}+" => "")
    compact = replace(stripped, r"[^a-z0-9]+" => " ")
    return strip(compact)
end

function _build_board_index(labels::Vector{String})
    index_map = Dict{String, Int}()
    for (idx, label) in enumerate(labels)
        index_map[_normalize_label(label)] = idx
    end
    return index_map
end

function _resolve_square_index(name::String, group::String, board_index::Dict{String, Int})
    key = _normalize_label(name)
    if haskey(board_index, key)
        return board_index[key]
    end

    if key == _normalize_label("Rue de la Fayette") && haskey(board_index, _normalize_label("Rue La Fayette"))
        return board_index[_normalize_label("Rue La Fayette")]
    end

    if key == _normalize_label("Rue de Courcelles") && group == "Bleu Clair" && haskey(board_index, _normalize_label("Rue Lecourbe"))
        return board_index[_normalize_label("Rue Lecourbe")]
    end

    throw(ArgumentError("Could not map property to board square: $(name) (group=$(group))."))
end

"""
Return the default TOML property-financial file path for the French board.
"""
function _default_property_financials_file()
    return joinpath(@__DIR__, "..", "docs", "properties_cost_rent_fr.toml")
end

"""
Load and cache TOML financial data for the French Monopoly board.

If `property_rules_file` is provided, it overrides the default file path.
"""
function load_property_financials_fr(; property_rules_file::Union{Nothing,AbstractString}=nothing)
    file_path = property_rules_file === nothing ? _default_property_financials_file() : String(property_rules_file)
    absolute_path = isabspath(file_path) ? file_path : normpath(joinpath(@__DIR__, "..", file_path))

    if !isfile(absolute_path)
        throw(ArgumentError("property financials file not found: $(absolute_path)"))
    end

    if haskey(_PROPERTY_RULES_CACHE, absolute_path)
        return _PROPERTY_RULES_CACHE[absolute_path]
    end

    parsed = TOML.parsefile(absolute_path)

    if !haskey(parsed, "terrains") || !haskey(parsed, "gares") || !haskey(parsed, "compagnies")
        throw(ArgumentError("Invalid property financials TOML format. Expected keys: terrains, gares, compagnies."))
    end

    _PROPERTY_RULES_CACHE[absolute_path] = parsed
    return parsed
end

"""
Return flattened, analysis-ready rows for French Monopoly financial data.

Rows include streets, railroads and utilities with normalized keys.
"""
function property_financial_rows_fr(; property_rules_file::Union{Nothing,AbstractString}=nothing)
    config = load_property_financials_fr(property_rules_file=property_rules_file)
    rows = Vector{NamedTuple}()

    for terrain_group_raw in config["terrains"]
        terrain_group = Dict{String, Any}(terrain_group_raw)
        group_name = String(terrain_group["group"])
        house_cost = Int(terrain_group["house_cost"])

        for property_raw in terrain_group["properties"]
            property = Dict{String, Any}(property_raw)
            rents = Int.(property["rents"])
            if length(rents) != 6
                property_name = String(property["name"])
                throw(ArgumentError("Each street must define 6 rent levels (base, 1-4 houses, hotel). Property: $(property_name)."))
            end

            push!(rows, (
                category="street",
                group=group_name,
                name=String(property["name"]),
                purchase_price=Int(property["purchase_price"]),
                mortgage=Int(property["mortgage"]),
                house_cost=house_cost,
                rent_base=rents[1],
                rent_1_house=rents[2],
                rent_2_houses=rents[3],
                rent_3_houses=rents[4],
                rent_4_houses=rents[5],
                rent_hotel=rents[6],
            ))
        end
    end

    gares = Dict{String, Any}(config["gares"])
    gares_rents = Int.(gares["rents"])
    for gare_name in gares["names"]
        push!(rows, (
            category="railroad",
            group="Gares",
            name=String(gare_name),
            purchase_price=Int(gares["purchase_price"]),
            mortgage=Int(gares["mortgage"]),
            rent_1_owned=gares_rents[1],
            rent_2_owned=gares_rents[2],
            rent_3_owned=gares_rents[3],
            rent_4_owned=gares_rents[4],
        ))
    end

    compagnies = Dict{String, Any}(config["compagnies"])
    rent_multipliers = Dict{String, Any}(compagnies["rent_multipliers"])
    for company_name in compagnies["names"]
        push!(rows, (
            category="utility",
            group="Compagnies",
            name=String(company_name),
            purchase_price=Int(compagnies["purchase_price"]),
            mortgage=Int(compagnies["mortgage"]),
            multiplier_1_owned=Int(rent_multipliers["one_owned"]),
            multiplier_2_owned=Int(rent_multipliers["two_owned"]),
        ))
    end

    return rows
end

"""
ROI for each street property in naked state (no monopoly bonus).

Expected gain is computed per full opponent turn:
`expected_gain = expected_landings_per_turn[square] * rent_base`
and ROI is `expected_gain / purchase_price`.
"""
function roi_streets_naked_fr(
    expected_landings_per_turn::AbstractVector{<:Real};
    property_rules_file::Union{Nothing,AbstractString}=nothing,
    board_labels::Vector{String}=board_labels_fr(),
)
    if length(expected_landings_per_turn) != length(board_labels)
        throw(ArgumentError("expected_landings_per_turn must have length $(length(board_labels)), got $(length(expected_landings_per_turn))."))
    end

    rows = property_financial_rows_fr(property_rules_file=property_rules_file)
    board_index = _build_board_index(board_labels)
    results = Vector{NamedTuple}()

    for row in rows
        if row.category != "street"
            continue
        end
        square_idx = _resolve_square_index(row.name, row.group, board_index)
        expected_gain = Float64(expected_landings_per_turn[square_idx]) * row.rent_base
        roi = expected_gain / row.purchase_price

        push!(results, (
            name=row.name,
            group=row.group,
            square=square_idx,
            cost=row.purchase_price,
            expected_gain=expected_gain,
            roi=roi,
        ))
    end

    return sort(results; by=r -> r.roi, rev=true)
end

"""
ROI summary for railroad strategies with 1 to 4 railroads owned.

For each ownership count `n`, this function selects the `n` railroads with highest
expected landings, then computes:
- cost = `n * railroad_purchase_price`
- expected_gain = `rent_n * sum(landings_of_selected_railroads)`
- roi = `expected_gain / cost`
"""
function roi_railroads_fr(
    expected_landings_per_turn::AbstractVector{<:Real};
    property_rules_file::Union{Nothing,AbstractString}=nothing,
    board_labels::Vector{String}=board_labels_fr(),
)
    if length(expected_landings_per_turn) != length(board_labels)
        throw(ArgumentError("expected_landings_per_turn must have length $(length(board_labels)), got $(length(expected_landings_per_turn))."))
    end

    config = load_property_financials_fr(property_rules_file=property_rules_file)
    gares = Dict{String, Any}(config["gares"])
    railway_names = String.(gares["names"])
    rents = Int.(gares["rents"])
    purchase_price = Int(gares["purchase_price"])

    board_index = _build_board_index(board_labels)
    railway_rows = Vector{NamedTuple}()
    for name in railway_names
        idx = _resolve_square_index(name, "Gares", board_index)
        push!(railway_rows, (name=name, square=idx, landings=Float64(expected_landings_per_turn[idx])))
    end

    sorted_railways = sort(railway_rows; by=r -> r.landings, rev=true)
    results = Vector{NamedTuple}()

    for owned_count in 1:4
        selected = sorted_railways[1:owned_count]
        landings_sum = sum(r.landings for r in selected)
        expected_gain = rents[owned_count] * landings_sum
        cost = owned_count * purchase_price
        roi = expected_gain / cost

        push!(results, (
            owned_count=owned_count,
            selected=String[r.name for r in selected],
            cost=cost,
            expected_gain=expected_gain,
            roi=roi,
        ))
    end

    return sort(results; by=r -> r.roi, rev=true)
end

"""
ROI summary for utility strategies with 1 to 2 utilities owned.

For each ownership count `n`, this function selects the `n` utilities with highest
expected landings, then computes:
- expected utility rent per landing = multiplier * expected_dice_sum
- cost = `n * utility_purchase_price`
- expected_gain = `expected_rent * sum(landings_of_selected_utilities)`
- roi = `expected_gain / cost`
"""
function roi_utilities_fr(
    expected_landings_per_turn::AbstractVector{<:Real};
    property_rules_file::Union{Nothing,AbstractString}=nothing,
    board_labels::Vector{String}=board_labels_fr(),
    expected_dice_sum::Real=7.0,
)
    if length(expected_landings_per_turn) != length(board_labels)
        throw(ArgumentError("expected_landings_per_turn must have length $(length(board_labels)), got $(length(expected_landings_per_turn))."))
    end
    if expected_dice_sum <= 0
        throw(ArgumentError("expected_dice_sum must be > 0, got $(expected_dice_sum)."))
    end

    config = load_property_financials_fr(property_rules_file=property_rules_file)
    compagnies = Dict{String, Any}(config["compagnies"])
    utility_names = String.(compagnies["names"])
    purchase_price = Int(compagnies["purchase_price"])
    multipliers = Dict{String, Any}(compagnies["rent_multipliers"])
    utility_multipliers = [Int(multipliers["one_owned"]), Int(multipliers["two_owned"])]

    board_index = _build_board_index(board_labels)
    utility_rows = Vector{NamedTuple}()
    for name in utility_names
        idx = _resolve_square_index(name, "Compagnies", board_index)
        push!(utility_rows, (name=name, square=idx, landings=Float64(expected_landings_per_turn[idx])))
    end

    sorted_utilities = sort(utility_rows; by=r -> r.landings, rev=true)
    results = Vector{NamedTuple}()

    for owned_count in 1:2
        selected = sorted_utilities[1:owned_count]
        landings_sum = sum(r.landings for r in selected)
        expected_rent_per_landing = utility_multipliers[owned_count] * Float64(expected_dice_sum)
        expected_gain = expected_rent_per_landing * landings_sum
        cost = owned_count * purchase_price
        roi = expected_gain / cost

        push!(results, (
            owned_count=owned_count,
            selected=String[r.name for r in selected],
            cost=cost,
            expected_gain=expected_gain,
            roi=roi,
        ))
    end

    return sort(results; by=r -> r.roi, rev=true)
end

"""
Print a basic French ROI report:
- each street in naked state,
- railroad strategies (1..4 owned),
- utility strategies (1..2 owned).
"""
function print_basic_roi_report_fr(
    expected_landings_per_turn::AbstractVector{<:Real};
    property_rules_file::Union{Nothing,AbstractString}=nothing,
    board_labels::Vector{String}=board_labels_fr(),
    expected_dice_sum::Real=7.0,
    gain_label::String="espérance",
)
    streets = roi_streets_naked_fr(
        expected_landings_per_turn;
        property_rules_file=property_rules_file,
        board_labels=board_labels,
    )
    railways = roi_railroads_fr(
        expected_landings_per_turn;
        property_rules_file=property_rules_file,
        board_labels=board_labels,
    )
    utilities = roi_utilities_fr(
        expected_landings_per_turn;
        property_rules_file=property_rules_file,
        board_labels=board_labels,
        expected_dice_sum=expected_dice_sum,
    )

    println("ROI — Terrains nus (sans monopole):")
    for row in streets
        @printf("%2d - %-30s | coût=%4d | %s=%8.4f | ROI=%8.4f%%\n", row.square, row.name, row.cost, gain_label, row.expected_gain, 100 * row.roi)
    end

    println("\nROI — Gares (stratégies 1 à 4):")
    for row in railways
        @printf("%d gare(s) | coût=%4d | %s=%8.4f | ROI=%8.4f%% | sélection=%s\n", row.owned_count, row.cost, gain_label, row.expected_gain, 100 * row.roi, join(row.selected, ", "))
    end

    println("\nROI — Compagnies (stratégies 1 à 2):")
    for row in utilities
        @printf("%d compagnie(s) | coût=%4d | %s=%8.4f | ROI=%8.4f%% | sélection=%s\n", row.owned_count, row.cost, gain_label, row.expected_gain, 100 * row.roi, join(row.selected, ", "))
    end

    return (
        streets=streets,
        railroads=railways,
        utilities=utilities,
    )
end

"""
Alias API when input vector is explicitly turn-boundary probabilities.
"""
function roi_streets_naked_from_probabilities_fr(
    turn_probabilities::AbstractVector{<:Real};
    property_rules_file::Union{Nothing,AbstractString}=nothing,
    board_labels::Vector{String}=board_labels_fr(),
)
    return roi_streets_naked_fr(
        turn_probabilities;
        property_rules_file=property_rules_file,
        board_labels=board_labels,
    )
end

"""
Alias API when input vector is explicitly turn-boundary probabilities.
"""
function roi_railroads_from_probabilities_fr(
    turn_probabilities::AbstractVector{<:Real};
    property_rules_file::Union{Nothing,AbstractString}=nothing,
    board_labels::Vector{String}=board_labels_fr(),
)
    return roi_railroads_fr(
        turn_probabilities;
        property_rules_file=property_rules_file,
        board_labels=board_labels,
    )
end

"""
Alias API when input vector is explicitly turn-boundary probabilities.
"""
function roi_utilities_from_probabilities_fr(
    turn_probabilities::AbstractVector{<:Real};
    property_rules_file::Union{Nothing,AbstractString}=nothing,
    board_labels::Vector{String}=board_labels_fr(),
    expected_dice_sum::Real=7.0,
)
    return roi_utilities_fr(
        turn_probabilities;
        property_rules_file=property_rules_file,
        board_labels=board_labels,
        expected_dice_sum=expected_dice_sum,
    )
end

"""
Print ROI report using turn-boundary probabilities as explicit input metric.
"""
function print_basic_roi_report_from_probabilities_fr(
    turn_probabilities::AbstractVector{<:Real};
    property_rules_file::Union{Nothing,AbstractString}=nothing,
    board_labels::Vector{String}=board_labels_fr(),
    expected_dice_sum::Real=7.0,
)
    return print_basic_roi_report_fr(
        turn_probabilities;
        property_rules_file=property_rules_file,
        board_labels=board_labels,
        expected_dice_sum=expected_dice_sum,
        gain_label="gain_prob",
    )
end

end
