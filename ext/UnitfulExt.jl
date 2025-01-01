module UnitfulExt

using Unitful
import FlexiMaps

FlexiMaps.isaffine(::typeof(ustrip)) = true
FlexiMaps.isaffine(::Base.Fix1{typeof(ustrip)}) = true

end
