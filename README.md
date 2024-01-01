# FlexiMaps.jl

All-familiar `map` on steroids: a set of functions that generalize `map`.

## `filtermap`

`filtermap(f, X)`: map and filter a collection in one go.
Most useful when the mapped function shares some computations with the filter predicate.

Returns same as `map(f, X)`, dropping elements where `f(x)` is `nothing`.
Return `Some(nothing)` from `f` to keep `nothing` in the result.

```julia
filtermap(x -> x % 3 == 0 ? x^2 : nothing, 1:10) == [9, 36, 81]
```

_Analogous to `filter_map` in Rust_

## `flatmap`/`flatten`

These functions are similar to `Iterators.flatmap` and `Iterators.flatten`, but operate on arrays in a more performant and generic manner.

`flatmap(f, X)`: apply `f` to all elements of `X` and flatten the result by concatenating all `f(x)` collections.

`flatmap(fₒᵤₜ, fᵢₙ, X)`: apply `fₒᵤₜ` to all elements of `X`, and apply `fᵢₙ` to the results. Basically, `[fᵢₙ(x, y) for x in X for y in fₒᵤₜ(x)]`.

`flatmap(f, X)` is similar to `mapreduce(f, vcat, X)` and `SplitApplyCombine.mapmany(f, A)`, but more efficient and generic.

Defining differences include:
- better result type inference
- keeps array types, eg `StructArray`
- works with empty collections
- supports arbitrary iterators, not only arrays

_Analogous to `flat_map` in Rust, and `SelectMany` in C#_

`flatten(X)`: flatten a collection of collections by concatenating all elements, equivalent to `flatmap(identity, X)`.

## `mapview` (lazy `map`)

`mapview(f, X)`:
- like `map(f, X)`, but works lazily, doesn't materialize the result returning a view instead.
- like `Iterators.map(f, X)`, but with better collection support, type stability, etc.

Works on different collections and arbitrary iterables. Collection types are preserved when possible for ranges, arrays, dictionaires. Passes `length`, `keys` and others directly to the parent. Does its best to determine the resulting `eltype` without evaluating `f`. Supports both getting and setting values (through `Accessors.jl`).

```julia
X = [1, 2, 3]
mapview(x -> x + 1, X) == [2, 3, 4]  # a view of X, doesn't take extra memory

X = Dict(:a => 1, :b => 2, :c => 3)
mapview(x -> x + 1, X) == Dict(:a => 2, :b => 3, :c => 4)  # same with Dict

X = [1, 2, 3]
mapview(x -> x + 1, (x for x in X))  # and with iterator
```

```julia
julia> X = [1, 2, 3.]

julia> Y = mapview(exp10, X)
3-element FlexiMaps.MappedArray{Float64, 1, typeof(exp10), Vector{Float64}}:
   10.0
  100.0
 1000.0

# setindex! works for all functions/optics supported by Accessors
julia> Y[2] = 10^10

# when invertible, push! also works
julia> push!(Y, 10000)

julia> X
4-element Vector{Float64}:
  1.0
 10.0
  3.0
  4.0
```

# `maprange`

`maprange(f, start, stop; length)`: `length` values between `start` and `stop`, so that `f(x)` is incremented in uniform steps. Uses `mapview` in order not to materialize the array.

`maprange(identity, ...)` is equivalent to `range(...)`. Most common application - log-spaced ranges:

`maprange(log, 10, 1000, length=5) ≈ [10, 31.6227766, 100, 316.227766, 1000]`

Other transformations can also be useful:

`maprange(sqrt, 16, 1024, length=5) == [16, 121, 324, 625, 1024]`
