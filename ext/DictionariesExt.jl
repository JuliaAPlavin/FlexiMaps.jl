module DictionariesExt
import Dictionaries: AbstractDictionary, MappedDictionary, issettable, gettokenvalue, settokenvalue!, _dicts, _f
import FlexiMaps: mapview, set

mapview(f, d::AbstractDictionary) = Iterators.map(f, d)  # Iterators.map defined in Dictionaries to return a MappedDictionary
mapview(::typeof(identity), d::AbstractDictionary) = d  # disambiguation

issettable(::MappedDictionary) = true

function settokenvalue!(d::MappedDictionary{I, T, <:Any, <:Tuple{AbstractDictionary{<:I}}}, t, v::T) where {I, T}
    pd = _dicts(d)[1]
    pv = set(gettokenvalue(pd, t), _f(d), v)
    settokenvalue!(pd, t, pv)
    return d
end

end
