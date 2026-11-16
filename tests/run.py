import os
import sys
import lupa.lua51 as lupa

here = os.path.dirname(os.path.abspath(__file__))
addon = sys.argv[1]
failed = False

# Syntax check every addon file on its own first.
for name in sorted(os.listdir(addon)):
    if name.endswith(".lua"):
        lua = lupa.LuaRuntime()
        src = open(os.path.join(addon, name), encoding="utf-8").read()
        ok, err = lua.eval("function(s, n) local f, e = loadstring(s, n); return f ~= nil, e end")(src, name)
        if not ok:
            print("SYNTAX", name, err)
            failed = True

for scenario in ["forever", "retail", "saved", "pinned", "long"]:
    lua = lupa.LuaRuntime()
    g = lua.globals()
    g.TEST_DIR = here
    g.ADDON_DIR = addon
    g.SCENARIO = scenario
    output = []
    g.print = lambda *args: output.append(" ".join(str(a) for a in args))
    try:
        lua.execute(open(os.path.join(here, "tests.lua"), encoding="utf-8").read())
    except Exception as exc:
        print("ERROR", scenario, exc)
        failed = True
    for line in output:
        if line.startswith("FAIL") or line.startswith("RESULT"):
            print(line)
        if line.startswith("FAIL") or (line.startswith("RESULT") and "failed=0" not in line):
            failed = True

sys.exit(1 if failed else 0)
