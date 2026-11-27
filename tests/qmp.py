#!/usr/bin/env python3
"""Tiny QMP client: qmp.py SOCKET screendump FILE.png | qmp.py SOCKET quit"""
import json, socket, sys
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
send({"execute": "qmp_capabilities"})
if cmd == "screendump":
    print(send({"execute": "screendump", "arguments": {"filename": sys.argv[3], "format": "png"}}))
elif cmd == "quit":
    print(send({"execute": "quit"}))
