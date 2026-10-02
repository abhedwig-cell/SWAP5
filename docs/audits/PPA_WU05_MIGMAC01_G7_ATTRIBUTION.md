# PPA-WU05-MIGMAC01 G7 state-identity attribution

Date: 2026-10-02
Status: ATTRIBUTED_CAPTURE_INCOMPLETENESS_NOT_OPERATOR_FALSIFICATION
Owning head before persistence: 1d6d5029fab0296c7384a34935dd62cbe2d69358
Canonical observed: 800f6a9b429ed2a392e4c3778951bb92eca042aa

## Question

G7 compared the corrected B1.11 last nonlinear macropore exchange vector with a
SWAP5 re-evaluation and found a maximum node difference of
9.1392659217592875e-4 cm/day and an OTHER-sum difference of about
1.9425e-3 cm/day.

The question is whether this is evidence of a remaining operator mismatch.

## Audit

The persisted last-rate file contains only:

- time and dt;
- ordinary and perched zone indices and groundwater levels;
- matrix pressure head per node;
- matrix water content per node;
- B1.11 QExcMpMtx per node.

It does not contain the macropore state at that last rate evaluation:
dynamic volume, domain water, domain volume, sorptivity,
theta-sorption reference, absorption time, or the other mutable standard
macropore carrier fields are absent.

The current diagnostic constructs the SWAP5 provider from the ORIGIN/accepted
macropore carrier and then evaluates it at the persisted last-rate matrix
h/theta. Therefore G7 is not a same-state operator comparison.

This is independently consistent with the already documented B1.11 iteration
lag: last-rate h(2)=0.0096182734785161973 cm while final accepted h(2) is
0.00068230903875077459 cm. The reference result explicitly states that the
legacy converged receipt is evaluated on the last nonlinear rate, not exactly
on the final accepted head.

## Classification

G7 is reclassified from an unexplained production-operator discrepancy to an
incomplete-reference-carrier attribution.

The existing numerical difference remains recorded as negative/non-parity
evidence. It is not relabelled PASS and no tolerance is widened.

It is not valid to use this comparison as a production-admission blocker for
the operator because state identity cannot be established from the persisted
reference artifact.

A strict last-rate parity claim would require a new deterministic B1.11 capture
that persists the complete mutable macropore carrier at the exact QExcMpMtx
evaluation. The repository does not currently contain that carrier in the
last-rate artifact.

## Evidence that does remain state-complete

The frozen source-backed SWAP5 route now provides stronger migration evidence:

- exact source matrix-area ownership is explicit;
- immutable covering parameters are explicit;
- positive covered matrix-to-macropore transfer occurs;
- direct Reference Richards converges without tolerance or dt changes;
- serialized source transaction completes with mass residual about 1.0e-16 cm;
- discard/replay, commit publication and persistence/restart pass;
- O0/O2 pass;
- A9, A10 and PERCH20 transaction/restart preservation pass on the qualified
  postimage.

These results qualify the migrated source-backed behavior but do not constitute
bitwise B1.11 last-rate parity.

## Governance consequence

G7 exact last-rate parity: NOT PROVEN
G7 operator mismatch: NOT ESTABLISHED
G7 admission blocker: RESOLVED BY ATTRIBUTION
Remaining requirement before production-admission candidate:
review the complete postimage against the migration contract and confirm that
no other open blocker is hidden in stale status fields. Do not claim canonical
admission before the canonical integration step.
