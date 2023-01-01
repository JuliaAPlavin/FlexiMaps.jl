module FlexiMaps

using Accessors
using InverseFunctions

export 
    filtermap,
    mapview, maprange,
    flatmap, flatmap!, flatten, flatten!

include("filtermap.jl")
include("mapview.jl")
include("flatmap.jl")


_eltype(::T) where {T} = _eltype(T)
_eltype(::Type{Union{}}) = Union{}
function _eltype(::Type{T}) where {T}
    ETb = eltype(T)
    ETb != Any && return ETb
    # Base.eltype returns Any for mapped/flattened/... iterators
    # here we attempt to infer a tighter type:
    ET = Core.Compiler.return_type(Base._iterator_upper_bound, Tuple{T})
    # Union{} can be returned for empty iterators
    # should it be replaced with Any?
    # ET === Union{} ? Any : ET
end

end
