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
    want = OuterStruct("Outer Struct", TestStruct1(33, 55.55, ["xyz", "abc"]))
    @assert string(have) == string(want) "$have == $want"
end

# Optional fields
@json_parseable struct WithOptional
    a::Optional{Int}
    b::Optional{TestStruct1}
end

function test_parse_3()
    json = "{\"a\": 1234, \"b\": {\"a\": 33, \"b\": 55.55, \"c\": [\"xyz\", \"abc\"]}}"
    have = parse_struct(WithOptional, json)
    want = WithOptional(1234, TestStruct1(33, 55.55, ["xyz", "abc"]))
    @assert string(have) == string(want) "$have == $want"
end

function test_parse_4()
    json = "{\"a\": 1234}"
    have = parse_struct(WithOptional, json)
    want = WithOptional(1234, nothing)
    @assert string(have) == string(want) "$have == $want"
end
function test_parse_5()
    json = "{}"
    have = parse_struct(WithOptional, json)
    want = WithOptional(nothing, nothing)
    @assert string(have) == string(want) "$have == $want"
end
function test_parse_6()
    json = "{\"b\": nul}"
    have = parse_struct(WithOptional, json)
    want = WithOptional(nothing, nothing)
    @assert string(have) == string(want) "$have == $want"
end

println("Starting JSONStructs test")
test_parse_1()
test_parse_2()
test_parse_3()
test_parse_4()
test_parse_5()
test_parse_6()
