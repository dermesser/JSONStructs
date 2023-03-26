
module Parser

const Optional{T} = Union{T,Nothing}

"""A JSON parsing exception."""
struct JSONException
    pos::Int
    tok::String
    reason::String
end

function Base.show(io::IO, je::JSONException)
    print(
        io,
        "JSONException: " *
        je.reason *
        " at position $(je.pos), unexpected token: " *
        je.tok,
    )
end

# JSON parser struct.
mutable struct JP
    s::String
    pos::Int
    length::Int
end

@inline function JP(s::AbstractString)::JP
    JP(string(s), 1, length(s))
end

@inline function raise_error(jp::JP, reason::AbstractString = "")::JSONException
    throw(JSONException(jp.pos, lookahead_word(jp), reason))
end

@inline function current(jp::JP)::Char
    jp.s[jp.pos]
end

@inline function next!(jp::JP)
    jp.pos += 1
end

@inline function isend(jp::JP)
    jp.pos > jp.length
end

@inline function reset!(jp::JP)
    jp.pos = 1
end

const FLOAT_CHARS = ['e', '.', '-']

# The take_...! functions return nothing on parsing failure, or a value.
# The value might be nothing (i.e., Some(nothing)) if the JSON object contained a null.

function take_num!(jp::JP)::Union{Nothing,Some{Union{Nothing,Float64,Int}}}
    isfloatstr(c) = c in FLOAT_CHARS
    pred(c) = isdigit(c) || isfloatstr(c)
    span = takewhile!(jp, pred)
    if isnothing(span)
        if !isnothing(take_null!(jp))
            Some(nothing)
        else
            nothing
        end
    else
        a, b = span
        s = (@view jp.s[a:b])
        Some(parse(Float64, s))
    end
end

function take_bool!(jp::JP)::Union{Nothing,Bool}
    if expect!(jp, "true")
        true
    elseif expect!(jp, "false")
        false
    else
        nothing
    end
end

function take_object!(jp::JP)::Union{Nothing,Some{Union{Nothing,Dict{String,Any}}}}
    d = take_object_literal!(jp)
    if isnothing(d)
        if isnothing(take_null!(jp))
            nothing
        else
            Some(nothing)
        end
    else
        Some(d)
    end
end

function take_null!(jp::JP)::Union{Some{Nothing},Nothing}
    if expect!(jp, "null")
        Some(nothing)
    else
        nothing
    end
end

function take_object_literal!(jp::JP)::Union{Nothing,Dict{String,Any}}
    expect!(jp, '{') || return nothing

    d = Dict{String,Any}()
    while true
        key = take_str!(jp)
        if isnothing(key)
            # Empty object
            break
        end

        expect!(jp, ':') || raise_error(jp, "malformatted object - expecting ':'")

        val = take_val!(jp)

        d[key] = val
        if expect!(jp, ',')
            continue
        else
            # End of object
            break
        end
    end

    expect!(jp, '}') || raise_error(jp, "Unclosed object - '}' missing")
    d
end

function take_str!(jp::JP)::Union{Nothing,String}
    expect!(jp, '"') || return nothing

    span = takewhile!(jp, (!=)('"'), false)
    if isnothing(span)
        raise_error(jp, "unclosed string at $(jp.pos)")
    end

    expect!(jp, '"') || raise_error(jp, "unclosed string at $(jp.pos)")
    a, b = span
    jp.s[a:b]
end

function take_list!(jp::JP)::Union{Nothing,Some{Union{Nothing,Vector{Any}}}}
    if expect!(jp, '[')
        l = Any[]
        while true
            o = take_val!(jp)
            if isnothing(o)
                break
            else
                push!(l, something(o))
            end

            if expect!(jp, ',')
                continue
            else
                break
            end
        end

        expect!(jp, ']') || raise_error(jp, "Missing closing ']' at $(jp.pos)")
        Some(l)
    else
        return take_null!(jp)
    end
end

"""value is anything - object/list/number/boolean/string"""
function take_val!(jp::JP)::Union{Nothing,Some{Union{Nothing,Any}}}
    n = take_num!(jp)
    if !isnothing(n)
        return Some(n)
    end
    s = take_str!(jp)
    if !isnothing(s)
        return Some(s)
    end
    l = take_list!(jp)
    if !isnothing(l)
        return l
    end
    d = take_object!(jp)
    if !isnothing(d)
        return d
    end
    b = take_bool!(jp)
    if !isnothing(b)
        return Some(b)
    end
    nothing
end

function take_struct!(t::Type{T}, jp::JP)::Union{Nothing,T} where {T}
    raise_error(jp, "JSON Parsing not implemented for type $t")
end

function strip_ws!(jp::JP)
    while !isend(jp) && isspace(jp.s[jp.pos])
        jp.pos += 1
    end
end

function takewhile!(jp::JP, pred::Function, stripws = true)::Union{Nothing,Tuple{Int,Int}}
    if stripws
        strip_ws!(jp)
    end
    if !isend(jp) && pred(current(jp))
        a = jp.pos
        while !isend(jp) && pred(current(jp))
            next!(jp)
        end
        (a, jp.pos - 1)
    else
        nothing
    end
end

@inline function expect!(jp::JP, c::Char)::Bool
    strip_ws!(jp)
    if current(jp) == c
        next!(jp)
        true
    else
        false
    end
end

function expect!(jp::JP, pref::AbstractString)::Bool
    strip_ws!(jp)
    pl = length(pref)

    if (@view jp.s[jp.pos:min(jp.length, jp.pos + pl - 1)]) == pref
        jp.pos += pl
        true
    else
        false
    end
end

function lookahead_word(jp::JP)::String
    i = jp.pos
    while !isspace(jp.s[i]) && i < jp.length
        i += 1
    end
    jp.s[jp.pos:i-1]
end

"""Parse a json value.."""
function parse_value(s::AbstractString)
    jp = JP(s)
    take_val!(jp)
end

"""Parse a struct that is marked with @json_parseable."""
function parse_struct(t::Type{T}, s::AbstractString)::Some{Union{Nothing,T}} where {T}
    take_struct!(t, JP(s))
end

end
