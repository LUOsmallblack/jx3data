using JavaCall, JSON, DataFrames

convertible(javatype::Type, juliatype::Type) = hasmethod(convert, Tuple{Type{javatype}, juliatype})

function jtypeforclass(cls::JClass)
    isarray(cls) = jcall(cls, "isArray", jboolean, ()) != 0x00
    if isarray(cls)
        jcomponentcls = jcall(cls, "getComponentType", JClass, ())
        return Array{jtypeforclass(jcomponentcls), 1}
    end
    name = getname(cls)
    if name == "void"
        Nothing
    elseif name == "boolean"
        jboolean
    elseif name == "char"
        jchar
    elseif name == "short"
        jshort
    elseif name == "float"
        jfloat
    elseif name == "double"
        jdouble
    elseif name == "int"
        jint
    elseif name == "long"
        jlong
    else
        JavaObject{Symbol(name)}
    end
end

function _narrow(obj::JavaObject)
    c = jcall(obj,"getClass", JClass, ())
    return convert(jtypeforclass(c), obj)
end
_narrow(obj::JavaCall.jprimitive) = obj

function findmethod(obj::Union{JavaObject{C}, Type{JavaObject{C}}}, name::AbstractString, args...) where C
    allmethods = listmethods(obj, name)
    filter(allmethods) do m
        params = getparametertypes(m)
        if length(params) != length(args)
            return false
        end
        all([convertible(jtypeforclass(c), typeof(a)) for (c, a) in zip(getparametertypes(m), args)])
    end
end

function jdcall(obj::Union{JavaObject{C}, Type{JavaObject{C}}}, name::AbstractString, args...) where C
    matchmethods = findmethod(obj, name, args...)
    if length(matchmethods) == 0
        allmethods = listmethods(obj, name)
        candidates = join(allmethods, "\n  ")
        error("no match methods $name for $obj, candidates are:\n  $candidates")
    elseif length(matchmethods) > 1
        candidates = join(matchmethods, "\n  ")
        error("multiple methods $name for $obj, candidates are:\n  $candidates")
    end
    matchmethod = matchmethods[1]
    rettype = jtypeforclass(getreturntype(matchmethod))
    argstype = tuple(map(jtypeforclass, getparametertypes(matchmethod))...)
    # println("type: $rettype ($argstype)")
    return jcall(obj, name, rettype, argstype, args...)
end

function parse_json(result::Array{JString})
    data = map(result) do line
        JavaCall.unsafe_string(line) |> JSON.parse
    end
    allkeys = union([keys(r) for r in data]...)
    df = DataFrame()
    for key in allkeys
      df[Symbol(key)] = map(data) do row
        value = get(row, key, nothing)
        if value == nothing
            missing
        else
            value
        end
      end
    end
    return df
end

macro spark(expr)
    function apply_args(args)
        if length(args) == 1
            arg = args[1]
            if isa(arg, Expr) && arg.head == :...
                @assert length(arg.args) == 1
                arg = arg.args[1]
                if isa(arg, Symbol)
                    return [:($(arg)[1]), :($(arg)[2:end])]
                elseif isa(arg, Expr) && arg.head ∈ (:hcat, :vect)
                    first_arg = arg.args[1]
                    popfirst!(arg.args)
                    return [first_arg, arg]
                end
                return :((args->(args[1], collect(args[2:end])))($(arg)))
            end
        end
        return args
    end
    function change(expr::Expr)
        if expr.head == :call
            func = expr.args[1]
            args = apply_args(expr.args[2:end])
            if isa(func, Expr) && func.head == :.
                @assert length(func.args) == 2
                base = change(func.args[1])
                quoted = func.args[2]
                @assert isa(quoted, QuoteNode)
                if isa(args, Array)
                    return :(jdcall($base, $(string(quoted.value)), $(args...)))
                else
                    return :(jdcall($base, $(string(quoted.value)), $(args)...))
                end
            end
        end
    end
    function change(expr::Symbol)
        :($(expr).jdf)
    end
    return :(_narrow($(change(expr))))
end
