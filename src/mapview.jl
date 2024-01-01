struct MappedArray{T, N, F, TX <: AbstractArray{<:Any, N}} <: AbstractArray{T, N}
    f::F
    parent::TX
end
MappedArray{T, N}(f, X) where {T, N} = MappedArray{T, N, typeof(f), typeof(X)}(f, X)
Accessors.constructorof(::Type{<:MappedArray{T, N}}) where {T, N} = MappedArray{T, N}
parent_type(::Type{<:MappedArray{T, N, F, TX}}) where {T, N, F, TX} = TX

Base.@propagate_inbounds Base.getindex(A::MappedArray, I...) = _getindex(A, to_indices(A, I))
Base.@propagate_inbounds _getindex(A::MappedArray, I::Tuple{Vararg{Integer}}) = _f(A)(parent(A)[I...])
Base.@propagate_inbounds _getindex(A::MappedArray, I::Tuple) = @set parent(A) = parent(A)[I...]

Base.@propagate_inbounds Base.setindex!(A::MappedArray, v, I...) = _setindex!(A, v, to_indices(A, I))
Base.@propagate_inbounds _setindex!(A::MappedArray, v, I::Tuple{Vararg{Integer}}) = (parent(A)[I...] = set(parent(A)[I...], _f(A), v); A)
Base.@propagate_inbounds _setindex!(A::MappedArray, v, I::Tuple) = (parent(A)[I...] = set.(parent(A)[I...], Ref(_f(A)), v); A)

Base.append!(A::MappedArray, iter) = (append!(parent(A), map(inverse(_f(A)), iter)); A)


struct MappedRange{T, F, TX <: AbstractRange} <: AbstractRange{T}
    f::F
    parent::TX
end
MappedRange{T}(f, X) where {T} = MappedRange{T, typeof(f), typeof(X)}(f, X)
Accessors.constructorof(::Type{<:MappedRange{T}}) where {T} = MappedRange{T}
parent_type(::Type{<:MappedRange{<:Any, <:Any, TX}}) where {TX} = TX
Base.step(A::MappedRange) =
    islinear(_f(A)) ?
        _f(A)(step(parent(A))) :  # linear
        _f(A)(first(parent(A)) + step(parent(A))) - _f(A)(first(parent(A)))  # affine
Base.first(A::MappedRange) = _f(A)(first(parent(A)))
Base.last(A::MappedRange) = _f(A)(last(parent(A)))


struct MappedAny{F, TX}
    f::F
    parent::TX
end
parent_type(::Type{MappedAny{F, TX}}) where {F, TX} = TX

Base.@propagate_inbounds Base.getindex(A::MappedAny, I...) = _f(A)(parent(A)[I...])
Base.@propagate_inbounds Base.setindex!(A::MappedAny, v, I...) = (parent(A)[I...] = set(parent(A)[I...], _f(A), v); A)

Base.eltype(A::MappedAny) = Core.Compiler.return_type(_f(A), Tuple{_eltype(parent(A))})

@inline function Base.iterate(A::MappedAny, state...)
	it = iterate(parent(A), state...)
	isnothing(it) ?
        nothing :
        (_f(A)(first(it)), last(it))
end


const _MTT = Union{MappedArray, MappedRange, MappedAny}
Base.parent(A::_MTT) = getfield(A, :parent)
_f(A::_MTT) = getfield(A, :f)
Base.size(A::_MTT) = size(parent(A))
Base.length(A::_MTT) = length(parent(A))
Base.IndexStyle(::Type{MT}) where {MT <: _MTT} = IndexStyle(parent_type(MT))
Base.IteratorSize(::Type{MT}) where {MT <: _MTT} = Base.IteratorSize(parent_type(MT))
Base.IteratorEltype(::Type{MT}) where {MT <: _MTT} = Base.IteratorEltype(parent_type(MT))
Base.axes(A::_MTT) = axes(parent(A))
Base.keys(A::_MTT) = keys(parent(A))
Base.values(A::_MTT) = mapview(_f(A), values(parent(A)))
Base.keytype(A::_MTT) = keytype(parent(A))
Base.valtype(A::_MTT) = eltype(A)
Base.reverse(A::_MTT; kwargs...) = mapview(_f(A), reverse(parent(A); kwargs...))

Base.map(f, A::_MTT) = map(f ∘ _f(A), parent(A))
Base.collect(A::_MTT) = map(_f(A), parent(A))
Base.filter(f, A::_MTT) = @modify(parent(A)) do P
    filter(f ∘ _f(A), P)
end

Accessors.set(A::_MTT, ::typeof(parent), val) = constructorof(typeof(A))(_f(A), val)

for type in (
        :Dims,
        # mimic OffsetArrays signature
        :(Tuple{Union{Integer, AbstractUnitRange}, Vararg{Union{Integer, AbstractUnitRange}}}),
        # disambiguation with Base
        :(Tuple{Integer, Vararg{Integer}}),
        :(Tuple{Union{Integer, Base.OneTo}, Vararg{Union{Integer, Base.OneTo}}}),
    )
    @eval Base.similar(::Type{MT}, dims::$(type)) where {MT <: _MTT} = similar(parent_type(MT), dims)
    @eval Base.similar(A::_MTT, T::Type, dims::$(type)) = similar(parent(A), T, dims)
end

Base.getproperty(A::_MTT, p::Symbol) = mapview(Accessors.PropertyLens(p), A)
Base.getproperty(A::_MTT, p) = mapview(Accessors.PropertyLens(p), A)


function Base.:(==)(A::Union{AbstractArray, MappedAny}, B::Union{AbstractArray, MappedAny})
    if axes(A) != axes(B)
        return false
    end
    anymissing = false
    for (a, b) in zip(A, B)
        eq = (a == b)
        if ismissing(eq)
            anymissing = true
        elseif !eq
            return false
        end
    end
    return anymissing ? missing : true
end

Base.findfirst(pred::Function, A::MappedArray) = _findfirst(pred, A, inverse(_f(A)))
_findfirst(pred, A, ::NoInverse) = Base.@invoke findfirst(pred::typeof(pred), A::AbstractArray)
_findfirst(pred::Union{Base.Fix2{typeof(isequal)}, Base.Fix2{typeof(==)}}, A, invf::Function) = findfirst(pred.f(invf(pred.x)), parent(A))

Base.searchsortedfirst(A::MappedArray{<:Any, 1}, v; kwargs...) = _searchsortedfirst(A, v, inverse(_f(A)); kwargs...)
_searchsortedfirst(A, v, ::NoInverse; kwargs...) = Base.@invoke searchsortedfirst(A::AbstractVector, v::typeof(v); kwargs...)
_searchsortedfirst(A, v, invf::Function; rev=false) = searchsortedfirst(parent(A), invf(v); rev=_is_increasing(_f(A)) ? rev : !rev)
Base.searchsortedlast(A::MappedArray{<:Any, 1}, v; kwargs...) = _searchsortedlast(A, v, inverse(_f(A)); kwargs...)
_searchsortedlast(A, v, ::NoInverse; kwargs...) = Base.@invoke searchsortedlast(A::AbstractVector, v::typeof(v); kwargs...)
_searchsortedlast(A, v, invf::Function; rev=false) = searchsortedlast(parent(A), invf(v); rev=_is_increasing(_f(A)) ? rev : !rev)

# Base.findall(interval_d::Base.Fix2{typeof(in), <:Interval}, x::AbstractRange) =
#     searchsorted_interval(x, interval_d.x; rev=step(x) < zero(step(x)))

# only called for invertible functions: they are either increasing or decreasing
_is_increasing(f) = f(2) < f(3)

"""    mapview(f, X)

Like `map(f, X)` but doesn't materialize the result and returns a view.

Works on arrays, dicts, and arbitrary iterables. Passes `length`, `keys` and others directly to the parent. Does its best to determine the resulting `eltype` without evaluating `f`. Supports both getting and setting values (through `Accessors.jl`).
"""
mapview(f, X::AbstractArray{T, N}) where {T, N} = MappedArray{Core.Compiler.return_type(f, Tuple{T}), N}(f, X)
mapview(f, X::AbstractRange{T}) where {T} = isaffine(f) ? MappedRange{Core.Compiler.return_type(f, Tuple{T})}(f, X) : @invoke mapview(f, X::AbstractVector{T})
mapview(f, X) = MappedAny(f, X)
mapview(f, X::_MTT) = mapview(f ∘ _f(X), parent(X))

mapview(p::Union{Symbol,Int,String}, A) = mapview(PropertyLens(p), A)
# disambiguate:
mapview(p::Union{Symbol,Int,String}, A::AbstractArray) = mapview(PropertyLens(p), A)
mapview(p::Union{Symbol,Int,String}, A::AbstractRange) = mapview(PropertyLens(p), A)
mapview(p::Union{Symbol,Int,String}, A::_MTT) = mapview(PropertyLens(p), A)

islinear(f) = false
islinear(f::Union{typeof.((deg2rad, rad2deg, -, +))...}) = true
islinear(f::Base.Fix1{<:Union{typeof.((*,))...}}) = true
islinear(f::Base.Fix2{<:Union{typeof.((*, /))...}}) = true
islinear(f::ComposedFunction) = islinear(f.inner) && islinear(f.outer)

isaffine(f) = false
isaffine(f::Union{typeof.((deg2rad, rad2deg, -, +))...}) = true
isaffine(f::Base.Fix1{<:Union{typeof.((-, +, *))...}}) = true
isaffine(f::Base.Fix2{<:Union{typeof.((-, +, *, /))...}}) = true
isaffine(f::ComposedFunction) = isaffine(f.inner) && isaffine(f.outer)


"""
    maprange(f, start; stop, length)
    maprange(f; start, stop, length)
    maprange(f, start, stop; length)

`length` values between `start` and `stop`, so that `f(x)` is incremented in uniform steps. Uses `mapview` in order not to materialize the array.

`maprange(identity, ...)` is equivalent to `range(...)`. Most common application - log-spaced ranges:

`maprange(log, 10, 1000, length=5) ≈ [10, 31.6227766, 100, 316.227766, 1000]`

Other transformations can also be useful:

`maprange(sqrt, 16, 1024, length=5) == [16, 121, 324, 625, 1024]`
"""
function maprange end

maprange(f, start; stop, length) = maprange(f, start, stop; length)
maprange(f; start, stop, length) = maprange(f, start, stop; length)
maprange(f, start, stop; length) = maprange(f, promote(start, stop)...; length)
function maprange(f, start::T, stop::T; length) where {T}
    if inverse(f) isa NoInverse
        @assert set(start, f, f(start)) == set(stop, f, f(start))
        @assert set(start, f, f(stop)) == set(stop, f, f(stop))
    end
    lo, hi = minmax(start, stop)
    rng = range(f(start), f(stop); length)
    mapview(rng) do x
        # if f is always invertible:
        # fx = inverse(f)(x)
        fx = set(lo, f, x)
        x === first(rng) && return oftype(fx, start)
        x === last(rng) && return oftype(fx, stop)
        clamp(fx, lo, hi)
    end
end
