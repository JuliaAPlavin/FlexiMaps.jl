using TestItems
using TestItemRunner
@run_package_tests


@testitem "filtermap" begin
    using AxisKeys
    using OffsetArrays

    X = 1:10
    Y = filtermap(x -> x % 3 == 0 ? Some(x^2) : nothing, X)
    @test Y == [9, 36, 81]
    @test typeof(Y) == Vector{Int}

    @test filtermap(x -> x % 3 == 0 ? x^2 : nothing, X) == [9, 36, 81]
    @test filtermap(x -> x % 3 == 0 ? Some(nothing) : nothing, X) == [nothing, nothing, nothing]

    @test filtermap(x -> x % 3 == 0 ? Some(x^2) : nothing, (1, 2, 3, 4, 5, 6)) === (9, 36)

    @test_broken filtermap(x -> isodd(x) ? Some(x^2) : nothing, OffsetArray([1, 2, 3], 5))::Vector{Int} == [1, 9]
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

    @test @inferred(flatmap(i -> 1:i, [1][1:0]))::Vector{Int} == []
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
    using FlexiMaps: flatmap⁻
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

    @test @inferred(flatten((v for v in [1:1, 1:2, 1:3])))::Vector{Int} == [1, 1,2, 1,2,3]
    @test @inferred(flatten((v for v in [1:1, 1:2, 1:3] if length(v) > 100)))::Vector{Int} == []
    @test_broken @inferred(flatten((v for v in [1:1, 1:2, 1:3] if false)))::Vector{Int} == []
    @test @inferred(flatten([(1, 2), (3, 4)]))::Vector{Int} == [1, 2, 3, 4]
    @test @inferred(flatten([(1, 2), (3,)]))::Vector{Int} == [1, 2, 3]
    @test @inferred(flatten(((1, 2), (3, 4))))::Vector{Int} == [1, 2, 3, 4]
    @test @inferred(flatten(((1, 2), (3,))))::Vector{Int} == [1, 2, 3]
    @test @inferred(flatten(([1, 2], [3, 4])))::Vector{Int} == [1, 2, 3, 4]
    @test @inferred(flatten([(1, :a), (2, :b)]))::Vector{Union{Int64, Symbol}} == [1, :a, 2, :b]
    @test @inferred(flatten(((1, :a), (:b, 2))))::Vector{Any} == [1, :a, :b, 2]
    @test @inferred(flatten(([1], 2)))::Vector{Int} == [1, 2]

    @test @inferred(flatten(([1 2], [5.5], (x = false,)))) == [1, 2, 5.5, 0]  # should the eltype be promoted at all?
    @test_broken @inferred(flatten(([1 2], [5.5], (x = false,))))::Vector{Float64} == [1, 2, 5.5, 0]  # should the eltype be promoted at all?
    
    a = @inferred(flatten([StructVector(a=[1, 2]), StructVector(a=[1, 2, 3])]))::StructArray
    @test a == [(a=1,), (a=2,), (a=1,), (a=2,), (a=3,)]
    @test a.a::Vector{Int} == [1, 2, 1, 2, 3]
    a = @inferred(flatten([view(StructVector(a=[1, 2]), 1:1:2), view(StructVector(a=[1, 2, 3]), 1:1:3)]))::StructArray
    @test a.a::Vector{Int} == [1, 2, 1, 2, 3]
    a = @inferred(flatten([view(StructVector(a=[1, 2]), 1:1:2)]))::StructArray
    @test a.a::Vector{Int} == [1, 2]
    a = @inferred(flatten((view(StructVector(a=[1, 2]), 1:1:2),)))::StructArray
    @test a.a::Vector{Int} == [1, 2]

    @test_throws "_out === out" flatten([KeyedArray([1, 2], x=10:10:20), KeyedArray([1, 2, 3], x=10:10:30)])
    a = @inferred(flatten([KeyedArray([1, 2], x=[10, 20]), KeyedArray([1, 2, 3], x=[10, 20, 30])]))::KeyedArray
    @test a == KeyedArray([1, 2, 1, 2, 3], x=[10, 20, 10, 20, 30])

    @test @inferred(flatten([[]]))::Vector{Any} == []
    @test @inferred(flatten(Vector{Int}[]))::Vector{Int} == []
    @test @inferred(flatten(()))::Vector{Union{}} == []
    @test @inferred(flatten([StructVector(a=[1, 2])][1:0])) == []
    @test flatten(Any[[]]) == []
    @test flatten([]) == []
end

@testitem "mapview" begin
    using FlexiMaps: MappedArray
    using Accessors

    @testset "array" begin
        a = [1, 2, 3]
        ma = @inferred mapview(@optic(_ + 1), a)
        @test ma == [2, 3, 4]
        @test ma isa AbstractVector{Int}
        @test @inferred(ma[3]) == 4
        @test @inferred(ma[CartesianIndex(3)]) == 4
        @test @inferred(ma[2:3])::MappedArray == [3, 4]
        @test @inferred(map(x -> x * 2, ma))::Vector{Int} == [4, 6, 8]
        @test reverse(ma)::MappedArray == [4, 3, 2]
        @test view(ma, 2:3)::SubArray == [3, 4]
        @test size(similar(typeof(ma), 3)::Vector{Int}) == (3,)
        
        # ensure we get a view
        a[2] = 20
        @test ma == [2, 21, 4]

        ma[3] = 11
        ma[1:2] = [21, 31]
        push!(ma, 101)
        @test a == [20, 30, 10, 100]
        @test ma == [21, 31, 11, 101]

        ma = @inferred mapview(x -> (; x=x + 1), a)
        @test ma.x::MappedArray{Int} == [21, 31, 11, 101]
        @test parent(ma.x) === parent(ma) === a

        # multiple arrays - not implemented
        # ma = @inferred mapview((x, y) -> x + y, 1:3, [10, 20, 30])
        # @test ma == [11, 22, 33]
        # @test @inferred(ma[2]) == 22
        # @test @inferred(ma[CartesianIndex(2)]) == 22

        @testset "find" begin
            ma = mapview(@optic(_ * 10), [1, 2, 2, 2, 3, 4])
            @test findfirst(==(30), ma) == 5
            @test findfirst(==(35), ma) |> isnothing
            @test searchsortedfirst(ma, 20) == 2
            @test searchsortedlast(ma, 20) == 4
            @test searchsortedfirst(reverse(ma), 20; rev=true) == 3
            @test searchsortedlast(reverse(ma), 20; rev=true) == 5

            ma = mapview(x -> x * 10, [1, 2, 2, 2, 3, 4])
            @test findfirst(==(30), ma) == 5
            @test findfirst(==(35), ma) |> isnothing
            @test searchsortedfirst(ma, 20) == 2
            @test searchsortedlast(ma, 20) == 4
            @test searchsortedfirst(reverse(ma), 20; rev=true) == 3
            @test searchsortedlast(reverse(ma), 20; rev=true) == 5

            ma = mapview(@optic(_ * -10), .- [1, 2, 2, 2, 3, 4])
            @test findfirst(==(30), ma) == 5
            @test findfirst(==(35), ma) |> isnothing
            @test searchsortedfirst(ma, 20) == 2
            @test searchsortedlast(ma, 20) == 4
            @test searchsortedfirst(reverse(ma), 20; rev=true) == 3
            @test searchsortedlast(reverse(ma), 20; rev=true) == 5
        end
    end

    @testset "dict" begin
        a = Dict(:a => 1, :b => 2, :c => 3)
        ma = @inferred mapview(@optic(_ + 1), a)
        @test ma == Dict(:a => 2, :b => 3, :c => 4)
        @test ma isa AbstractDict{Symbol, Int}
        @test @inferred(ma[:c]) == 4
        # ensure we get a view
        a[:b] = 20
        @test ma == Dict(:a => 2, :b => 21, :c => 4)

        ma[:c] = 11
        ma[:d] = 31
        @test a == Dict(:a => 1, :b => 20, :c => 10, :d => 30)
        @test ma == Dict(:a => 2, :b => 21, :c => 11, :d => 31)
    end

    @testset "iterator" begin
        a = [1, 2, 3]
        ma = @inferred mapview(x -> x + 1, (x for x in a))
        @test ma == [2, 3, 4]
        @test @inferred(eltype(ma)) == Int
        @test @inferred(first(ma)) == 2
        @test @inferred(collect(ma)) == [2, 3, 4]
        @test @inferred(findmax(ma)) == (4, 3)
        # ensure we get a view
        a[2] = 20
        @test ma == [2, 21, 4]
    end
end

@testitem "maprange" begin
    using Unitful
    using AccessorsExtra

    begin
        @test maprange(identity, 1, 10, length=5) ≈ range(1, 10, length=5)
        lr = @inferred maprange(log10, 0.1, 10, length=5)
        @test lr ≈ [0.1, √0.1, 1, √10, 10]
        for f in [log, log2, log10,] # @optic(log(0.1, _))] XXX - see my fix PR to InverseFunctions
            lr = @inferred maprange(f, 0.1, 10, length=5)
            @test lr ≈ [0.1, √0.1, 1, √10, 10]
            lr = @inferred maprange(f, 10, 0.1, length=5)
            @test lr ≈ [0.1, √0.1, 1, √10, 10] |> reverse
        end

        lr = @inferred maprange(@optic(log(ustrip(u"m", _))), 0.1u"m", 10u"m", length=5)
        @test lr ≈ [0.1, √0.1, 1, √10, 10]u"m"
        lr = @inferred maprange(@optic(log(ustrip(u"m", _))), 10u"cm", 10u"m", length=5)
        @test lr ≈ [0.1, √0.1, 1, √10, 10]u"m"

        @testset for a in [1, 10, 100, 1000, 1e-10, 1e10], b in [1, 10, 100, 1000, 1e-10, 1e10], len in [2:10; 12345]
            rng = maprange(log, a, b, length=len)
            @test length(rng) == len
            a != b && @test allunique(rng)
            @test issorted(rng, rev=a > b)
            @test minimum(rng) == min(a, b)
            @test maximum(rng) == max(a, b)
        end
    end
end


@testitem "_" begin
    import Aqua
    Aqua.test_all(FlexiMaps; ambiguities=false)
    Aqua.test_ambiguities(FlexiMaps)

    import CompatHelperLocal as CHL
    CHL.@check()
end
