module StructArraysExt
using StructArrays
import FlexiMaps: mapview, _mapmerge, _merge_insert, mapinsert⁻
using FlexiMaps.Accessors, FlexiMaps.DataPipes

const _FUNCS = Union{
    PropertyLens,
    IndexLens{<:Tuple{Integer}},
    typeof(first),typeof(last)
}
# properties without a column, eg computed in getproperty, go through the generic method
_hascolumn(o, A) = true
_hascolumn(::PropertyLens{P}, A) where {P} =
    P isa Symbol ?
        hasfield(typeof(StructArrays.components(A)), P) :
        1 <= P <= fieldcount(typeof(StructArrays.components(A)))

mapview(o::_FUNCS, A::StructArray) =
    _hascolumn(o, A) ?
        o(StructArrays.components(A)) :
        @invoke mapview(o::Any, A::AbstractArray)

mapview(f::ComposedFunction{<:Any, <:_FUNCS}, A::StructArray) =
    _hascolumn(f.inner, A) ?
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
