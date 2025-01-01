module AxisKeysExt

using AxisKeys: AxisKeys, NamedDims, KeyedArray, dimnames, axiskeys, hasnames, dim, getkey
using FlexiMaps: MappedArray

const MA_KA = MappedArray{<:Any,<:Any,<:Any,<:KeyedArray}

AxisKeys.dimnames(A::MappedArray, args...) = dimnames(parent(A), args...)
AxisKeys.dimnames(A::MappedArray, d::Integer) = dimnames(parent(A), d)  # disambiguation
AxisKeys.axiskeys(A::MappedArray, args...) = axiskeys(parent(A), args...)
AxisKeys.dim(A::MappedArray, args...) = dim(parent(A), args...)
AxisKeys.hasnames(A::MappedArray) = hasnames(parent(A))

@inline Base.@propagate_inbounds function Base.getindex(A::MA_KA; kw...)
    hasnames(A) || error("must have names!")
    inds = NamedDims.order_named_inds(Val(dimnames(A)); kw...)
    getindex(A, inds...)
end
@inline Base.@propagate_inbounds function Base.view(A::MA_KA; kw...)
    hasnames(A) || error("must have names!")
    inds = NamedDims.order_named_inds(Val(dimnames(A)); kw...)
    view(A, inds...)
end

@inline Base.@propagate_inbounds (A::MA_KA)(args...) = getkey(A, args...)
@inline Base.@propagate_inbounds (A::MA_KA)(;kw...) = getkey(A; kw...)

end
