#!/usr/bin/env python3
"""Focused real parser contract tests; no model execution or network."""
from pathlib import Path
import subprocess
import sys
import tempfile

validator = Path(__file__).with_name("validate_backtrack_trace.py")
first = ("KALMTHOUT_BACKTRACK_DECISION 1 1 0 4.1666666666666664E-002 "
         "1.0000000000000000E+000 2.0000000000000000E+000 "
         "3.0000000000000000E+000 9.0000000000000000E-001 "
         "1.0000000000000000E-010 T surface-flux\n")
second = ("KALMTHOUT_BACKTRACK_DECISION 1 2 1 4.1666666666666664E-002 "
          "3.3333333333333331E-001 4.0000000000000000E+000 "
          "3.0000000000000000E+000 9.0000000000000000E-001 "
          "1.0000000000000000E-010 F ponded-head\n")

def parse(txt):
    with tempfile.TemporaryDirectory() as d:
        filename = Path(d) / "trace.log"
        filename.write_text(txt)
        return subprocess.run([sys.executable, str(validator), str(filename)],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE).returncode

assert parse(first + second) == 0, "valid trace rejected"
assert parse(first.replace(" T surface-flux", " F surface-flux") + second) != 0, "incorrect decision accepted"
assert parse("") != 0, "missing trace accepted"
assert parse(first.replace("1.0000000000000000E-010", "NaN")) != 0, "non-finite tolerance accepted"
print("KALMTHOUT_BACKTRACK_PARSER_TEST=PASS (4 cases)")
