# WOFOST81 harvest owner candidate

Run `python -B tests/crop-harvest/run_harvest.py --output <fresh-directory>` with
GNU Fortran available. O0/O2 builds use real production providers, bounds/FP
traps and strict -Werror on the changed PP02 providers. The harvest driver has
43 production providers because it also checks the actual active-only crop/N
serializer and existing residue chemistry. The unchanged repository daily
integration driver has24 providers. Their shared closure is compiled once per
optimization; each driver is linked and executed independently.

The original harvest block in mod_harvest_oracle.f90 is mechanically extracted
from authenticated B1.11 wofostnut.f90. Dead canopy and already processed daily
death are explicitly zero in this profile. It does not recreate historical
retained dead canopy from a cumulative loss ledger. The driver tests125 distinct
fraction combinations, complete per-organ transfers, end-status before reset,
unchanged input, private-record cloning, source calendar/maturity triggers,
invalid inputs, stale/repeated harvest refusal, current serializer refusal and
the current daily-owner refusal. The original B1.11 residue chemistry processes
all four material outputs and closes their N boundary against harvest export.

These are owner candidates, not accepted physical events. No production caller
publishes them yet. An authentic calendar/weather event, joint water/crop/soil-N
publication, exactly-once pending incorporation, observation acknowledgement,
fresh-process native continuation, fallow and new-season initialization remain
open. Native writers must not omit the new private optional record; the old
active-only owner packer refuses harvested values. No physical production or
full-preservation PASS is inferred.

Verify retained source/commands/output and the independent extracted block with
`python -B tests/crop-harvest/verify_evidence.py`. Failed exploratory selections
remain in the evidence capsule with their exact outcomes.
