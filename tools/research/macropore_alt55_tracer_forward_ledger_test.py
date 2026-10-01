#!/usr/bin/env python3
from pathlib import Path
import importlib.util

P=Path(__file__).with_name("macropore_alt55_tracer_forward_ledger.py")
spec=importlib.util.spec_from_file_location("alt55",P)
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

r=m.demonstration()
assert abs(r["ledger"]["residual"]) < 1e-12
assert abs(sum(r["ic_profile"])-r["ledger"]["ic_source"]) < 1e-12

try:
    m.route(1.0,0.4,0.1,0.25,[i/10 for i in range(11)],
            [0.5]+[0.0]*9,[0.0]*10,0.04)
except ValueError as exc:
    assert "matrix profile" in str(exc)
else:
    raise AssertionError("matrix mass leak not rejected")

print("PASS F-MACRO-ALT55 tracer forward-ledger contract")
