using TestItems
using TestItemRunner
@run_package_tests


@testitem "findonly" begin
    @test @inferred(findonly(iseven, [11, 12])) == 2
    @test_throws "more than one" findonly(isodd, [1, 2, 3])
    @test_throws "no element" findonly(isodd, [2, 4])
end

@testitem "filtermap" begin
    using AxisKeys

    X = 1:10
    Y = filtermap(x -> x % 3 == 0 ? Some(x^2) : nothing, X)
    @test Y == [9, 36, 81]
    @test typeof(Y) == Vector{Int}

    @test filtermap(x -> x % 3 == 0 ? x^2 : nothing, X) == [9, 36, 81]
    @test filtermap(x -> x % 3 == 0 ? Some(nothing) : nothing, X) == [nothing, nothing, nothing]

    @test filtermap(x -> x % 3 == 0 ? Some(x^2) : nothing, (1, 2, 3, 4, 5, 6)) === (9, 36)

    @test filtermap(x -> isodd(x) ? Some(x^2) : nothing, KeyedArray([1, 2, 3], x=[10, 20, 30]))::KeyedArray == KeyedArray([1, 9], x=[10, 30])
end

@testitem "flatmap only outer func" begin
    using StructArrays

    @test @inferred(flatmap(i->1:i, 1:3))::Vector{Int} == [1, 1,2, 1,2,3]
    @test @inferred(flatmap(i->1:i, 0:3))::Vector{Int} == [1, 1,2, 1,2,3]
    @test @inferred(flatmap(i -> i == 0 ? [nothing] : 1:i, 0:3))::Vector{Union{Int,Nothing}} == [nothing, 1, 1,2, 1,2,3]

    a = @inferred(flatmap(i -> StructVector(a=1:i), [2, 3]))::StructArray
    @test a == [(a=1,), (a=2,), (a=1,), (a=2,), (a=3,)]
    @test a.a == [1, 2, 1, 2, 3]

    let
        cnt = Ref(0)
        @test flatmap(i -> [cnt[] += 1], 1:3)::Vector{Int} == [1, 2, 3]
        @test cnt[] == 3
    end

    @test @inferred(flatmap(i -> (j for j in 1:i), (i for i in 1:3)))::Vector{Int} == [1, 1,2, 1,2,3]
    @test @inferred(flatmap(i -> 1:i, [1 3; 2 4]))::Vector{Int} == [1, 1,2, 1,2,3, 1,2,3,4]
    @test @inferred(flatmap(i -> reshape(1:i, 2, :), [2, 4]))::Vector{Int} == [1, 2, 1, 2, 3, 4]

    @test_broken flatmap(i -> 1:i, [1][1:0]) == []
    @test @inferred(flatmap(i -> collect(1:i), [1][1:0]))::Vector{Int} == []
    @test @inferred(flatmap(i -> (j for j in 1:i), (i for i in 1:0)))::Vector{Int} == []

    X = [(a=[1, 2],), (a=[3, 4],)]
    out = Int[]
    @test flatmap!(x -> x.a, out, X) === out == [1, 2, 3, 4]
end

@testitem "flatmap outer & inner func" begin
    using StructArrays

    X = [(a=[1, 2],), (a=[3, 4],)]
    @test @inferred(flatmap(x -> x.a, (x, a) -> (a, sum(x.a)), X)) == [(1, 3), (2, 3), (3, 7), (4, 7)]

    @test @inferred(flatmap(x -> x.a, (x, a) -> (a, sum(x.a)), X[1:0])) == []

    out = Tuple{Int, Int}[]
    @test flatmap!(x -> x.a, (x, a) -> (a, sum(x.a)), out, X) === out == [(1, 3), (2, 3), (3, 7), (4, 7)]

    @test @inferred(flatmap(i -> (j for j in 1:i), (i, j) -> i + j, (i for i in 1:3))) == [2, 3,4, 4,5,6]

    let
        cnt_out = Ref(0)
        cnt_in = Ref(0)
        @test @inferred(flatmap(i -> [cnt_out[] += 1], (i, j) -> (cnt_in[] += 1), 1:3))::Vector{Int} == [1, 2, 3]
        @test cnt_out[] == 3
        @test cnt_in[] == 3
    end

    Y = @inferred flatmap(x -> StructArray(;x.a), (x, a) -> (a, sum(x.a)), X)
    @test Y == [((a=1,), 3), ((a=2,), 3), ((a=3,), 7), ((a=4,), 7)]
    @test Y isa StructArray

    Y = @inferred flatmap(x -> StructArray(;x.a), (x, a) -> (a, sum(x.a)), X[1:0])
    @test Y == []
    @test Y isa StructArray
end

@testitem "flatmap⁻" begin
    using FilterMaps: flatmap⁻
    using Accessors

    @test @inferred(flatmap⁻(@optic(_.vals), (x, v) -> (;x..., v), [(a=1, vals=[2, 3]), (a=4, vals=[5])])) == [(a=1, v=2), (a=1, v=3), (a=4, v=5)]
    @test @inferred(flatmap⁻(@optic(_.vals), (x, v) -> (;x..., v), [(a=1, vals=[2, 3]), (a=4, vals=[5])][1:0])) == []
end

@testitem "flatten" begin
    using AxisKeys
    using StructArrays

    @test @inferred(flatten([1:1, 1:2, 1:3])) == [1, 1,2, 1,2,3]
    out = Int[]
    @test flatten!(out, [1:1, 1:2, 1:3]) === out == [1, 1,2, 1,2,3]

    a = @inferred(flatten([StructVector(a=[1, 2]), StructVector(a=[1, 2, 3])]))::StructArray
    @test a == [(a=1,), (a=2,), (a=1,), (a=2,), (a=3,)]
    @test a.a == [1, 2, 1, 2, 3]

    @test_throws "_out === out" flatten([KeyedArray([1, 2], x=10:10:20), KeyedArray([1, 2, 3], x=10:10:30)])
    a = @inferred(flatten([KeyedArray([1, 2], x=[10, 20]), KeyedArray([1, 2, 3], x=[10, 20, 30])]))::KeyedArray
    @test a == KeyedArray([1, 2, 1, 2, 3], x=[10, 20, 10, 20, 30])

    @test @inferred(flatten([[]])) == []
    @test @inferred(flatten(Vector{Int}[])) == []
    @test @inferred(flatten([StructVector(a=[1, 2])][1:0])) == []
    @test flatten(Any[[]]) == []
    @test flatten([]) == []
end


@testitem "_" begin
    import Aqua
    Aqua.test_all(FilterMaps; ambiguities=false)
    Aqua.test_ambiguities(FilterMaps)

    import CompatHelperLocal as CHL
    CHL.@check()
end
