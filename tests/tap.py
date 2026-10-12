"""A robot thumb: attach to a tmux server as a 46-column phone would, tap the status line from
left to right until something answers, and print what reached this terminal.

    python3 tests/tap.py <socket> <session> [from_x] [to_x]

Prints `OSC52 <decoded text> ST|BEL` for the first clipboard escape seen, else the status-line
message the tap produced (`MSG <text>`), else `NOTHING`.
"""
import base64
import fcntl
import os
import pty
import re
import select
import struct
import sys
import termios
import time

sock, session = sys.argv[1], sys.argv[2]
lo = int(sys.argv[3]) if len(sys.argv) > 3 else 1
hi = int(sys.argv[4]) if len(sys.argv) > 4 else 46

pid, fd = pty.fork()
if pid == 0:
    os.environ.pop('TMUX', None)
    os.environ['TERM'] = 'xterm-256color'
    os.execvp('tmux', ['tmux', '-S', sock, 'attach', '-t', session])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 24, 46, 0, 0))


def drain(seconds):
    out, end = b'', time.time() + seconds
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                out += os.read(fd, 65536)
            except OSError:
                break
    return out


drain(1.0)
seen = b''
result = 'NOTHING'
for x in range(lo, hi + 1):
    # SGR mouse: press and release of the left button on row 24, the status line.
    os.write(fd, f'\x1b[<0;{x};24M\x1b[<0;{x};24m'.encode())
    out = drain(0.5)
    seen += out
    i = out.find(b'\x1b]52;c;')
    if i >= 0:
        st, bel = out.find(b'\x1b\\', i), out.find(b'\x07', i)
        end = st if st >= 0 else bel
        result = f"OSC52 {base64.b64decode(out[i + 7:end]).decode()} {'ST' if st >= 0 else 'BEL'}"
        break
    m = re.search(rb'(my own tap|\xf0\x9f\x93\x8b [^\x1b\r\n]+)', out)
    if m:
        result = 'MSG ' + m.group(1).decode().strip()
        break
os.kill(pid, 9)
print(result)
