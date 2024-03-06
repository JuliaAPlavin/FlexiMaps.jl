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
    @test filtermap(((i, x),) -> i == 2 || x == 3 ? x^2 : nothing, enumerate(X)) == [4, 9]

    @test_broken filtermap(x -> isodd(x) ? Some(x^2) : nothing, OffsetArray([1, 2, 3], 5))::Vector{Int} == [1, 9]
    @test filtermap(x -> isodd(x) ? Some(x^2) : nothing, KeyedArray([1, 2, 3], x=[10, 20, 30]))::KeyedArray == KeyedArray([1, 9], x=[10, 30])

    @test filtermap(x -> x % 3 == 0 ? Some(x^2) : nothing, [1 2 3; 4 5 6]) == [9, 36]

    @test filtermap(x -> x[1] == x[2] ? x[1] : nothing, Iterators.product(1:3, 1.:3.)) == [1, 2, 3]
end

@testitem "flatmap only outer func" begin
    using StructArrays

    @test @inferred(flatmap(i->1:i, 1:3))::Vector{Int} == [1, 1,2, 1,2,3]
    @test @inferred(flatmap(i->1:i, 0:3))::Vector{Int} == [1, 1,2, 1,2,3]
    @test @inferred(flatmap(i -> i == 0 ? [nothing] : 1:i, 0:3))::Vector{Union{Int,Nothing}} == [nothing, 1, 1,2, 1,2,3]

    @test @inferred(flatmap(i -> StructVector(a=1:i), [2, 3])).a::Vector{Int} == [1, 2, 1, 2, 3]
    @test (flatmap(i -> StructVector(a=1:i), Any[2, 3])).a::Vector{Int} == [1, 2, 1, 2, 3]
    @test (flatmap(i -> i > 10 ? 123 : StructVector(a=1:i), Any[2, 3])).a::Vector{Int} == [1, 2, 1, 2, 3]

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

    en = enumerate([3, 4, 5])
    @test flatmap(((i, x),) -> 1:x, en) == [1,2,3, 1,2,3,4, 1,2,3,4,5]
    @test flatmap(((i, x),) -> i < 2 ? Vector{Int}(1:x) : Vector{Any}(1:x), en) == [1,2,3, 1,2,3,4, 1,2,3,4,5]
    en = enumerate(Any[3, 4, 5])
    @test flatmap(((i, x),) -> 1:x, en) == [1,2,3, 1,2,3,4, 1,2,3,4,5]
    @test flatmap(((i, x),) -> i < 2 ? Vector{Int}(1:x) : Vector{Any}(1:x), en) == [1,2,3, 1,2,3,4, 1,2,3,4,5]
    en = enumerate(Int[])
    @test flatmap(((i, x),) -> 1:x, en) == []
    @test flatmap(((i, x),) -> i < 2 ? Vector{Int}(1:x) : Vector{Any}(1:x), en) == []
    en = enumerate([])
    @test flatmap(((i, x),) -> 1:x, en) == []
    @test flatmap(((i, x),) -> i < 2 ? Vector{Int}(1:x) : Vector{Any}(1:x), en) == []
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
    using StaticArrays
    using JLArrays: jl

    @test @inferred(flatten([1:1, 1:2, 1:3]))::Vector{Int} == [1, 1,2, 1,2,3]
    @test flatten(Any[1:1, 1:2, 1:3])::Vector{Int} == [1, 1,2, 1,2,3]
    out = Int[]
    @test flatten!(out, [1:1, 1:2, 1:3]) === out == [1, 1,2, 1,2,3]

    @test @inferred(flatten((v for v in [1:1, 1:2, 1:3])))::Vector{Int} == [1, 1,2, 1,2,3]
    @test @inferred(flatten((v for v in [1:1, 1:2, 1:3] if length(v) > 100)))::Vector{Int} == []
    @test @inferred(flatten((v for v in [1:1, 1:2, 1:3] if false)))::Vector{Int} == []
    @test @inferred(flatten([(1, 2), (3, 4)]))::Vector{Int} == [1, 2, 3, 4]
    @test @inferred(flatten([(1, 2), (3,)]))::Vector{Int} == [1, 2, 3]
    @test @inferred(flatten(((1, 2), (3, 4))))::Vector{Int} == [1, 2, 3, 4]
    @test @inferred(flatten(((1, 2), (3,))))::Vector{Int} == [1, 2, 3]
    @test @inferred(flatten(([1, 2], [3, 4])))::Vector{Int} == [1, 2, 3, 4]
    @test @inferred(flatten([(1, :a), (2, :b)]))::Vector{Union{Int64, Symbol}} == [1, :a, 2, :b]
    @test @inferred(flatten(((1, :a), (:b, 2))))::Vector{Union{Int64, Symbol}} == [1, :a, :b, 2]
    @test @inferred(flatten(([1], 2)))::Vector{Int} == [1, 2]

    # should the eltype be promoted at all?
    @test flatten(Union{Vector{Int}, Vector{Float64}}[[1], [2.0]])::Vector{Float64} == [1, 2]
    @test flatten([[1], ["2"]])::Vector == [1, "2"]
    @test @inferred(flatten([Union{Int, Float64}[1], Union{Int, Float64}[2.0]]))::Vector{Union{Int, Float64}} == [1, 2]
    @test @inferred(flatten([Union{Int, Float64}[1, 2.0], Union{Int, Float64}[2.0]]))::Vector{Union{Int, Float64}} == [1, 2, 2]
    @test @inferred(flatten(([1 2], [5.5], (x = false,))))::Vector == [1, 2, 5.5, 0]
    
    @test @inferred(flatten([StructVector(a=[1, 2]), StructVector(a=[1, 2, 3])])).a::Vector{Int} == [1, 2, 1, 2, 3]
    @test @inferred(flatten([view(StructVector(a=[1, 2]), 1:1:2), view(StructVector(a=[1, 2, 3]), 1:1:3)])).a::Vector{Int} == [1, 2, 1, 2, 3]
    @test @inferred(flatten([view(StructVector(a=[1, 2]), 1:1:2)])).a::Vector{Int} == [1, 2]
    @test @inferred(flatten((view(StructVector(a=[1, 2]), 1:1:2),))).a::AbstractVector{Int} == [1, 2]
    @test_broken @inferred(flatten((view(StructVector(a=[1, 2]), 1:1:2), view(StructVector(a=[1, 2]), 1:1:2)))).a::Vector{Int} == [1, 2]
    @test flatten((view(StructVector(a=[1, 2]), 1:1:2), view(StructVector(a=[1, 2]), 1:1:2))).a::Vector{Int} == [1, 2, 1, 2]
    @test flatten(Any[StructVector(a=[1, 2]), StructVector(a=[1, 2, 3])]).a::Vector{Int} == [1, 2, 1, 2, 3]
    @test flatten([StructVector(a=1:2), StructVector(a=1:3)]).a::Vector{Int} == [1, 2, 1, 2, 3]

    @test flatten((SVector(1, 2), SVector(3, 4))) == [1, 2, 3, 4]
    @test flatten(SVector(SVector(1, 2), SVector(3, 4))) == [1, 2, 3, 4]
    @test flatten([jl([1, 2]), jl([3, 4])]) == jl([1, 2, 3, 4])
    @test flatten((jl([1, 2]), jl([3, 4]))) == jl([1, 2, 3, 4])

    a = KeyedArray([1, 2], x=[10, 20])
    b = KeyedArray([1, 2, 3], x=[10, 20, 30])
    @test flatten([a, b])::KeyedArray == KeyedArray([1, 2, 1, 2, 3], x=[10, 20, 10, 20, 30])
    @test flatmap(x->x, (a, b))::KeyedArray == KeyedArray([1, 2, 1, 2, 3], x=[10, 20, 10, 20, 30])
    @test a == KeyedArray([1, 2], x=10:10:20)
    @test axiskeys(a) == (10:10:20,)
    @test b == KeyedArray([1, 2, 3], x=10:10:30)

    @test flatten([KeyedArray([1, 2], x=10:10:20), KeyedArray([1, 2, 3], x=10:10:30)])::KeyedArray == KeyedArray([1, 2, 1, 2, 3], x=[10, 20, 10, 20, 30])
    @test_throws "_out === out" flatten((x for x in [KeyedArray([1, 2], x=10:10:20), KeyedArray([1, 2, 3], x=10:10:30)]))
    @test @inferred(flatten([KeyedArray([1, 2], x=[10, 20]), KeyedArray([1, 2, 3], x=[10, 20, 30])]))::KeyedArray == KeyedArray([1, 2, 1, 2, 3], x=[10, 20, 10, 20, 30])
    @test flatten(Any[KeyedArray([1, 2], x=[10, 20]), KeyedArray([1, 2, 3], x=[10, 20, 30])])::KeyedArray == KeyedArray([1, 2, 1, 2, 3], x=[10, 20, 10, 20, 30])
    @test flatten([KeyedArray([1, 2], x=10:10:20), KeyedArray([1.0, 2, 3], x=10:10:30)])::KeyedArray == KeyedArray([1, 2, 1, 2, 3], x=[10, 20, 10, 20, 30])
    @test flatten([KeyedArray([1, 2], x=[10, 20]), KeyedArray([1.0, 2, 3], x=[10, 20, 30])])::KeyedArray == KeyedArray([1, 2, 1, 2, 3], x=[10, 20, 10, 20, 30])

    @test @inferred(flatten([[]]))::Vector{Any} == []
    @test @inferred(flatten(Vector{Int}[]))::Vector{Int} == []
    @test @inferred(flatten(()))::Vector{Union{}} == []
    @test @inferred(flatten([StructVector(a=[1, 2])][1:0])) == []
    @test flatten(Any[[]]) == []
    @test flatten([]) == []
    @test @inferred(flatten(())) == []
end

@testitem "flatten parentindices" begin
    using StructArrays

    a = [10, 20, 30, 40, 50]
    avs = [view(a, [2, 5]), view(a, [3, 1, 4])]
    @test @inferred(flatten_parent(avs))::Vector{Int} == a
    @test @inferred(flatmap_parent(av -> 2 .* av, avs))::Vector{Int} == 2 .* a
    @test @inferred(flatmap_parent(av -> 2 .* av, (av for av in avs)))::Vector{Int} == 2 .* a
    @test @inferred(flatmap_parent(av -> StructArray(x=2 .* av), avs)).x == 2 .* a

    @test_throws "same parent" flatmap_parent(av -> 2 .* av, collect.(avs))
    @test_throws "must be covered" flatmap_parent(av -> 2 .* av, avs[1:1])

    let
        cnt = Ref(0)
        @test flatmap_parent(av -> av .+ (cnt[] += 1), avs)::Vector{Int} == [12, 21, 32, 42, 51]
        @test cnt[] == 2
    end
end

@testitem "mapview - arrays" begin
    using FlexiMaps: MappedArray
    using Accessors

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

    @test size(similar(ma, 3)::Vector{Int}) == (3,)
    @test size(similar(mapview(float, a), 3)::Vector{Float64}) == (3,)
    @test size(similar(typeof(ma), 3)::Vector{Int}) == (3,)
    @test size(similar(typeof(mapview(float, a)), 3)::Vector{Float64}) == (3,)
    
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

    ma = @inferred mapview(-, [1 2 3; 4 5 6])
    @test ma == [-1 -2 -3; -4 -5 -6]
    @test ma[1, 2] == -2
    @test ma[CartesianIndex(1, 2)] == -2
    ma_s = @inferred ma[:, 2:3]
    @test ma_s::MappedArray == [-2 -3; -5 -6]
    @test parent(ma_s)::Matrix == [2 3; 5 6]
    ma_s = @inferred ma[1, :]
    @test ma_s::MappedArray == [-1, -2, -3]
    @test parent(ma_s)::Vector == [1, 2, 3]
    ma_s = @inferred ma[1, 2:3]
    @test ma_s::MappedArray == [-2, -3]
    @test parent(ma_s)::Vector == [2, 3]

    ma = @inferred mapview(x -> x + 1, view([10, 20, 30], 2:3))
    @test ma == [21, 31]
    @test_broken parentindices(ma) == (2:3,)  # should it work? how to reconcile with parent()?

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

@testitem "mapview - KeyedArray" begin
    using FlexiMaps: MappedArray
    using AxisKeys

    a = KeyedArray([1, 2, 3], a=[:a, :b, :c])
    ma = @inferred mapview(x -> x + 1, a)
    @test ma[2] == 3
    @test_broken ma[a=2] == 3
    @test_broken ma[a=Key(:b)] == 3
    mma = @inferred map(x -> x + 1, ma)
    @test mma::KeyedArray == KeyedArray([3, 4, 5], a=[:a, :b, :c])
    fma = @inferred filter(x -> x >= 3, ma)
    @test fma isa MappedArray
    @test collect(fma)::KeyedArray == KeyedArray([3, 4], a=[:b, :c])
end

@testitem "mapview - StructArrays" begin
    using Accessors
    using StructArrays

    sa = StructArray(x=[1, 2, 3], y=[:a, :b, :c])
    msa = @inferred mapview(@optic(_.x), sa)
    @test msa === mapview(:x, sa)
    @test msa === sa.x
    @test mapview(@optic(_[:x]), sa) == sa.x
    @test mapview(@optic(_[2]), sa) === sa.y
    @test mapview(first, sa) === sa.x
    @test mapview(last, sa) === sa.y
    
    msa = mapview(@optic(_[(:y, :x)]), sa)
    @test msa == map(@optic(_[(:y, :x)]), sa)
    @test msa.x === sa.x
    msa[1] = (y=:d, x=10)
    @test sa == StructArray(x=[10, 2, 3], y=[:d, :b, :c])
end

@testitem "mapview - Dictionaries" begin
    using Accessors
    using Dictionaries

    a = dictionary([:a => 1, :b => 2, :c => 3])
    ma = @inferred mapview(@optic(_ + 1), a)
    @test ma == dictionary([:a => 2, :b => 3, :c => 4])
    @test ma isa AbstractDictionary{Symbol, Int}
    @test @inferred(ma[:c]) == 4
    # ensure we get a view
    a[:b] = 20
    @test ma == dictionary([:a => 2, :b => 21, :c => 4])

    ma[:c] = 11
    @test a == dictionary([:a => 1, :b => 20, :c => 10])
    @test ma == dictionary([:a => 2, :b => 21, :c => 11])
end

@testitem "mapview - iterators" begin
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

@testitem "mapview - ranges" begin
    using FlexiMaps: MappedArray
    using Accessors

    rng = mapview(deg2rad, 0:90:360)::AbstractRange
    @test rng ≈ [0, π/2, π, 3π/2, 2π]
    @test collect(rng) ≈ [0, π/2, π, 3π/2, 2π]
    @test first(rng) ≈ 0
    @test last(rng) ≈ 2π
    @test step(rng) ≈ π/2
    @test !isempty(rng)

    rng = mapview(@optic(_ + 1), 0:10)::AbstractRange
    @test rng == 1:11
    @test step(rng) == 1

    rng = mapview(@optic((_ + 1) / 2), 0:10)::AbstractRange
    @test rng == 0.5:0.5:5.5
    @test step(rng) == 0.5

    rng = mapview(x -> x + 1, 0:10)::MappedArray
    @test rng == map(x->x+1, 0:10)

    rng = mapview(@optic(_ ^ 2), 0:10)::MappedArray
    @test rng == map(x->x^2, 0:10)
end

@testitem "maprange" begin
    using Unitful
    using Accessors

    let
        r = maprange(identity, 1, 10, length=5)
        @test r ≈ range(1, 10, length=5)
        @test_broken step(r) ≈ 2.25

        lr = @inferred maprange(log10, 0.1, 10, length=5)
        @test lr ≈ [0.1, √0.1, 1, √10, 10]
        @test maprange(log10, 0.1, 10, step=0.5) ≈ [0.1, √0.1, 1, √10, 10]

        for f in [log, log2, log10, @optic(log(0.1, _))]
            lr = @inferred maprange(f, 0.1, 10, length=5)
            @test lr ≈ [0.1, √0.1, 1, √10, 10]
            lr = @inferred maprange(f, 10, 0.1, length=5)
            @test lr ≈ [0.1, √0.1, 1, √10, 10] |> reverse
        end

        lr = @inferred maprange(@optic(log(ustrip(u"m", _))), 0.1u"m", 10u"m", length=5)
        @test lr ≈ [0.1, √0.1, 1, √10, 10]u"m"
        lr = @inferred maprange(@optic(log(ustrip(u"m", _))), 10u"cm", 10u"m", length=5)
        @test lr ≈ [0.1, √0.1, 1, √10, 10]u"m"
        lr = @inferred maprange(@optic(log(_.a)), (a=0.1, b=5), (a=100., b=5), length=4)
        @test map(r->r.a, lr) ≈ [0.1, 1, 10, 100]
        @test map(r->r.b, lr) ≈ [5, 5, 5, 5]

        # @testset for a in [10], b in [100], len in [2:10; 12345]
        @testset for a in [1, 10, 100, 1000, 1e-10, 1e10], b in [1, 10, 100, 1000, 1e-10, 1e10], len in [2:10; 12345]
            rng = maprange(log, a, b, length=len)
            @test length(rng) == len
            a != b && @test allunique(rng)
            @test issorted(rng, rev=a > b)
            @test minimum(rng) == min(a, b)
            @test maximum(rng) == max(a, b)
            @test map(log, rng) ≈ range(log(a), log(b), length=len)

            rng = maprange(log, a, b, step=0.5)
            a != b && @test allunique(rng)
            @test issorted(rng, rev=a > b)
            @test map(log, rng) ≈ range(log(a), log(b), step=0.5)
        end
    end
end


@testitem "LogRange" begin
    # test from https://github.com/JuliaLang/julia/pull/39071
    const LogRange = (a, b, l) -> maprange(log, a, b, length=l)

    # basic idea
    @test LogRange(2, 16, 4) ≈ [2, 4, 8, 16]
    @test LogRange(1/8, 8.0, 7) ≈ [0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0]
    @test LogRange(1000, 1, 4) ≈ [1000, 100, 10, 1]
    @test LogRange(1, 10^9, 19)[1:2:end] ≈ 10 .^ (0:9)

    # negative & complex
    # @test LogRange(-1, -4, 3) == [-1, -2, -4]
    # @test LogRange(1, -1+0.0im, 3) == [1, im, -1]
    # @test LogRange(1, -1-0.0im, 3) == [1, -im, -1]

    # endpoints
    @test LogRange(0.1f0, 100, 33)[1] === 0.1f0
    @test LogRange(0.789, 123_456, 135_790)[[begin, end]] == [0.789, 123_456]
    @test LogRange(nextfloat(0f0), floatmax(Float32), typemax(Int))[end] === floatmax(Float32)
    @test LogRange(nextfloat(Float16(0)), floatmax(Float16), 66_000)[end] === floatmax(Float16)
    @test first(LogRange(pi, 2pi, 3000)) === LogRange(pi, 2pi, 3000)[1] === Float64(pi)
    @test last(LogRange(0.01, 0.1, 3000)) === 0.1
    # @test last(LogRange(-0.01, -0.1, 3000)) === last(LogRange(-0.01, -0.1, 3000))[end] === -0.1
    if Int == Int64
        @test LogRange(0.1, 1000, 2^54)[end] === 1000.0
        # @test LogRange(-0.1, -1000, 2^55)[end] === -1000.0
    end

    # empty, only, NaN, Inf
    # @test first(LogRange(1, 2, 0)) === 1.0
    # @test last(LogRange(1, 2, 0)) === 2.0
    # @test isnan(first(LogRange(0, 2, 0)))
    @test only(LogRange(2pi, 2pi, 1)) === LogRange(2pi, 2pi, 1)[1] === 2pi
    # @test isnan(LogRange(1, NaN, 3)[2])
    # @test isinf(LogRange(1, Inf, 3)[2])
    # @test isnan(LogRange(0, 2, 3)[1])

    # types
    @test eltype(LogRange(1, 10, 3)) == Float64
    @test eltype(LogRange(1, 10, Int32(3))) == Float64
    @test eltype(LogRange(1, 10f0, 3)) == Float32
    @test eltype(LogRange(1f0, 10, 3)) == Float32
    # @test eltype(LogRange(1f0, 10+im, 3)) == ComplexF32
    # @test eltype(LogRange(1f0, 10.0+im, 3)) == ComplexF64
    @test eltype(LogRange(1, big(10), 3)) == BigFloat
    @test LogRange(big"0.3", big(pi), 50)[1] == big"0.3"
    @test LogRange(big"0.3", big(pi), 50)[end] == big(pi)

    # errors
    @test_throws ArgumentError LogRange(1, 10, -1)
    @test_throws ArgumentError LogRange(1, 10, 1) # endpoints must differ
    @test_throws DomainError LogRange(1, -1, 3)   # needs complex numbers
    @test_throws ArgumentError LogRange(1, 10, 2)[true]
    @test_throws BoundsError LogRange(1, 10, 2)[3]

    # # printing
    # @test repr(LogRange(1,2,3)) == "LogRange(1.0, 2.0, 3)"
    # @test repr("text/plain", LogRange(1,2,3)) == "3-element LogRange{Float64}:\n 1.0, 1.41421, 2.0"
end

@testitem "map-accessors" begin
    using StructArrays
    using Accessors

    xs = [(a=1, b=2), (a=3, b=4)]
    @test @inferred(mapset(a=x -> x.b^2, xs)) == [(a=4, b=2), (a=16, b=4)]
    @test @inferred(mapset(a=x -> x.b^2, b=x -> x.a, xs)) == [(a=4, b=1), (a=16, b=3)]
    @test @inferred(mapinsert(c=x -> x.b^2, xs)) == [(a=1, b=2, c=4), (a=3, b=4, c=16)]
    @test @inferred(mapinsert(c=x -> x.b^2, d=x -> x.a + x.b, xs)) == [(a=1, b=2, c=4, d=3), (a=3, b=4, c=16, d=7)]

    @test mapinsert⁻(c=@optic(_.b^2), xs) == [(a=1, c=4), (a=3, c=16)]
    @test mapinsert⁻(c=@optic(_.b^2), d=@optic(_.b), xs) == [(a=1, c=4, d=2), (a=3, c=16, d=4)]

    @test @inferred(mapsetview(a=x -> x.b^2, xs)) == [(a=4, b=2), (a=16, b=4)]
    @test @inferred(mapsetview(a=x -> x.b^2, b=x -> x.a, xs)) == [(a=4, b=1), (a=16, b=3)]
    @test @inferred(mapinsertview(c=x -> x.b^2, xs)) == [(a=1, b=2, c=4), (a=3, b=4, c=16)]
    @test @inferred(mapinsertview(c=x -> x.b^2, d=x -> x.a + x.b, xs)) == [(a=1, b=2, c=4, d=3), (a=3, b=4, c=16, d=7)]

    sa = StructArray(xs)
    sm = @inferred(mapset(a=x -> x.b^2, sa))
    @test sm.a == [4, 16]
    @test sm.b === sa.b
    sm = @inferred(mapinsert(c=x -> x.b^2, sa))
    @test sm.b === sa.b
    @test sm.c == [4, 16]
    sm = @inferred mapinsert⁻(c=@optic(_.b^2), sa)
    @test sm.a === sa.a
    @test sm.c == [4, 16]
    @test sm[1] == (a=1, c=4)
end

@testitem "_" begin
    import Aqua
    Aqua.test_all(FlexiMaps; ambiguities=false)
    Aqua.test_ambiguities(FlexiMaps)

    import CompatHelperLocal as CHL
    CHL.@check()
end
