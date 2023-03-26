using BenchmarkTools

using JSON
using JSONStructs

@json_parseable struct InnerStruct
    x::Int
    y::Float64
end

@json_parseable struct OuterStruct
    a::Int
    b::Float64
    c::String
    d::Optional{Bool}
    e::Vector{Int}
    f::Optional{InnerStruct}
end

const Test_JSON_string_full = """
{"a": 12, "b": 1.23, "c": "a string", "d": true, "e": [1,2,3,4], "f": {"x": 12, "y": 111.222}}
"""
const Test_JSON_string_short = """
{"a": 12, "b": 1.23, "c": "a string", "e": [1]}
"""

function benchmark_comparison_full(s::String)
    println("benchmark: ", s)
    @show parse_struct(OuterStruct, s)

    println("JSONStructs parse_struct")
    display(@benchmark parse_struct(OuterStruct, $s))

    println("JSONStructs parse_value")
    display(@benchmark parse_value($s))

    println("JSON")
    display(@benchmark JSON.parse($s))
end


benchmark_comparison_full(Test_JSON_string_full)
benchmark_comparison_full(Test_JSON_string_short)
