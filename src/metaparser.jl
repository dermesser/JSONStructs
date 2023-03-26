module Metaparser

import ..Parser: Optional

function is_allowed_field_type(s::Symbol)::Bool
    true
end
function is_allowed_field_type(s::Expr)
    subtyp = s.args[1]
    s.head == :curly && (subtyp == :Vector || subtyp == :Optional)
end

"""Parse a `struct` and convert it into a list of (field name, field typ) pairs.

This is where type expressions are evaluated and turned into types.
"""
function parse_struct_expr(s::Expr, eval::Function)::Vector{Pair{Symbol,Type}}
    s.head == :struct || error("Expr must be struct but is $s")
    args = s.args[2:end]
    typedef = args[1]

    fields = args[2]
    fields.head == :block || error("Expr must contain a block but has $fields")
    fields_exprs = Pair[]
    for f in fields.args
        if typeof(f) == LineNumberNode
            continue
        end
        typeof(f) == Expr || error("Field $f in $typedef must have type!")
        f.head == :(::) || error(
            "Field $f in $typedef must be type! (we don't support constructors etc. - struct must be plain)",
        )
        name, typsym = f.args

        is_allowed_field_type(typsym) || error(
            "typsyme of $f should be symbol or simple type (Vector/Optional) but is $typsym",
        )

        typ = eval(typsym)

        push!(fields_exprs, name => typ)
    end

    fields_exprs
end

function get_type_of_struct(s::Expr)
    s.head == :struct || error("Expr must be struct, is $s")
    typedef = s.args[2]

    if typeof(typedef) == Symbol
        typedef
    elseif typeof(typedef) == Expr
        error("We don't support generic structs yet :(")
    end
end

function map_type_to_parse_method(::Type{<:Number}, mod::Expr, jparg::Symbol)::Expr
    Expr(:call, :($mod.take_num!), jparg)
end
function map_type_to_parse_method(::Type{<:AbstractString}, mod::Expr, jparg::Symbol)::Expr
    Expr(:call, :($mod.take_str!), jparg)
end
function map_type_to_parse_method(::Type{Bool}, mod::Expr, jparg::Symbol)::Expr
    Expr(:call, :($mod.take_bool!), jparg)
end
function map_type_to_parse_method(::Type{<:AbstractDict}, mod::Expr, jparg::Symbol)::Expr
    Expr(:call, :($mod.take_object!), jparg)
end
function map_type_to_parse_method(::Type{<:AbstractVector}, mod::Expr, jparg::Symbol)::Expr
    Expr(:call, :($mod.take_list!), jparg)
end
function map_type_to_parse_method(
    ::Type{Optional{T}},
    mod::Expr,
    jparg::Symbol,
)::Expr where {T}
    map_type_to_parse_method(T, mod, jparg)
end
function map_type_to_parse_method(t::Type{T}, mod::Expr, jparg::Symbol)::Expr where {T}
    if isstructtype(T)
        Expr(:call, :($mod.take_struct!), t, jparg)
    else
        error("Unknown type $T for JSON parsing!")
    end
end

function check_variables_filled_expr(vars::AbstractVector{Pair{Symbol,Type}})::Vector{Expr}
    check_var_cond(sym, typ) = begin
        if typeof(typ) == Union
            quote
                "skipped optional field check"
            end
        else
            syms = string(sym)
            quote
                syms = $syms
                if isnothing($sym)
                    error("Field $syms not given in JSON object!")
                end
            end
        end
    end
    [check_var_cond(sym, typ) for (sym, typ) in vars]
end

function json_parseable(strct, ev)
    typs::Vector{Pair{Symbol,Type}} = parse_struct_expr(strct, ev)
    typ = get_type_of_struct(strct)

    fieldvars = [:($(name)::Union{$typ,Nothing} = nothing) for (name, typ) in typs]
    fieldnames = [name for (name, _) in typs]
    fields_filled_cond = check_variables_filled_expr(typs)
    Mod = :(JSONStructs.Parser)

    methods = [(name, typ, map_type_to_parse_method(typ, Mod, :jp)) for (name, typ) in typs]
    field_dispatch = [
        begin
            fieldname = string(name)
            typname = string(typ)
            quote
                if !matched && key == $(string(name))
                    val = $method
                    $name = something(val)
                    matched = true
                end
            end
        end for (name, typ, method) in methods
    ]

    quote
        $strct

        function $Mod.take_struct!(
            ::Type{$typ},
            jp::$(Mod).JP,
        )::Some{Union{Nothing,$typ}}
            $(fieldvars...)

            ob = $Mod.expect!(jp, '{')
            if !ob
                n = $Mod.take_null!(jp)
                if isnothing(n)
                    $Mod.raise_error(
                        jp,
                        "malformed object: expected object start '{' or null",
                    )
                end
                # object is null, try returning default values (nothing)
                return Some(nothing)
            else
                while true
                    key = $Mod.take_str!(jp)
                    if isnothing(key)
                        break
                    end

                    $Mod.expect!(jp, ':') ||
                        $Mod.raise_error(jp, "malformed object - expected ':'")

                    matched = false
                    $(field_dispatch...)

                    if !matched
                        $Mod.take_val!(jp)
                    end

                    if $Mod.expect!(jp, ',')
                        continue
                    else
                        break
                    end
                end

                $(fields_filled_cond...)

                $Mod.expect!(jp, '}') || $Mod.raise_error("unclosed object")
            end

            Some($(typ)($(fieldnames...)))
        end
    end |> esc
end

macro json_parseable(strct)
    json_parseable(strct, x -> __module__.eval(x))
end

end
