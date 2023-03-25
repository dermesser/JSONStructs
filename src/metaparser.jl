module Metaparser

function parse_struct_expr(s::Expr)
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
        name, typ = f.args

        is_type = (typeof(typ) == Symbol || (typeof(typ) == Expr && typ.head == :curly))
        is_type ||
            error("Type of $f should be symbol (simple type) but is $(typeof(typ)): $typ")

        typ = eval(typ)
        isconcretetype(typ) ||
            error("Type of field $name must be concrete, but is not (is $typ)!")

        push!(fields_exprs, name => eval(typ))
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

function map_type_to_parse_method(::Type{<:Number})::Symbol
    :take_num!
end
function map_type_to_parse_method(::Type{<:AbstractString})::Symbol
    :take_str!
end
function map_type_to_parse_method(::Type{Bool})::Symbol
    :take_bool!
end
function map_type_to_parse_method(::Type{<:AbstractDict})::Symbol
    :take_object!
end
function map_type_to_parse_method(::Type{<:AbstractVector})::Symbol
    :take_list!
end
function map_type_to_parse_method(::Type{T})::Symbol where {T}
    error("unexpected type")
    if isstructtype(T)
        :take_struct!
    else
        error("Unknown type $T for JSON parsing!")
    end
end

function check_variables_filled_expr(varnames::AbstractVector{Symbol})::Vector{Expr}
    check_var_cond(sym) = begin
        syms = string(sym)
        quote
            syms = $syms
            if isnothing($sym)
                error("Field $syms not given in JSON object!")
            end
        end
    end
    [check_var_cond(s) for s in varnames]
end

function json_parseable(strct)
    typs::Vector{Pair{Symbol,Type}} = parse_struct_expr(strct)
    typ = get_type_of_struct(strct)

    fieldvars = [:($(name)::Union{$typ,Nothing} = nothing) for (name, typ) in typs]
    fieldnames = [name for (name, _) in typs]
    fields_filled_cond = check_variables_filled_expr(fieldnames)
    Mod = :(JSONStructs.Parser)

    methods = [(name, map_type_to_parse_method(typ)) for (name, typ) in typs]
    field_dispatch = [
        quote
            if !matched && key == $(string(name))
                $name = $Mod.$(method)(jp)
                matched = true
            end
        end for (name, method) in methods
    ]

    quote
        $strct

        function $Mod.take_struct!(::Type{$typ}, jp::$(Mod).JP)::Union{Nothing,$typ}
            $Mod.expect!(jp, '{') || return nothing

            $(fieldvars...)

            while true
                key = $Mod.take_str!(jp)
                if isnothing(key)
                    break
                end

                $Mod.expect!(jp, ':') || error("malformed object - expected ':'")

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

            $Mod.expect!(jp, '}') || error("unclosed object")

            $(typ)($(fieldnames...))
        end
    end |> esc
end

macro json_parseable(strct)
    json_parseable(strct)
end

end
