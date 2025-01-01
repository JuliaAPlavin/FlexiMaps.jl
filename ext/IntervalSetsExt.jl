module IntervalSetsExt

using IntervalSets
import FlexiMaps: maprange

maprange(f, int::ClosedInterval; length) = maprange(f, endpoints(int)..., length)
maprange(f, int::ClosedInterval, length) = maprange(f, endpoints(int)..., length)

end
