# Original CDE output with the mixed aquifer owner

**Proposed / implementation in progress; not admitted.** Baseline is actual
canonical76c6251a2f3f6345428b26b1a9e03cf7e0bf917a after PR1727/1728. The actual
source and metadata merge postimages pass their detached registered owner.
Historical closure remains PARTIAL, whole science NOT_QUALIFIED, fixed RC3
unchanged. This work changes output composition, not aquifer equations.

## Reconciled owning interfaces

`conserved_aquifer_solute.py` and its original source correction already own
the seven-field mixed reservoir state, loss-limited step policy and unchanged
1e-10mg/cm2 reservoir/exchange/soil-plus-reservoir guards. The actual aquifer
native call follows the existing conserved CDE stock prefix. Existing whole
model differences from the corrected original remain unresolved; output work
must not claim to settle them.

The admitted original-output helpers explicitly reject SWBR1. Their CDE daily
probe emits soil and uptake observations but does not emit the required seven
aquifer observations. Consequently, removing the selector refusal alone is
insufficient. The complete existing reservoir, physical irrigation/history,
calendar and original private CDE output state must remain owned and restored.

## Bounded composition contract

Extend the existing explicit `--original-output` route only for analytical
no-macro SWSOLU1/SWBR1/SWDRA1, daily interval reset cadence, original adaptive
day-seed policy and SWHYST0/1/2. Snow, frost and detailed weather remain excluded.
Reuse literal output/calendar/clock/receipt providers and the existing seventeen
scalar plus active IMQSOL private CDE output owner. Add a metadata-only actual
process-domain witness and a distinct typed native codec. Preserve the complete
existing aquifer native payload and the48byte conserved CDE prefix offset.

The daily probe must call the real existing aquifer observer. It must not
reconstruct reservoir state from CSV, alter physical source or concentration,
create a second physical owner or adjust a balance tolerance. Existing routes
delegate to their literal admitted owners when this composition is inactive.

Affected invariants:3,4,7,13,21,23,30. Before admission require local O0/O2 actual
output/source/native pilots; soil-transfer, initial release, sorption/decay and
active loss-limited profiles; formats0..3 and representative groups/precision;
first/terminal/year/source windows; malformed actual native/domain refusals;
external discard/replay/accept/recovery; independent public run/restart;
Windows/Ubuntu full qualification and exact existing-route preservation.
Persist the prototype before compilation. Canonical admission requires its
actual merge parents, complete qualified tree and detached registered owner.
