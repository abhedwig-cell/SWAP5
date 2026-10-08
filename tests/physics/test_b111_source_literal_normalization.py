#!/usr/bin/env python3
"""Focused lexical regression for byte-pinned B1.11 source matching."""
import ast
from pathlib import Path

root=Path(__file__).resolve().parents[2]
path=root/"tools/audits/probe_b111_nut_sol_exact_source.py"
module=ast.parse(path.read_text())
fn=next(node for node in module.body if isinstance(node,ast.FunctionDef)
        and node.name=="normalize_fortran_d_literals")
scope={"re": __import__("re")}
exec(compile(ast.Module(body=[fn],type_ignores=[]),str(path),"exec"),scope)
normalize=scope["normalize_fortran_d_literals"]
cases={
    "1.0d0":"1.d0",
    "1.00d0":"1.d0",
    "0.26d0":"0.26d0",
    "41.9d0":"41.9d0",
    "0.d-3":"0.d-3",
    "foo1.0d0":"foo1.0d0",
    "-1.0d0":"-1.d0",
}
for raw, expected in cases.items():
    actual=normalize(raw)
    if actual!=expected:
        raise SystemExit(f"literal normalization mismatch {raw}: {actual}, wanted {expected}")
print("B111_SOURCE_LITERAL_NORMALIZATION_PASS 7/7")
