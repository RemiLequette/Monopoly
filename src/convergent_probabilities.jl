"""
Compute the long-run convergent (stationary) probabilities for a transition matrix.

Uses power iteration: `p_{k+1} = T * p_k` until the infinity-norm delta is below `tol`
or `max_iter` iterations are reached.

Returns a tuple `(probabilities, iterations, converged)`.
"""
function convergent_probabilities(
    transition_matrix::AbstractMatrix{<:Real};
    tol::Float64=1e-13,
    max_iter::Int=50_000,
    initial::Union{Nothing,AbstractVector{<:Real}}=nothing
)
    if size(transition_matrix, 1) != size(transition_matrix, 2)
        throw(ArgumentError("transition_matrix must be square, got $(size(transition_matrix))."))
    end
    if tol <= 0
        throw(ArgumentError("tol must be > 0, got $(tol)."))
    end
    if max_iter <= 0
        throw(ArgumentError("max_iter must be > 0, got $(max_iter)."))
    end

    n = size(transition_matrix, 1)
    p = if initial === nothing
        initial_probability_distribution(start_square=1)
    else
        if length(initial) != n
            throw(ArgumentError("Expected initial length $(n), got $(length(initial))."))
        end
        Float64.(initial)
    end

    for iter in 1:max_iter
        p_next = transition_matrix * p
        if maximum(abs.(p_next .- p)) < tol
            return p_next, iter, true
        end
        p = p_next
    end

    return p, max_iter, false
end
