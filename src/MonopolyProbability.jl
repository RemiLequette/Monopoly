module MonopolyProbability

using Printf

export BOARD_SIZE, standard_board, standard_board_us, board_square, print_board_square, board_probability_matrix, plot_board_heatmap

const BOARD_SIZE = 40

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

function _truncate_label(label::AbstractString, max_chars::Int)
    chars = collect(label)
    if length(chars) <= max_chars
        return label
    end
    return String(chars[1:max_chars-1]) * "…"
end

function _board_positions()
    positions = Tuple{Int, Int}[]

    for col in 11:-1:1
        push!(positions, (11, col))
    end
    for row in 10:-1:2
        push!(positions, (row, 1))
    end
    for col in 1:11
        push!(positions, (1, col))
    end
    for row in 2:11
        push!(positions, (row, 11))
    end

    return positions
end

function board_square(probabilities::AbstractVector{<:Real}; labels::Vector{String}=standard_board(), label_chars::Int=10, digits::Int=2)
    if length(probabilities) != BOARD_SIZE
        throw(ArgumentError("Expected $(BOARD_SIZE) probabilities, got $(length(probabilities))."))
    end
    if length(labels) != BOARD_SIZE
        throw(ArgumentError("Expected $(BOARD_SIZE) labels, got $(length(labels))."))
    end

    grid = fill("", 11, 11)
    positions = _board_positions()

    for idx in 1:BOARD_SIZE
        row, col = positions[idx]
        short_label = _truncate_label(labels[idx], label_chars)
        pct = 100 * float(probabilities[idx])
        grid[row, col] = string(short_label, "\n", @sprintf("%.*f%%", digits, pct))
    end

    grid[6, 6] = "MONOPOLY"
    return grid
end

function print_board_square(probabilities::AbstractVector{<:Real}; labels::Vector{String}=standard_board(), label_chars::Int=10, digits::Int=2)
    grid = board_square(probabilities; labels=labels, label_chars=label_chars, digits=digits)

    for row in 1:size(grid, 1)
        cells = String[]
        for col in 1:size(grid, 2)
            cell = replace(grid[row, col], "\n" => " | ")
            push!(cells, rpad(cell, 24))
        end
        println(join(cells, " "))
    end

    return grid
end

include("Visualization.jl")

end
