module StructArraysExt
using StructArrays
import FlexiMaps: mapview, _mapmerge, _merge_insert, mapinsert⁻
using FlexiMaps.Accessors, FlexiMaps.DataPipes

mapview(
    o::Union{
        PropertyLens,
        IndexLens{<:Tuple{Integer}},
        typeof(first),typeof(last)
    },
    A::StructArray
) = o(StructArrays.components(A))

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
