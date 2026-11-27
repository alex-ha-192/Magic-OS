#!/usr/bin/env python3
"""Tiny QMP client for the VM tests.
   qmp.py SOCKET screendump FILE.png
   qmp.py SOCKET type TEXT            type plain text (a-z 0-9 - . space)
   qmp.py SOCKET key KEY[+KEY...]     press a key or a combination, e.g. meta_l, alt+f2, ret
   qmp.py SOCKET quit"""
import json, socket, sys, time
sock, cmd = sys.argv[1], sys.argv[2]
s = socket.socket(socket.AF_UNIX)
s.settimeout(20)
s.connect(sock)
f = s.makefile("rw")
f.readline()
def send(obj):
    f.write(json.dumps(obj) + "\n"); f.flush()
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r:
            return r
def press(keys):
    return send({"execute": "send-key", "arguments": {"keys": [{"type": "qcode", "data": k} for k in keys], "hold-time": 60}})
NAMES = {"-": "minus", ".": "dot", " ": "spc", "/": "slash", "_": ["shift", "minus"]}
send({"execute": "qmp_capabilities"})
if cmd == "screendump":
    print(send({"execute": "screendump", "arguments": {"filename": sys.argv[3], "format": "png"}}))
elif cmd == "type":
    for ch in sys.argv[3]:
        k = NAMES.get(ch, ch)
        press(k if isinstance(k, list) else [k])
        time.sleep(0.06)
elif cmd == "key":
    print(press(sys.argv[3].split("+")))
elif cmd == "quit":
    print(send({"execute": "quit"}))
