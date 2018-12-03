using JavaCall, JSON, DataFrames

convertible(::Type{JavaObject{T}}, ::Type{JavaObject{S}}) where {T, S} = JavaCall.isConvertible(T, S)
convertible(::Type{T}, juliatype::Type) where T <: JavaCall.jprimitive = juliatype == T
convertible(javatype::Type{JavaObject{T}}, juliatype::Type{S}) where {T, S} = hasmethod(convert, Tuple{Type{javatype}, juliatype})
convertible(javatype::Type{Array{JavaObject{T}, 1}}, juliatype::Type{Array{S, 1}}) where {T, S} = convertible(JavaObject{T}, S)
convertible(javatype::Type{Array{JavaObject{T}, 1}}, juliatype::Type{Array{Any, 0}}) where T = true
convertible(javatype::Type{Array{JavaObject{T}, 1}}, juliatype::Type) where T = false

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
_narrow(obj::Array) = _narrow.(obj)
_narrow(obj::String) = obj
_narrow(obj::JavaCall.jprimitive) = obj
_narrow(::Nothing) = nothing

int_obj(x) = convert(JObject, JInteger((jint,), x))
bool_obj(x) = convert(JObject, JavaObject{Symbol("java.lang.Boolean")}((jboolean,), x))

typeof_fixemptyarray(a) = isa(a, Union{Array{Any}, Array{Union{}}}) && isempty(a) ? Array{Any, 0} : typeof(a)
function findmethod(obj::Union{JavaObject{C}, Type{JavaObject{C}}}, name::AbstractString, args...) where C
    allmethods = listmethods(obj, name)
    filter(allmethods) do m
        params = getparametertypes(m)
        if length(params) != length(args)
            return false
        end
        all([convertible(jtypeforclass(c), typeof_fixemptyarray(a)) for (c, a) in zip(getparametertypes(m), args)])
    end
end

function jdcall_cached end

function jdcall_cache_clear!()
    for m in methods(jdcall_cached)
        Base.delete_method(m)
    end
end

function jdcall_cache(obj::Union{JavaObject{C}, Type{JavaObject{C}}}, name::AbstractString, args...) where C
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

    basetype = isa(obj, DataType) ? Type{obj} : typeof(obj)
    args_julia = Symbol.(string.("arg", 1:length(args)))
    params_julia = [:($name::$type) for (name, type) in zip(args_julia, typeof.(args))]
    eval(:(function jdcall_cached(base::$(basetype), ::Val{$(QuoteNode(Symbol(name)))}, $(params_julia...))
      @show jcall(base, $name, $rettype, $argstype, $(args_julia...))
    end))
    return rettype, argstype
end

function jdcall(obj::Union{JavaObject{C}, Type{JavaObject{C}}}, name::AbstractString, args...) where C
    if !applicable(jdcall_cached, obj, Val(Symbol(name)), args...) || true
        rettype, argstype = jdcall_cache(obj, name, args...)
        return jcall(obj, name, rettype, argstype, args...)
    end
    @info("using cached $(@which jdcall_cached(obj, Val(Symbol(name)), args...))")
    return @show jdcall_cached(obj, Val(Symbol(name)), args...)
end

function parse_json(result::Array{JString})
    data = map(result) do line
        JavaCall.unsafe_string(line) |> JSON.parse
    end
    allkeys = foldl(union, [keys(r) for r in data])
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
function dump_json(result::DataFrame)
    data = [Dict(collect(pairs(row))) for row in eachrow(kungfu_cn_df)]
    map(data) do row
        JSON.json(row)
    end
end

function macro_javacall(trans_term, trans_call, expr)
    function change(expr::Expr)
        if expr.head == :call
            func = expr.args[1]
            args = expr.args[2:end]
            if isa(func, Expr) && func.head == :.
                @assert length(func.args) == 2
                base = change(func.args[1])
                quoted = func.args[2]
                @assert isa(quoted, QuoteNode)
                return trans_call(base, quoted.value, args)
            end
        end
        trans_term(expr)
    end
    change(expr) = trans_term(expr)
    @show :(_narrow($(esc(change(expr)))))
end

try_wrap(x) = x
try_wrap(x::Spark.JDataset) = Dataset(x)

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
                    # TODO: handle f([a...]...)
                    first_arg = arg.args[1]
                    popfirst!(arg.args)
                    return [first_arg, arg]
                end
                return :((args->(args[1], collect(args[2:end])))($(arg)))
            end
        end
        return args
    end
    trans_term(expr::Symbol) = :($(expr).jdf)
    function trans_call(base, method, args)
        args = apply_args(args)
        if isa(args, Array)
            :(jdcall($(base), $(string(method)), $(args...)))
        else
            :(jdcall($(base), $(string(method)), $(args)...))
        end
    end
    :(try_wrap($(macro_javacall(trans_term, trans_call, expr))))
end

functions = @jimport org.apache.spark.sql.functions
function try_call(base, method, args...)
    try
        jdcall(base, method, args...)
    catch
        jdcall(functions, method, base, args...)
    end
end

macro col(expr)
    trans_term(expr::Symbol) = :(jdcall(functions, "col", $(string(expr))))
    function trans_term(expr::Expr)
        if expr.head == :call
            func = expr.args[1]
            args = expr.args[2:end]
            return :(jdcall(functions, $(string(func)), $(args...)))
        end
        expr
    end
    trans_call(base, method, args) = :(try_call($(base), $(string(method)), $(args...)))
    macro_javacall(trans_term, trans_call, expr)
end

macro java(expr)
    trans_term(expr) = expr
    trans_call(base, method, args) = :(jdcall($(base), $(string(method)), $(args...)))
    macro_javacall(trans_term, trans_call, expr)
end

#%%
import Base.convert
JInteger = @jimport java.lang.Integer
JIterable = @jimport java.lang.Iterable
JList = @jimport java.util.List
JArray = @jimport java.util.Array
JArrays = @jimport java.util.Arrays
JSeq = @jimport scala.collection.Seq
JConverters = @jimport scala.collection.JavaConverters
JAsScala = @jimport scala.collection.convert.Decorators$AsScala
JScalaIterable = @jimport scala.collection.Iterable
function convert(::Type{JSeq}, obj::S) where S <: Union{JList, JArray}
    jasscala = jcall(JConverters, "iterableAsScalaIterableConverter", JAsScala, (JIterable,), obj)
    jscala = jcall(jasscala, "asScala", JObject, ()) |> _narrow
    jcall(jscala, "toSeq", JSeq, ())
end

function seq(a...)
    list = jdcall(JArrays, "asList", collect(a))
    convert(JSeq, list)
end
