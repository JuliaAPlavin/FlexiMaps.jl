module UnitfulExt

using Unitful
import FlexiMaps

FlexiMaps.isaffine(::typeof(ustrip)) = true
FlexiMaps.isaffine(::Base.Fix1{typeof(ustrip)}) = true
FlexiMaps.isaffine(::Unitful.Units) = true
FlexiMaps.islinear(::Base.Fix1{typeof(*), <:Unitful.Units}) = true
FlexiMaps.islinear(::Base.Fix2{<:Union{typeof(*), typeof(/)}, <:Unitful.Units}) = true

end
