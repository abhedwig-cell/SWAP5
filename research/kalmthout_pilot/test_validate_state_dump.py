#!/usr/bin/env python3
"""Focused parser smoke tests; no Fortran execution or network needed."""
import pathlib
import subprocess
import sys
import tempfile

validator = pathlib.Path(__file__).with_name("validate_state_dump.py")

def run(lines):
    with tempfile.TemporaryDirectory() as d:
        p=pathlib.Path(d)/"diagnostic.log"
        p.write_text(lines)
        return subprocess.run([sys.executable,str(validator),str(p)],capture_output=True,text=True)

header="KALMTHOUT_STATE_HEADER 2024-03-09T13:00 2 8.4762712060012352E-004 -2.0000000000000000E+000 1.6670095100000000E-001\n"
node1="KALMTHOUT_STATE_NODE 2024-03-09T13:00 1 -5.0000000000000000E-001 1.0000000000000000E+000 1.0008476271206002E+000 4.2300000000000000E-001\n"
node2="KALMTHOUT_STATE_NODE 2024-03-09T13:00 2 -1.5000000000000000E+000 1.0000000000000000E+000 -5.0000000000000000E+001 2.0000000000000000E-001\n"
assert run(header+node1+node2).returncode==0, "complete vector rejected"
assert run(header+node1).returncode!=0, "missing node accepted"
assert run(header+node1+node1).returncode!=0, "duplicate node accepted"
assert run(header+node1+node2.replace("2.0000000000000000E-001","1.2000000000000000E+000")).returncode!=0,"invalid theta accepted"
assert run(node1+node2).returncode!=0, "missing header accepted"
print("KALMTHOUT_STATE_DUMP_PARSER_TEST=PASS (5 cases)")
