#%%
# @show unsafe_load(JavaCall.penv)
# ppenv = Array{Ptr{JavaCall.JNIEnv}}(undef, 1)
# ccall(JavaCall.jvmfunc.AttachCurrentThread, Cint, (Ptr{JavaCall.JavaVM}, Ptr{Ptr{JavaCall.JNIEnv}}, Ptr{Cvoid}), JavaCall.pjvm, ppenv, C_NULL)
# unsafe_load(ppenv[1])

#%%
JClassLoader = @jimport(java.lang.ClassLoader)
JURL = @jimport(java.net.URL)
JThread = @jimport(java.lang.Thread)
current_classloader = @java JThread.currentThread().getContextClassLoader()
@java JThread.currentThread().getContextClassLoader()

function with_java_classloader(block, classloader)
    current_classloader = @java JThread.currentThread().getContextClassLoader()
    try
        @java JThread.currentThread().setContextClassLoader(classloader)
        return block()
    finally
        @java JThread.currentThread().setContextClassLoader(current_classloader)
    end
end

spcl = @jimport(javacall.SpecialClassLoader)((Array{JURL, 1}, JClassLoader), [], current_classloader)
# @java spcl.add("jars/jx3app-analyze-1.jar")
JavaCall.set_classloader(convert(JClassLoader, spcl))
JavaCall.classloader
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
# @show (x -> @java x.toString()).(@java spcl.getURLs())
# @java JThread.currentThread().setContextClassLoader(spcl)
# @java JThread.currentThread().getContextClassLoader()
# # @show JavaCall._metaclass(Symbol("java.lang.ClassLoader"))
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
