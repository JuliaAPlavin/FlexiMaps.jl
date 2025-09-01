"""    filtermap(f, X)

Map and filter a collection in one go.
Most useful when the mapped function shares some computations with the filter predicate.

Returns same as `map(f, X)`, dropping elements where `f(x)` is `nothing`.
Return `Some(nothing)` from `f` to keep `nothing` in the result.
"""
function filtermap end

filtermap(f::F, A::Union{Tuple,NamedTuple}) where {F} = map(something, filter(!isnothing, map(f, A)))

function filtermap(f::F, A) where {F}
    resT_raw = Base.promote_op(f, eltype(A))
    resT_nn = Base.nonnothingtype(resT_raw)
    resT = Base.promote_op(something, resT_nn)
    res = _empty(A, resT)
    for x in A
        y = f(x)
        if !isnothing(y)
            push!(res, something(y))
        end
    end
    return res
end

_empty(A::AbstractVector, T) = empty(A, T)
_empty(A::AbstractArray, T) = similar(A, T, 0)
_empty(A, T) = Vector{T}()
