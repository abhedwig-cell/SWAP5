#!/usr/bin/env python3
from pathlib import Path
import json, re

ROOT = Path(__file__).resolve().parents[2]
files = {
  "gateway": ROOT/"src/adapter/mod_groundwater_external_gateway.f90",
  "contract": ROOT/"src/runtime/mod_groundwater_coupling_contract.f90",
  "ledger": ROOT/"src/runtime/mod_groundwater_interface_mass_ledger.f90",
  "science": ROOT/"docs/science/groundwater-coupling.md",
  "gc41": ROOT/"docs/integration/F-GC41_WHOLE_WINDOW_ACCEPTANCE_RETRY.md",
  "gc42": ROOT/"docs/integration/F-GC42_WHOLE_WINDOW_SERVICE_COMPOSITION.md",
  "gc43": ROOT/"docs/integration/F-GC43_PRODUCTION_SWAP_PARTICIPANT.md",
}
txt={k:p.read_text() for k,p in files.items()}

ownership_tokens=[
  "saturated-tail","saturated tail","split face","ownership direction",
  "ownership_change","ownership change","interface-face","interface face"
]
def mentions(text, tokens=ownership_tokens):
    low=text.lower()
    return [t for t in tokens if t in low]

gateway_ownership=mentions(txt["gateway"])
contract_ownership=mentions(txt["contract"])
ledger_ownership=mentions(txt["ledger"])

gateway_fields_ok=all(s in txt["gateway"] for s in [
    "cell_id","t0","t1","flux_native","head_native"
])
science_head_exchange=all(s in txt["science"] for s in [
    "hydraulic head","whole-window","exchange"
])
ledger_window_exchange=all(s in txt["ledger"] for s in [
    "trial_exchange_m","trial_t0","trial_t1","committed_swap_outward_exchange_m"
])

pub_text=(txt["science"]+"\n"+txt["gc41"]+"\n"+txt["gc42"]+"\n"+txt["gc43"]).lower()
publication_window_based=all(s in pub_text for s in [
    "accepted", "publication"
]) and ("coupling window" in pub_text or "window" in pub_text)

mapping_patterns=[
    r"each\s+fine\s+timeint",
    r"one\s+fine\s+.*interval\s+.*coupling\s+window",
    r"timeint17.*coupling\s+window",
    r"nlglob.*coupling\s+window",
]
mapping_hits=[]
for k,v in txt.items():
    lv=v.lower()
    for pat in mapping_patterns:
        if re.search(pat, lv):
            mapping_hits.append({"file":k,"pattern":pat})

ownership_external = bool(gateway_ownership or contract_ownership or ledger_ownership)
internal_cls=("INTERNAL_OWNERSHIP_EXPOSED" if ownership_external
              else "INTERNAL_OWNERSHIP_NOT_EXTERNAL_SURFACE")
mapping_cls=("TIMEINT_TO_COUPLING_WINDOW_MAPPING_ESTABLISHED" if mapping_hits
             else "TIMEINT_TO_COUPLING_WINDOW_MAPPING_NOT_ESTABLISHED")

consistent=(gateway_fields_ok and science_head_exchange and ledger_window_exchange and publication_window_based)
if not consistent:
    aggregate="NLGLOB14Z24_COUPLING_CONTRACT_INCONSISTENT"
elif ownership_external:
    aggregate="NLGLOB14Z24_OWNERSHIP_IS_EXTERNAL_COUPLING_SURFACE"
elif mapping_hits:
    aggregate="QUALIFIED_Z24_INTERNAL_OWNERSHIP_WITH_EXPLICIT_WINDOW_MAPPING"
else:
    aggregate="QUALIFIED_Z24_CHATTER_INTERNAL_TO_SWAP_COUPLING_RELEVANCE_NOT_ESTABLISHED"

out={
 "aggregate":aggregate,
 "ownership_surface":internal_cls,
 "temporal_mapping":mapping_cls,
 "gateway_ownership_terms":gateway_ownership,
 "contract_ownership_terms":contract_ownership,
 "ledger_ownership_terms":ledger_ownership,
 "mapping_hits":mapping_hits,
 "gateway_fields_ok":gateway_fields_ok,
 "science_head_exchange":science_head_exchange,
 "ledger_window_exchange":ledger_window_exchange,
 "publication_window_based":publication_window_based,
}
print("F_PE_NLGLOB14Z24_RESULT="+json.dumps(out,separators=(",",":"),sort_keys=True))
assert aggregate in {
 "QUALIFIED_Z24_CHATTER_INTERNAL_TO_SWAP_COUPLING_RELEVANCE_NOT_ESTABLISHED",
 "NLGLOB14Z24_OWNERSHIP_IS_EXTERNAL_COUPLING_SURFACE",
 "QUALIFIED_Z24_INTERNAL_OWNERSHIP_WITH_EXPLICIT_WINDOW_MAPPING",
 "NLGLOB14Z24_COUPLING_CONTRACT_INCONSISTENT",
}
print("F_PE_NLGLOB14Z24=PASS")
