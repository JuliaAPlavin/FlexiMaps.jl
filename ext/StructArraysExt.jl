module StructArraysExt
using StructArrays
import FlexiMaps: mapview, _mapmerge, _merge_insert, mapinsert⁻
using FlexiMaps.Accessors, FlexiMaps.DataPipes

const _FUNCS = Union{
    PropertyLens,
    IndexLens{<:Tuple{Integer}},
    typeof(first),typeof(last)
}
mapview(
    o::_FUNCS,
    A::StructArray
) = o(StructArrays.components(A))

mapview(f::ComposedFunction{<:Any, <:_FUNCS}, x::StructArray) = mapview(f.outer, mapview(f.inner, x))

# properties without a column, eg computed in getproperty, go through the generic method
_hascolumn(A::StructArray, ::PropertyLens{P}) where {P} =
    P isa Symbol ?
        hasfield(typeof(StructArrays.components(A)), P) :
        1 <= P <= length(StructArrays.components(A))
mapview(o::PropertyLens, A::StructArray) =
    _hascolumn(A, o) ?
        o(StructArrays.components(A)) :
        @invoke mapview(o::Any, A::AbstractArray)
mapview(f::ComposedFunction{<:Any, <:PropertyLens}, A::StructArray) =
    _hascolumn(A, f.inner) ?
        mapview(f.outer, mapview(f.inner, A)) :
        @invoke mapview(f::Any, A::AbstractArray)

mapview(
    o::IndexLens{<:Tuple{Tuple{Vararg{Union{Integer,Symbol}}}}},
    A::StructArray
) = @modify(o, StructArrays.components(A))


function _mapmerge(A::StructArray{<:NamedTuple}, mapf, mergef; kwargs...)
    new_comps = map(values(kwargs)) do fx
        mapf(fx, A)
    end
    return StructArray(mergef(StructArrays.components(A), new_comps))
end


function mapinsert⁻(A::StructArray; kwargs...)
    deloptics = map(values(kwargs)) do o
        Accessors.deopcompose(o) |> first
    end
    @p let
        StructArrays.components(A)
        _merge_insert(__, map(fx -> map(fx, A), values(kwargs)))
        reduce((acc, o) -> delete(acc, o), deloptics; init=__)
        StructArray()
    end
end

end
