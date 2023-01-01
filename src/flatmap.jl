flatmap!(f::Function, out, A) = flatten!(out, mapview(f, A))
flatmap!(f_out::Function, f_in::Function, out, A) = flatten!(out, mapview(a -> mapview(b -> f_in(a, b), f_out(a)), A))

"""
    flatmap(f, X)

Apply `f` to all elements of `X` and flatten the result by concatenating all `f(x)` collections.
Similar to `mapreduce(f, vcat, X)`, more efficient and generic.

    flatmap(fₒᵤₜ, fᵢₙ, X)

Apply `fₒᵤₜ` to all elements of `X`, and apply `fᵢₙ` to the results. Basically, `[fᵢₙ(x, y) for x in X for y in fₒᵤₜ(x)]`.
"""
function flatmap end

flatmap(f::Function, A) = flatten(mapview(f, A))
flatmap(f_out::Function, f_in::Function, A) = flatten(mapview(a -> mapview(b -> f_in(a, b), f_out(a)), A))
flatmap⁻(f_out, f_in::Function, A) = flatten(mapview(a -> mapview(b -> f_in(delete(a, f_out), b), f_out(a)), A))

"""    flatten(X)

Flatten a collection of collections by concatenating all elements.

Similar to `reduce(vcat, X)`, but more generic and type-stable.
"""
function flatten(A)
    T = _eltype(_eltype(A))
    flatten(T, A)
end

# abstractvectors do reduce(vcat), but MappedArray should use the generic method
flatten(::Type{T}, A::MappedArray) where {T} = Base.@invoke flatten(T::Type{T}, A::Any)

function flatten(::Type{T}, A::Base.AbstractVecOrTuple{<:AbstractVector}) where {T}
    if !(isconcretetype(T) || T isa Union)
        return Base.@invoke flatten(T::Type{T}, A::Any)
    end
    isempty(A) && return _empty_from_type(_eltype(A), T)
    return reduce(vcat, A)
end

function flatten(::Type{T}, A) where {T}
    it = iterate(A)
    if isnothing(it)
        return _empty_from_type(_eltype(A), T)
    end
    afirst, state = it
    arest = Iterators.rest(A, state)
    out = _similar_with_content(afirst, T)
    flatten!!(out, arest)
end

function flatten!(out, A)
    for a in A
        _out = append!(out, a)
        @assert _out === out  # e.g. AxisKeys may return something else from append!
    end
    out
end

function flatten!!(out, A) 
    for a in A
        if _eltype(a) <: _eltype(out)
            _out = append!(out, a)
            @assert _out === out  # e.g. AxisKeys may return something else from append!
        else
            out = vcat(out, a)
        end
    end
    out
end


function flatten_parent(A)
    @assert allequal(parent(a) for a in A)
    out = similar(parent(first(A)))
    for a in A
        out[parentindices(a)...] .= a
    end
    return out
end

"""    flatmap_parent(f, A)

Returns a collection consisting of all elements of each `f(a)`, similar to `flatmap(f, A)`.

Each element of `A` should be a `view` of the same parent array, and these views together should cover all elements of the parent.
Elements of the result are in the same order as the corresponding elements in the parent array of `a`s.

# Examples
```
julia> a = [10, 20, 30, 40, 50]

julia> avs = [view(a, [2, 5]), view(a, [3, 1, 4])]
2-element Vector{SubArray{Int64, 1, Vector{Int64}, Tuple{Vector{Int64}}, false}}:
 [20, 50]
 [30, 10, 40]

# multiply by 2 and reassemble in the original order
julia> flatmap_parent(av -> 2 .* av, avs)
5-element Vector{Int64}:
  20
  40
  60
  80
 100
```
"""
function flatmap_parent(f, A)
    Am = mapview(f, A)
    T = _eltype(_eltype(Am))
    it = iterate(A)
    if isnothing(it)
        return _empty_from_type(_eltype(A), T)
    end
    afirst, state = it
    amfirst, mstate = iterate(Am)
    par = parent(afirst)
    out = similar(amfirst, T, axes(par))
    assigned_indices = fill(false, axes(par))
    out[parentindices(afirst)...] .= amfirst
    assigned_indices[parentindices(afirst)...] .= true
    for (a, am) in zip(Iterators.rest(A, state), Iterators.rest(Am, mstate))
        parent(a) === par || throw(ArgumentError("expected all entries to be `view`s of the same parent array"))
        out[parentindices(a)...] .= am
        assigned_indices[parentindices(a)...] .= true
    end
    all(assigned_indices) || throw(ArgumentError("all indices must be covered"))
    return out
end


@inline function _similar_with_content(A, T)
    out = if isconcretetype(T) || T isa Union
        _similar_with_content_concrete(A, T)
    else
        _similar_with_content_sameeltype(A)
    end
    @assert out !== A
    return out
end

_similar_with_content_concrete(A::AbstractVector, ::Type{T}) where {T} = similar(A, T, length(A)) .= A
_similar_with_content_concrete(A::AbstractArray, ::Type{T}) where {T} = _similar_with_content_concrete(vec(A), T)
_similar_with_content_concrete(A, ::Type{T}) where {T} = append!(T[], A)
_similar_with_content_sameeltype(A::AbstractVector) = similar(A, length(A)) .= A
_similar_with_content_sameeltype(A::AbstractArray) = _similar_with_content_sameeltype(vec(A))
_similar_with_content_sameeltype(A) = append!(_eltype(A)[], A)

_empty_from_type(::Type, ::Type{T}) where {T} = T[]
_empty_from_type(::Type{Union{}}, ::Type{T}) where {T} = T[]
_empty_from_type(::Type{<:AbstractRange}, ::Type{T}) where {T} = T[]
_empty_from_type(::Type{AT}, ::Type{T}) where {AT <: AbstractArray, T} = similar(similar(AT, 0), T)
