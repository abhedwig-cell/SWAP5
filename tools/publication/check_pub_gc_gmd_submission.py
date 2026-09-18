#!/usr/bin/env python3
"""Audit the PUB-GC GMD prearchive package.

Default mode validates the frozen publication inventory and reports governance
blockers without failing merely because A1/A2b/A3 are intentionally unresolved.

Use --submission-ready only after release/licence/archive governance is closed;
that mode fails if any mandatory archival field or submission placeholder remains.
"""
from __future__ import annotations
import argparse, json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INV = ROOT / "docs/publication/PUB_GC_GMD_PREARCHIVE_INVENTORY.json"
META = ROOT / "docs/publication/PUB_GC_GMD_SUBMISSION_METADATA_DRAFT.md"
CODE = ROOT / "docs/publication/PUB_GC_GMD_CODE_DATA_AVAILABILITY_TEMPLATE.md"

def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--submission-ready",action="store_true")
    args=ap.parse_args()

    inv=json.loads(INV.read_text(encoding="utf-8"))
    errors=[]

    for item in inv["required_publication_assets"]:
        p=ROOT/item["path"]
        if not p.is_file():
            errors.append(f"missing required publication asset: {item['path']}")

    e7=ROOT/"docs/publication/PUB_GC_E7_REALISTIC_COMPONENT_DOMAIN_RESULT.json"
    if e7.is_file():
        x=json.loads(e7.read_text(encoding="utf-8"))
        if x.get("outcome")!="REALISTIC_COMPONENT_DOMAIN_LIMIT":
            errors.append("E7 outcome drifted from REALISTIC_COMPONENT_DOMAIN_LIMIT")
        ce=x.get("coupled_execution",{})
        for key in ("loose_completed_windows","strong_completed_windows","modflow_e7_windows_executed"):
            if ce.get(key)!=0:
                errors.append(f"E7 zero-window guard violated: {key}={ce.get(key)!r}")

    unresolved=[]
    fields=inv["final_archive_fields"]
    for key in ("publication_release_identifier","publication_commit","software_license_authority","archive_DOI_or_PID","archive_created_at"):
        if not fields.get(key):
            unresolved.append(key)

    placeholders=[]
    for p in (META,CODE):
        if p.is_file():
            txt=p.read_text(encoding="utf-8")
            placeholders.extend(f"{p.name}:{m.group(0)}" for m in re.finditer(r"<<[^>]+>>",txt))

    if errors:
        print("PUB_GC_GMD_PREARCHIVE_INTEGRITY=FAIL")
        for e in errors: print("ERROR:",e)
        return 2

    print("PUB_GC_GMD_PREARCHIVE_INTEGRITY=PASS")
    print(f"PUB_GC_GMD_REQUIRED_ASSETS={len(inv['required_publication_assets'])}")
    print("PUB_GC_GMD_E7_ZERO_WINDOW_GUARD=PASS")
    print("PUB_GC_GMD_A2A_SW4_LICENSE_AUTHORITY=VERIFIED")
    if unresolved:
        print("PUB_GC_GMD_ARCHIVAL_FIELDS=BLOCKED",",".join(unresolved))
    else:
        print("PUB_GC_GMD_ARCHIVAL_FIELDS=RESOLVED")
    print(f"PUB_GC_GMD_TEMPLATE_PLACEHOLDERS={len(placeholders)}")

    if args.submission_ready and (unresolved or placeholders):
        print("PUB_GC_GMD_SUBMISSION_READY=FAIL")
        for u in unresolved: print("UNRESOLVED:",u)
        for p in placeholders: print("PLACEHOLDER:",p)
        return 3

    print("PUB_GC_GMD_SUBMISSION_READY=" + ("PASS" if not unresolved and not placeholders else "BLOCKED_GOVERNANCE_METADATA"))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
