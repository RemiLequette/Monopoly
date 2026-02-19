using Plots

function board_probability_matrix(probabilities::AbstractVector{<:Real})
    if length(probabilities) != BOARD_SIZE
        throw(ArgumentError("Expected $(BOARD_SIZE) probabilities, got $(length(probabilities))."))
    end

    matrix = fill(NaN, 11, 11)
    positions = _board_positions()

    for idx in 1:BOARD_SIZE
        row, col = positions[idx]
        matrix[row, col] = 100 * float(probabilities[idx])
    end

    return matrix
end

function _traditional_square_color(idx::Int)
    if idx in (11, 31)
        return "#F97316"
    elseif idx in (1, 21)
        return "#E5E7EB"
    elseif idx in (2, 4)
        return "#8B4513"
    elseif idx in (7, 9, 10)
        return "#87CEEB"
    elseif idx in (12, 14, 15)
        return "#FF69B4"
    elseif idx in (17, 19, 20)
        return "#FFA500"
    elseif idx in (22, 24, 25)
        return "#FF0000"
    elseif idx in (27, 28, 30)
        return "#FFD700"
    elseif idx in (32, 33, 35)
        return "#008000"
    elseif idx == 40
        return "#1E3A8A"
    elseif idx in (6, 16, 26, 36)
        return "#111111"
    elseif idx in (13, 29)
        return "#E5E7EB"
    elseif idx in (8, 23, 37)
        return "#F97316"
    elseif idx in (3, 18, 34)
        return "#60A5FA"
    elseif idx in (5, 39)
        return "#9CA3AF"
    else
        return "#F3F4F6"
    end
end

function _probability_intensity(probabilities_pct::AbstractVector{<:Real})
    pmin, pmax = extrema(probabilities_pct)
    if pmax ≈ pmin
        return fill(0.0, length(probabilities_pct))
    end
    return 100 .* (probabilities_pct .- pmin) ./ (pmax - pmin)
end

function _is_light_hex_color(hex::AbstractString)
    clean = replace(hex, "#" => "")
    if length(clean) != 6
        return false
    end

    r = parse(Int, clean[1:2], base=16)
    g = parse(Int, clean[3:4], base=16)
    b = parse(Int, clean[5:6], base=16)
    luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return luminance >= 145
end

function _rect_shape(x0::Real, x1::Real, y0::Real, y1::Real)
    return Shape([x0, x1, x1, x0], [y0, y0, y1, y1])
end

function plot_board_heatmap(
    probabilities::AbstractVector{<:Real};
    labels::Vector{String}=standard_board(),
    label_chars::Int=12,
    title::String="Monopoly board probabilities"
)
    if length(probabilities) != BOARD_SIZE
        throw(ArgumentError("Expected $(BOARD_SIZE) probabilities, got $(length(probabilities))."))
    end
    if length(labels) != BOARD_SIZE
        throw(ArgumentError("Expected $(BOARD_SIZE) labels, got $(length(labels))."))
    end

    probabilities_pct = 100 .* float.(probabilities)
    pmin, pmax = extrema(probabilities_pct)
    pmid = (pmin + pmax) / 2
    intensity = _probability_intensity(probabilities_pct)
    gradient = cgrad(:YlOrRd)
    positions = _board_positions()

    p = plot(
        xlims=(0, 11),
        ylims=(-1.4, 11),
        aspect_ratio=1,
        legend=false,
        grid=false,
        ticks=false,
        framestyle=:box,
        title=title,
        size=(1200, 1200),
        margin=6Plots.mm,
        background_color=:white
    )

    for idx in 1:BOARD_SIZE
        row, col = positions[idx]

        x0 = col - 1
        x1 = col
        y0 = 11 - row
        y1 = 12 - row

        band_y0 = y0 + 2 / 3
        band_y1 = y1

        body_color = gradient[clamp(intensity[idx] / 100, 0, 1)]
        band_color = _traditional_square_color(idx)

        plot!(
            p,
            _rect_shape(x0, x1, y0, band_y0);
            fillcolor=body_color,
            linecolor=:black,
            linewidth=0.5
        )

        plot!(
            p,
            _rect_shape(x0, x1, band_y0, band_y1);
            fillcolor=band_color,
            linecolor=:black,
            linewidth=0.5
        )

        short_label = _truncate_label(labels[idx], label_chars)
        band_text_color = _is_light_hex_color(band_color) ? :black : :white

        annotate!(
            p,
            x0 + 0.5,
            band_y0 + (band_y1 - band_y0) * 0.5,
            text(short_label, 6, band_text_color, :center)
        )

        annotate!(
            p,
            x0 + 0.5,
            y0 + (band_y0 - y0) * 0.5,
            text(@sprintf("%.2f%%", probabilities_pct[idx]), 7, :black, :center)
        )
    end

    legend_x0 = 2.0
    legend_x1 = 9.0
    legend_y0 = -1.0
    legend_y1 = -0.55
    legend_steps = 80

    for step in 1:legend_steps
        t0 = (step - 1) / legend_steps
        t1 = step / legend_steps
        lx0 = legend_x0 + (legend_x1 - legend_x0) * t0
        lx1 = legend_x0 + (legend_x1 - legend_x0) * t1
        plot!(
            p,
            _rect_shape(lx0, lx1, legend_y0, legend_y1);
            fillcolor=gradient[t0],
            linecolor=gradient[t0],
            linewidth=0
        )
    end

    plot!(
        p,
        _rect_shape(legend_x0, legend_x1, legend_y0, legend_y1);
        fillalpha=0,
        linecolor=:black,
        linewidth=0.6
    )

    annotate!(p, 5.5, -0.2, text("Probability color scale (min-max)", 10, :black, :center))
    annotate!(p, legend_x0, legend_y0 - 0.12, text(@sprintf("%.2f%%", pmin), 9, :black, :left))
    annotate!(p, (legend_x0 + legend_x1) / 2, legend_y0 - 0.12, text(@sprintf("%.2f%%", pmid), 9, :black, :center))
    annotate!(p, legend_x1, legend_y0 - 0.12, text(@sprintf("%.2f%%", pmax), 9, :black, :right))

    annotate!(p, 5.5, 5.5, text("MONOPOLY", 20, :black, :center))
    return p
end
