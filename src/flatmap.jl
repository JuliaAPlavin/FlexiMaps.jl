flatmap!(f::Function, out, A) = flatten!(out, mapview(f, A))
flatmap!(f_out::Function, f_in::Function, out, A) = flatten!(out, mapview(a -> mapview(b -> f_in(a, b), f_out(a)), A))

flatmap(f::Function, A) = flatten(mapview(f, A))
flatmap(f_out::Function, f_in::Function, A) = flatten(mapview(a -> mapview(b -> f_in(a, b), f_out(a)), A))
flatmap⁻(f_out, f_in::Function, A) = flatten(mapview(a -> mapview(b -> f_in(delete(a, f_out), b), f_out(a)), A))

function flatten(A)
    T = _eltype(_eltype(A))
    flatten(T, A)
end

function flatten(::Type{T}, A) where {T}
    if isconcretetype(T) || T isa Union
        it = iterate(A)
        if isnothing(it)
            return _empty_from_type(_eltype(A), T)
        end
        afirst, state = it
        arest = Iterators.rest(A, state)
        out = _similar_with_content(afirst, T)
        flatten!(out, arest)
    else
        it = iterate(A)
        if isnothing(it)
            return _empty_from_type(_eltype(A), T)  # T or Union{}?
        end
        afirst, state = it
        arest = Iterators.rest(A, state)
        out = _similar_with_content(afirst)
        flatten!!(out, arest)
    end
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


_similar_with_content(A::AbstractVector, ::Type{T}) where {T} = similar(A, T) .= A
_similar_with_content(A::AbstractArray, ::Type{T}) where {T} = _similar_with_content(vec(A), T)
_similar_with_content(A, ::Type{T}) where {T} = append!(T[], A)
_similar_with_content(A::AbstractVector) = similar(A) .= A
_similar_with_content(A::AbstractArray) = _similar_with_content(vec(A))
_similar_with_content(A) = append!(_eltype(A)[], A)

_empty_from_type(::Type, ::Type{T}) where {T} = T[]
_empty_from_type(::Type{Union{}}, ::Type{T}) where {T} = T[]
_empty_from_type(::Type{<:AbstractRange}, ::Type{T}) where {T} = T[]
_empty_from_type(::Type{AT}, ::Type{T}) where {AT <: AbstractArray, T} = similar(similar(AT, 0), T)
