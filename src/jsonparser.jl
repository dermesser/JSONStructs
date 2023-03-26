
module Parser

const Optional{T} = Union{T,Nothing}

# JSON parser struct.
mutable struct JP
    s::String
    pos::Int
    length::Int
end

@inline function JP(s::AbstractString)::JP
    JP(string(s), 1, length(s))
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

function take_num!(jp::JP)::Union{Nothing,Float64,Int}
    isfloatstr(c) = c in FLOAT_CHARS
    pred(c) = isdigit(c) || isfloatstr(c)
    span = takewhile!(jp, pred)
    if isnothing(span)
        nothing
    else
        a, b = span
        s = (@view jp.s[a:b])
        parse(Float64, s)
    end
end

function take_bool!(jp::JP)::Union{Nothing,Bool}
    if expect_prefix!(jp, "true")
        true
    elseif expect_prefix!(jp, "false")
        false
    else
        nothing
    end
end

function take_object!(jp::JP)::Union{Nothing,Dict{String,Any}}
    expect!(jp, '{') || return nothing

    d = Dict{String,Any}()
    while true
        key = take_str!(jp)
        if isnothing(key)
            # Empty object
            break
        end

        expect!(jp, ':') || error("malformatted object - expecting ':'")

        val = take_val!(jp)

        d[key] = val
        if expect!(jp, ',')
            continue
        else
            # End of object
            break
        end
    end

    expect!(jp, '}') || error("Unclosed object - '}' missing")
    d
end

function take_str!(jp::JP)::Union{Nothing,String}
    expect!(jp, '"') || return nothing

    span = takewhile!(jp, (!=)('"'), false)
    if isnothing(span)
        error("unclosed string at $(jp.pos)")
    end

    expect!(jp, '"') || error("unclosed string at $(jp.pos)")
    a, b = span
    jp.s[a:b]
end

function take_list!(jp::JP)::Union{Nothing,Vector{Any}}
    expect!(jp, '[') || return nothing

    l = Any[]
    while true
        o = take_val!(jp)
        if isnothing(o)
            break
        else
            push!(l, o)
        end

        if expect!(jp, ',')
            continue
        else
            break
        end
    end

    expect!(jp, ']') || error("Missing closing ']' at $(jp.pos)")
    l
end

"""value is anything - object/list/number/boolean/string"""
function take_val!(jp::JP)::Union{Nothing,Any}
    n = take_num!(jp)
    if !isnothing(n)
        return n
    end
    s = take_str!(jp)
    if !isnothing(s)
        return s
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
        return b
    end
    nothing
end

function take_struct!(t::Type{T}, ::JP)::Union{Nothing,T} where {T}
    error("JSON Parsing not implemented for type $t")
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

function expect_prefix!(jp::JP, pref::AbstractString)::Bool
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
function parse_struct(t::Type{T}, s::AbstractString)::T where {T}
    take_struct!(t, JP(s))
end

end
