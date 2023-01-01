"""
Transform collection `A` by applying `f` to each element. Elements with `isnothing(f(x))` are dropped. Return `Some(nothing)` from `f` to keep `nothing` in the result.
"""
function filtermap(f, A...)
    map(something, filter!(!isnothing, map(f, A...)))
end

function filtermap(f, A::Tuple)
    map(something, filter(!isnothing, map(f, A)))
end
