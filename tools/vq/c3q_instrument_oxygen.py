#!/usr/bin/env python3
"""Fail-closed diagnostic instrumentation for exact B1.5p1 oxygenstress.f90.

The transformation is intentionally narrow. It adds only diagnostic declarations and a CSV write.
It refuses any source whose SHA is not the pinned corrected B1.5p1 oxygenstress identity.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

SOURCE_SHA256 = "8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87"
BEGIN = b"! C3Q_TRACE_BEGIN\r\n"
END = b"! C3Q_TRACE_END\r\n"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def replace_once(data: bytes, old: bytes, new: bytes, label: str) -> bytes:
    n = data.count(old)
    if n != 1:
        raise ValueError(f"{label}: expected one anchor, found {n}")
    return data.replace(old, new, 1)


def instrument(source: bytes) -> bytes:
    if sha(source) != SOURCE_SHA256:
        raise ValueError(f"source identity mismatch: {sha(source)}")

    decl_anchor = b"      real(8) top1,top2\r\n"
    decl = decl_anchor + BEGIN + (
        b"      integer, save :: c3q_trace_unit = -1\r\n"
        b"      integer, save :: c3q_call_index = 0\r\n"
        b"      logical, save :: c3q_trace_header = .false.\r\n"
    ) + END
    out = replace_once(source, decl_anchor, decl, "declaration")

    # Anchor immediately after the legacy lower clamp of rwu_factor. This records the final
    # physical response for the node, including the max_resp_factor==1 special case.
    write_anchor = b"          if (rwu_factor.lt.0.0d0) rwu_factor=0.0d0\r\n"
    write_block = write_anchor + BEGIN + (
        b"          if (c3q_trace_unit < 0) then\r\n"
        b"             open(newunit=c3q_trace_unit,file='c3q_oxygen_trace.csv',status='replace',action='write')\r\n"
        b"          end if\r\n"
        b"          if (.not.c3q_trace_header) then\r\n"
        b"             write(c3q_trace_unit,'(a)') 'call_index,node,matric_potential_pa,theta,gas_filled_porosity,soil_temp_k,max_resp_factor,waterfilm_thickness_m,d_soil,r_microbial_z0,ctopnode,c_macro,c_min_micro,resp_factor,rwu_factor'\r\n"
        b"             c3q_trace_header = .true.\r\n"
        b"          end if\r\n"
        b"          c3q_call_index = c3q_call_index + 1\r\n"
        b"          write(c3q_trace_unit,'(i0,\",\",i0,13(\",\",es25.16e3))') c3q_call_index,node,matric_potential,theta0,gas_filled_porosity,soil_temp,max_resp_factor,waterfilm_thickness,d_soil,r_microbial_z0,ctopnode,c_macro,c_min_micro,resp_factor,rwu_factor\r\n"
        b"          flush(c3q_trace_unit)\r\n"
    ) + END
    out = replace_once(out, write_anchor, write_block, "final-response")
    return out


def strip_trace(data: bytes) -> bytes:
    while BEGIN in data:
        start = data.index(BEGIN)
        stop = data.index(END, start) + len(END)
        data = data[:start] + data[stop:]
    return data


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    original = args.source.read_bytes()
    traced = instrument(original)
    if strip_trace(traced) != original:
        raise SystemExit("C3Q instrumentation reversibility gate failed")
    args.output.write_bytes(traced)
    print("C3Q_INSTRUMENTATION=PASS")
    print(f"C3Q_ORIGINAL_SHA256={sha(original)}")
    print(f"C3Q_INSTRUMENTED_SHA256={sha(traced)}")
    print("C3Q_STRIP_RESTORES_ORIGINAL=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
