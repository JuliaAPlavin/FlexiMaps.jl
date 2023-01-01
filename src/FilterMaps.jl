module FilterMaps

using Accessors: delete

export 
    filtermap,
    flatmap, flatmap!, flatten, flatten!,
    findonly

include("filtermap.jl")
include("flatmap.jl")

function findonly(pred, A)
    ix = findfirst(pred, A)
    isnothing(ix) && throw(ArgumentError("no element satisfies the predicate"))
    isnothing(findnext(pred, A, nextind(A, ix))) || throw(ArgumentError("more than one element satisfies the predicate"))
    return ix
end


_eltype(::T) where {T} = _eltype(T)
function _eltype(::Type{T}) where {T}
    ETb = eltype(T)
    ETb != Any && return ETb
    # Base.eltype returns Any for mapped/flattened/... iterators
    # here we attempt to infer a tighter type
    ET = Core.Compiler.return_type(first, Tuple{T})
    ET === Union{} ? Any : ET
end

_valtype(X) = _eltype(values(X))

end
