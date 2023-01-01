using TestItems
using TestItemRunner
@run_package_tests


@testitem "_" begin
    import Aqua
    Aqua.test_all(FilterMaps; ambiguities=false)
    Aqua.test_ambiguities(FilterMaps)

    import CompatHelperLocal as CHL
    CHL.@check()
end
