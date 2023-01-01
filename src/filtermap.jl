"""    filtermap(f, X)

Map and filter a collection in one go.
Most useful when the mapped function shares some computations with the filter predicate.

Returns same as `map(f, X)`, dropping elements where `f(x)` is `nothing`.
Return `Some(nothing)` from `f` to keep `nothing` in the result.
"""
function filtermap(f, A...)
    map(something, filter!(!isnothing, map(f, A...)))
end

function filtermap(f, A::Tuple)
    map(something, filter(!isnothing, map(f, A)))
end
