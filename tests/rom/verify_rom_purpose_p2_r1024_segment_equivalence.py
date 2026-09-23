#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib

NSTEPS=32768
NPROFILES=16384


def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalize_state(line:str)->str:
    parts=line.rstrip("\n").split("|")
    kept=[parts[0]]
    for item in parts[1:]:
        if item.startswith("REV="):
            continue
        kept.append(item)
    return "|".join(kept)


def scientific_lines(path:pathlib.Path)->list[str]:
    out=[]
    for line in path.read_text(errors="strict").splitlines():
        if line.startswith("LAREDYN0R_STATE|"):
            out.append(normalize_state(line))
        elif line.startswith("LAREDYN0R_PROFILE|"):
            out.append(line)
    return out


def counts(lines:list[str])->dict[str,int]:
    return {
        "state":sum(x.startswith("LAREDYN0R_STATE|") for x in lines),
        "profile":sum(x.startswith("LAREDYN0R_PROFILE|") for x in lines),
    }


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--full-o0",required=True,type=pathlib.Path)
    ap.add_argument("--full-o2",required=True,type=pathlib.Path)
    ap.add_argument("--segments",required=True,type=pathlib.Path,nargs=4)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    # The original full route itself must already satisfy the frozen O0/O2
    # identity requirement. This is raw byte identity, not normalized identity.
    if a.full_o0.read_bytes()!=a.full_o2.read_bytes():
        raise SystemExit("full S06 O0/O2 byte identity failed")

    full=scientific_lines(a.full_o0)
    seg=[]
    for p in a.segments:
        seg.extend(scientific_lines(p))

    fc=counts(full); sc=counts(seg)
    if fc!={"state":NSTEPS,"profile":NPROFILES}:
        raise SystemExit(f"unexpected full scientific coverage {fc}")
    if sc!=fc:
        raise SystemExit(f"segmented scientific coverage {sc} != {fc}")

    exact=(full==seg)
    mismatch=None
    if not exact:
        for i,(x,y) in enumerate(zip(full,seg),start=1):
            if x!=y:
                mismatch={"scientific_line":i,"full":x,"segmented":y}
                break
        if mismatch is None and len(full)!=len(seg):
            mismatch={"scientific_line":min(len(full),len(seg))+1,
                      "full_length":len(full),"segmented_length":len(seg)}

    out={
        "schema":"swap5.rom-purpose.p2.r1024-segment-equivalence.v1",
        "workstream":"ROM-PURPOSE",
        "work_unit":"ROM-PURPOSE-P2-REFERENCE",
        "witness_case":"B01/R1024_T32/S06",
        "full_o0_sha256":sha256(a.full_o0),
        "full_o2_sha256":sha256(a.full_o2),
        "segment_sha256":[sha256(p) for p in a.segments],
        "scientific_line_counts":fc,
        "ignored_nonhydrologic_field":["REV"],
        "reason_REV_ignored":"Revision counters are local restart bookkeeping and were already excluded from hydrologic checkpoint authority.",
        "all_other_STATE_fields_exact":exact,
        "PROFILE_lines_exact":exact,
        "full_O0_O2_raw_byte_identity":True,
        "segmented_matches_full_scientific_output_exactly":exact,
        "mismatch":mismatch,
        "qualified":exact,
        "scientific_change":False
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"qualified":exact,"counts":fc,"mismatch":mismatch},sort_keys=True))
    return 0 if exact else 3


if __name__=="__main__":
    raise SystemExit(main())
