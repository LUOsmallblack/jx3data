#%%
# @show unsafe_load(JavaCall.penv)
# ppenv = Array{Ptr{JavaCall.JNIEnv}}(undef, 1)
# ccall(JavaCall.jvmfunc.AttachCurrentThread, Cint, (Ptr{JavaCall.JavaVM}, Ptr{Ptr{JavaCall.JNIEnv}}, Ptr{Cvoid}), JavaCall.pjvm, ppenv, C_NULL)
# unsafe_load(ppenv[1])
using JavaCall
import JavaCall._metaclass

#%%
JClassLoader = @jimport(java.lang.ClassLoader)
JURL = @jimport(java.net.URL)
JThread = @jimport(java.lang.Thread)
# current_classloader = @java JThread.currentThread().getContextClassLoader()
# @java JThread.currentThread().getContextClassLoader()

function init_java_classloader()
    global spcl = new_spcl()
    set_current_classloader(convert(JClassLoader, spcl))
    set_javacall_classloader(convert(JClassLoader, spcl))
    spcl
end

classloader = nothing
set_javacall_classloader(new_loader::Union{JClassLoader, Nothing}) = global classloader = new_loader
get_current_classloader() = @java JThread.currentThread().getContextClassLoader()
set_current_classloader(cl) = @java JThread.currentThread().setContextClassLoader(cl)
function with_java_classloader(block, classloader)
    current_classloader = get_current_classloader()
    try
        set_current_classloader(classloader)
        return block()
    finally
        set_current_classloader(current_classloader)
    end
end

new_spcl() = new_spcl(get_current_classloader())
new_spcl(parent) = @jimport(javacall.SpecialClassLoader)((Array{JURL, 1}, JClassLoader), [], parent)

function JavaCall._metaclass(class::Symbol)
    @show jclass = JavaCall.javaclassname(class)
    jclassptr = if classloader == nothing || class == Symbol("java.lang.Class")
        ccall(JavaCall.jnifunc.FindClass, Ptr{Nothing}, (Ptr{JavaCall.JNIEnv}, Ptr{UInt8}), JavaCall.penv, jclass)
    else
        classClass = JavaCall.metaclass(JClass)
        sig = JavaCall.method_signature(JClass, JString, jboolean, JClassLoader)
        jmethodId = ccall(JavaCall.jnifunc.GetStaticMethodID, Ptr{Nothing},
                          (Ptr{JavaCall.JNIEnv}, Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}), JavaCall.penv, classClass,
                          "forName", sig)
        @assert jmethodId != C_NULL
        jclassstr = convert(JString, String(class))
        ccall(JavaCall.jnifunc.CallStaticObjectMethodA, Ptr{Nothing}, (Ptr{JavaCall.JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
                            JavaCall.penv, classClass.ptr, jmethodId, JavaCall.jvalue.([jclassstr.ptr, jboolean(false), classloader.ptr]))
    end
    jclassptr == C_NULL && throw(JavaCall.JavaCallError("Class Not Found $jclass"))
    return JavaMetaClass(class, jclassptr)
end

# @java spcl.add("jars/jx3app-analyze-1.jar")
#%%
# @show @java JThread.currentThread().getId()
# Threads.threadid()
# @show (x -> @java x.toString()).(@java JThread.currentThread().getStackTrace())
# @show stacktrace()
# run(`bash -c "echo \$PPID"`)
# ccall((:syscall, "/usr/lib/libc.so.6"), Clong, (Clong,), 186) # SYS_gettid __NR_gettid
#
# function jprocess_result(pr)
#     isr = @jimport(java.io.InputStreamReader)((@jimport(java.io.InputStream),), @java pr.getInputStream())
#     br = @jimport(java.io.BufferedReader)((@jimport(java.io.Reader),), isr)
#     lines = []
#     # while (line = @java br.readLine()) != nothing
#     #     push!(lines, @show line)
#     # end
#     @java br.readLine()
# end
# jprocess_result(@java @jimport(java.lang.Runtime).getRuntime().exec(["bash", "-c", "echo \$PPID"]))

#%%
# spcl = get_spcl()
# @java spcl.add("jars/postgresql-42.2.5.jar")
# @show (x -> @java x.toString()).(@java spcl.getURLs())
# set_current_classloader(spcl)
# get_current_classloader()
# @show JavaCall._metaclass(Symbol("java.lang.ClassLoader"))
# # @java JClass.forName("java.lang.ClassLoader", jboolean(true), spcl)
# @show JavaCall._metaclass(Symbol("jx3app.case_class.v1.Replay\$"))
# JReplay = @jimport("jx3app.case_class.v1.Replay\$")
# @java JClass.forName("jx3app.case_class.v1.Replay\$", jboolean(true), spcl)
# JReplay_i = @java jfield(JReplay, "MODULE\$", JReplay)
# @java JReplay_i.encoder()
# @java spcl.getClass()
# #%%
# @java jcall(JReplay_, "getClassLoader", JClassLoader, ()).toString()
# (x -> @java x.toString()).(@java jcall(JReplay_, "getFields", Array{@jimport(java.lang.reflect.Field),1}, ()))
# (x -> @java x.toString()).(@java jcall(JReplay_, "getMethods", Array{@jimport(java.lang.reflect.Method),1}, ()))
# @java jfield(JReplay, "MODULE\$", JReplay)
# JavaCall.metaclass(JReplay)
#
# JavaCall.geterror()
