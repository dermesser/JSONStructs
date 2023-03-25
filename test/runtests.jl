# Some basic tests.

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

@json_parseable struct OuterStruct
    a::String
    b::TestStruct1
end

function test_parse_2()
    json = "{\"a\": \"Outer Struct\", \"b\": {\"a\": 33, \"b\": 55.55, \"c\": [\"xyz\", \"abc\"]}}"
    have = parse_struct(OuterStruct, json)
    want = OuterStruct("Outer Struct", TestStruct1(33, 55.55, ["xyz", "abd"]))
    @show have, want
    @assert string(have) == string(want) "$have == $want"
end

println("Starting JSONStructs test")
test_parse_1()
test_parse_2()
