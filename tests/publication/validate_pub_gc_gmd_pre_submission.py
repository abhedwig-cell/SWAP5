#!/usr/bin/env python3
from pathlib import Path
import json, re
ROOT=Path(__file__).resolve().parents[2]
PUB=ROOT/"docs/publication"
man=(PUB/"PUB_GC_COUPLE_MANUSCRIPT_DRAFT.md").read_text()
meta=(PUB/"PUB_GC_GMD_SUBMISSION_METADATA_DRAFT.md").read_text()
plan=json.loads((PUB/"PUB_GC_GMD_FIGURE_EXPORT_PLAN.json").read_text())
m=re.search(r"Current candidate, below the 500-character GMD limit:\n\n> ([^\n]+)",meta)
assert m, "short summary missing"
summary=m.group(1)
assert len(summary)<=500, len(summary)
assert "# 7. Code and data availability" in man
abstract=man[man.index("## Abstract"):man.index("# 1. Introduction")]
assert not re.search(r"\([A-Z][^)]*,\s*20\d\d\)",abstract), "abstract contains citation-like author-year text"
assert len(plan["figures"])==7
for i,item in enumerate(plan["figures"],1):
    assert item["target"]==f"f{i:02d}.pdf"
    assert (ROOT/item["source"]).exists(), item["source"]
assert plan["upload_rule"]["svg_direct_upload"] is False
assert plan["upload_rule"]["max_individual_figure_mb"]==5
assert "REALISTIC_COMPONENT_DOMAIN_LIMIT" in (PUB/"PUB_GC_SUBMISSION_READINESS.md").read_text()
print(f"PUB_GC_GMD_SHORT_SUMMARY_CHARS={len(summary)}")
print("PUB_GC_GMD_MANUSCRIPT_AVAILABILITY_HEADING=PASS")
print("PUB_GC_GMD_FIGURE_EXPORT_PLAN=PASS")
print("PUB_GC_GMD_PRE_SUBMISSION_STATIC_GATE=PASS")
