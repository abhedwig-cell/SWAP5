# MIGMAC01 confirmed B1.11 perched-classification defect
Date: 2026-10-02
Status: CONFIRMED_REFERENCE_DEFECT_NOT_A_PERCH21_REGRESSION
Owning evidence branch: research/ppa-wu05-migmac01-covering-layer

The fixed modified-Andelst event was rerun with an additional read-only hook at
MACRORATE aggregate completion, before its ITask=1 return. No physical source
statement, input, dt, tolerance or selection rule changed. The same first event,
covering head and covered receipt were recovered. Exact B1.11 source remains
manifest-verified; separately identified selected-source instrumentation is
recorded in the machine checks. The original source event remains evidence of
covered-operator activation, but its whole-case exchange is not a suitable
uncorrected physics target for MIGMAC01 admission.

At the actual last rate evaluation:
- ordinary matrix top / nodgwl / nodgwlflcpzo = 55;
- B1.11 perched top = 55, bottom = 55;
- ordinary gwl and perched gwl both = -75.233469634536689 cm;
- h(54)=-1.2419233129262046 cm and h(55)=+0.8510135494351094 cm;
- distinct positive-head intervals are 1–2, 15–28 and 55–112;
- CRITUNDSATVOL=0.1 cm, unchanged from official input.

Source CALCGWL starts its perched search at min(nodgwl,numnod).
Here that is saturated node 55, inside the ordinary groundwater zone.
It immediately selects that ordinary node, constructs a spurious one-node
perched carrier, and misses the detached shallow saturated water above nodes
29–54. MACRORATE then calls SATFLOW for both this false perched carrier and
the ordinary zone, so ordinary node 55 is counted twice.

The migrated carrier, evaluated on those exact last-rate h/theta and gwl values,
has main top 55 and perched top 1 / bottom 29 with the unchanged 0.1-cm air-volume
criterion. The tiny maximum last-rate/accepted-head lag is only
0.00013091323540594113 cm. Thus the large discrepancy is not explained by
evaluating a materially different head state.

A read-only process ablation was used solely to attribute the difference:
disable perched detection in a copied probe template, evaluate the frozen source
last-rate state, then restore the active probe before the actual runtime replay.
The immutable original rate template and production replay retain perched
physics throughout. The ablation is not an admission fixture or a proposed fix.

Ablation other exchange = -0.39139067582795939 cm/day; reference =
-0.40973640650434007 cm/day. Maximum remaining difference is at node 55:
probe -0.018345730676406151, reference -0.036691461352812302 cm/day.
The exact factor of two confirms the false perched/ordinary duplicate.
This isolates the large missing shallow exchange and the reference duplicate;
it does not claim every coupled solver difference is explained or repaired.

Local O0/O2 repeat the carrier and ablation findings and the unchanged negative
full-runtime outcome. Source operator still has exact opposite matrix sink.
Full runtime still requests retry with a dry tentative covering head.
No tolerance was relaxed and no positive result was obtained by disabling a
process in the real replay.

Repository authority: docs/verification/principles.md defines B0 -> corrected
B1 -> B2 and states that confirmed legacy bugs must be corrected and qualified
in the B1 line before requiring SWAP5 to reproduce corrected behavior.
PERCH21 is already canonically admitted and closed by its result authority.
Reintroducing this reference defect into PERCH21 would be the wrong repair.

Next scientific prerequisite: preregister and qualify an explicitly identified
B1 correction that begins the perched search ABOVE the ordinary saturated zone,
including cases where the water-table-containing cell itself is unsaturated,
whole-column saturation, no ordinary groundwater, multiple shallow wet islands,
and positive covered-top forcing. Preserve exact B1.11 as immutable authority;
do not relabel an unqualified diagnostic patch as B1.12 or admitted reference.
Then recapture a source-backed active state under that qualified correction and
continue MIGMAC01 on the same no-tuning and mass-ownership rules.

Independent explicit matrix-area and serialized covering-parameter integration
gaps remain. There is no production-admission candidate or canonical closeout.
Frozen Status-A denominator and M2 scope are unchanged.
