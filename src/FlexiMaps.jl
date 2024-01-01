module FlexiMaps

using Accessors
using InverseFunctions
using DataPipes

export 
    filtermap,
    mapview, maprange,
    flatmap, flatmap!, flatten, flatten!,
    flatten_parent, flatmap_parent,
    mapset, mapinsert, mapinsert⁻, mapsetview, mapinsertview

include("filtermap.jl")
include("mapview.jl")
include("flatmap.jl")
include("mapaccessors.jl")


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

# needed for proper _eltype of inferrably-empty iterators
_eltype(x::Base.Generator) = Core.Compiler.return_type(x.f, Tuple{_eltype(x.iter)})

end
