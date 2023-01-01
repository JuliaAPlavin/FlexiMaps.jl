function flatmap!(f::Function, out, A)
    empty!(out)
    for a in A
        append!(out, f(a))
    end
    out
end

function flatmap!(f_out::Function, f_in::Function, out, A)
    empty!(out)
    for a in A
        for b in f_out(a)
            push!(out, f_in(a, b))
        end
    end
    out
end


function flatmap(f::Function, A)
    T = _eltype(Base.promote_op(f, _eltype(A)))
    it = iterate(A)
    if isnothing(it)
        return _empty_from_type(Base.promote_op(f, _eltype(A)), T)
    end
    afirst, state = it
    arest = Iterators.rest(A, state)
    out = _similar_with_content(f(afirst), T)
    for x in arest
        _out = append!(out, f(x))
        @assert _out === out  # e.g. AxisKeys may return something else from append!
    end
    return out
end

# rougly reduce(vcat, map(a -> map(b -> f_in(a, b), f_out(a)), A))
function flatmap(f_out::Function, f_in::Function, A)
    TO = _eltype(Base.promote_op(f_out, _eltype(A)))
    T = Base.promote_op(f_in, _eltype(A), TO)
    it = iterate(A)
    if isnothing(it)
        return _empty_from_type(Base.promote_op(f_out, _eltype(A)), T)
    end
    afirst, state = it
    arest = Iterators.rest(A, state)
    out = _similar_with_content(map(y -> f_in(afirst, y), f_out(afirst)), T)
    for x in arest
        for y in f_out(x)
            push!(out, f_in(x, y))
        end
    end
    return out
end

function flatmap⁻(f_out, f_in::Function, A)
    TO = _eltype(Base.promote_op(f_out, _eltype(A)))
    T = Base.promote_op(f_in, Base.promote_op(delete, _eltype(A), typeof(f_out)), TO)
    it = iterate(A)
    if isnothing(it)
        return _empty_from_type(Base.promote_op(f_out, _eltype(A)), T)
    end
    afirst, state = it
    afirst⁻ = delete(afirst, f_out)
    arest = Iterators.rest(A, state)
    out = _similar_with_content(map(y -> f_in(afirst⁻, y), f_out(afirst)), T)
    for x in arest
        x⁻ = delete(x, f_out)
        for y in f_out(x)
            push!(out, f_in(x⁻, y))
        end
    end
    return out
end


_similar_with_content(A::AbstractVector, ::Type{T}) where {T} = similar(A, T) .= A
_similar_with_content(A::AbstractArray, ::Type{T}) where {T} = _similar_with_content(vec(A), T)
_similar_with_content(A, ::Type{T}) where {T} = append!(T[], A)

_empty_from_type(::Type, ::Type{T}) where {T} = T[]
_empty_from_type(::Type{AT}, ::Type{T}) where {AT <: AbstractArray, T} = similar(AT, 0)


flatten(A) = flatmap(identity, A)
flatten!(out, A) = flatmap!(identity, out, A)
