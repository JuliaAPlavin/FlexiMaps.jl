module DictionariesExt
import Dictionaries: AbstractDictionary, MappedDictionary, issettable, gettokenvalue, settokenvalue!, _dicts, _f
import FlexiMaps: mapview, set

# code from
# https://github.com/andyferris/Dictionaries.jl/blob/83d41051617e602f616e20c527ad052ffc2e4573/src/map.jl#L147-L151
# or (same)
# https://github.com/JuliaData/SplitApplyCombine.jl/blob/8534d12b7c6f78c85dcad9b22f7c6f619d62a9f4/src/map.jl#L112-L117
function mapview(f, d::AbstractDictionary)
    I = keytype(d)
    T = Core.Compiler.return_type(f, Tuple{eltype(d)}) 
    return MappedDictionary{I, T, typeof(f), Tuple{typeof(d)}}(f, (d,))
end

issettable(::MappedDictionary) = true

function settokenvalue!(d::MappedDictionary{I, T, <:Any, <:Tuple{AbstractDictionary{<:I}}}, t, v::T) where {I, T}
    pd = _dicts(d)[1]
    pv = set(gettokenvalue(pd, t), _f(d), v)
    settokenvalue!(pd, t, pv)
    return d
end

end
