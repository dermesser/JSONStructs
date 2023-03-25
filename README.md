# `JSONStructs.jl`

**Warning:** This is not (yet) a production-grade JSON parser!

This package implements a macro, `@json_parseable`, that generates custom parsers for your structs,
similarly to how `#[derive(Serialize,Deserialize)]` works with `serde` in Rust.

The `JSON3.jl` package offers similar functionality, but is (in my opinion) a bit more complicated.
Regardless, you might want to use it instead of this immature package.

## Example

See e.g. `tests/runtests.jl` for a short example:

```julia
using JSONStructs

@json_parseable struct TestStruct1
    a::Int
    b::Float64
    c::Vector{String}
end

function test_parse_1()
    json = "{\"a\": 33, \"b\": 55.55, \"c\": [\"xyz\", \"abc\"]}"
    have = parse_struct(TestStruct1, json)
    want = TestStruct1(33, 55.55, ["xyz", "abc"])
    @assert string(have) == string(want) "$have == $want"
end

```

The `@json_parseable` macro parses the struct (Note: this might fail if you define constructors or a
generic struct! Keep it simple) and generates a method for this specific type. The method's code is
generated specifically for this struct. As of now, all fields are mandatory, and unknown fields are
ignored -- this obviously needs to change before it can be used productively :-)

## Advantages

Over `JSON.jl`:

* You get strongly-typed parsing results instead of `Dict`s and `Any`s.
* Performance is better. For very simple structs, e.g. two numeric fields, this package is already
40% faster than the `JSON` package.

