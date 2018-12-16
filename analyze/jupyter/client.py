from jupyter_client import KernelManager
from jupyter_client.threaded import ThreadedKernelClient as KernelClient, ThreadedZMQSocketChannel as ZMQSocketChannel
from jupyter_client.kernelspec import KernelSpec
from jupyter_client.channels import HBChannel

import os, sys, json, datetime

def get_output(cmd):
    from subprocess import Popen, PIPE
    proc = Popen(cmd, stdin=PIPE, stdout=PIPE, start_new_session=True)
    (out, _) = proc.communicate()
    proc.stdin.close()
    return out

def find_ijulia(julia_path='/usr/bin/julia'):
    return get_output([julia_path, '-e', 'import IJulia; print(pathof(IJulia))']).decode()

def julia_spec(kernel_path=None, *, julia_path='/usr/bin/julia'):
    if kernel_path is None:
        kernel_path = os.path.join(os.path.dirname(find_ijulia()), "kernel.jl")
    julia_argv=[julia_path,'-i','--startup-file=yes','--color=yes',kernel_path,'{connection_file}']
    return KernelSpec(display_name="julia", env={}, language="julia", argv=julia_argv)

def json_default(obj):
    if isinstance(obj, datetime.datetime):
        return str(obj)
    else:
        debug_print("dump", str(type(obj)))
    return repr(obj)

def channel_print(channel, msg):
    try:
        msg = json.dumps(msg, default=json_default)
    except:
        pass
    print(f"{channel}>{msg}")
    # print(f"{channel}>{msg}", end="\r\n", file=sys.stderr)

def debug_print(*args, newline=sys.stdin.isatty() and "\n" or "\r\n"):
    msg = args
    if len(args) == 1:
        msg = args[0]
    print("debug", msg, end=newline, file=sys.stderr)

class StdoutHandler:
    channel_name = "dummy"
    def call_handlers(self, msg):
        channel_print(self.channel_name, msg)

class HBOutputChannel(StdoutHandler, HBChannel):
    channel_name = "hb"
class ShellOutputChannel(StdoutHandler, ZMQSocketChannel):
    channel_name = "shell"
class StdInOutputChannel(StdoutHandler, ZMQSocketChannel):
    channel_name = "stdin"
class IOPubOutputChannel(StdoutHandler, ZMQSocketChannel):
    channel_name = "iopub"

supported_request = [
    'comm_info_request',
    'complete_request',
    'execute',
    'execute_request',
    'history_request',
    'input_reply',
    'input_request',
    'inspect_request',
    'is_complete_request',
    'kernel_info_request',
    'msg',
    'shutdown_request',
]

def gen_msg(kc, msg):
    msg = json.loads(msg)
    if isinstance(msg, dict):
        msg_type = msg["msg_type"]
        content = msg["content"]
    elif isinstance(msg, list):
        msg_type, content = msg
    else:
        debug_print("input", str(type(msg)))
    if msg_type not in supported_request:
        debug_print("input", msg_type)
    return kc.session.msg(msg_type, content)

def start_kernel(spec):
    km = KernelManager(kernel_name=spec.language)
    km._kernel_spec = spec
    km.start_kernel()
    return km

def connect_kernel(connection_file):
    kc = KernelClient(
        hb_channel_class=HBOutputChannel,
        shell_channel_class=ShellOutputChannel,
        stdin_channel_class=StdInOutputChannel,
        iopub_channel_class=IOPubOutputChannel)
    kc.load_connection_file(connection_file)
    kc.start_channels()
    return kc

def event_loop(kc):
    channels = {
        "hb": kc.hb_channel,
        "shell": kc.shell_channel,
        "stdin": kc.stdin_channel,
        "iopub": kc.iopub_channel,
    }
    while True:
        try:
            line = input()
            [channel, msg] = line.split(">", 1)
            msg = gen_msg(kc, msg)
            debug_print("msg", msg)
            channels[channel].send(msg)
            channel_print("msgid", msg["header"]["msg_id"])
        except KeyboardInterrupt:
            debug_print("exit", "interrupt")
            break
        except EOFError:
            debug_print("exit", "eoferror")
            break
        except Exception as e:
            debug_print("error", e)

if __name__ == "__main__":
    import readline
    spec = julia_spec()
    km = start_kernel(spec)
    kc = connect_kernel(km.connection_file)
    event_loop(kc)
    kc.ioloop_thread.join()
