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


test_parse_1()
