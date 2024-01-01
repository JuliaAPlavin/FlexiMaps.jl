module StructArraysExt
using StructArrays
import FlexiMaps: mapview
using FlexiMaps.Accessors

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

end
