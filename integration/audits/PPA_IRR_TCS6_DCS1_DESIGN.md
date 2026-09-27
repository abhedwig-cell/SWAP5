# TCS6 with supplied-deficit DCS1

Branch-local supplied-deficit process and bounded runtime qualification;
not canonical admission. Current evidence is in `PPA_IRR_TCS6_COMPOSITION_STATUS.json`.
Baseline `b4ff0bf3c`. Owning counter/publication contract remains
`PPA_IRR_TCS6_OWNER_DESIGN.md`.

Release `SWAP/irrigation.f90` lines 519-531 select the weekly event using cdef;
lines 567-576 compute DCS1 depth from the same cdef, correction table and strict
rainfall threshold. The release member was reread from the supplied nested ZIP.
TCSFIX, solute overirrigation and alternate delivery remain excluded.

Extend the existing pure weekly composition to accept DCS1 as well as DCS2.
For DCS1, copy the request and bind its deficit from the explicit weekly deficit
argument so timing and amount cannot use inconsistent deficits. Reuse the
existing depth calculation, limits, event splitting and pending-event handling.
No state owner, publication, tolerance or default policy changes. Failed/split
proposals retain the original counter. Qualification first covers independent
amount arithmetic; profile derivation and daily runtime admission remain separate.

## Explicit bootstrap extension

The weekly route may now accept DCS1 without a root-profile argument because
`weekly_inputs` explicitly supplies the common deficit for timing and depth.
This is not inferred deficit derivation. Other DCS1 routes retain their profile
requirements. Existing shape, ordinal, committed-snapshot and publication checks
remain unchanged. The two-column weekly gift fixture uses DCS1 in column 1 and
DCS2 in column 2 with equal independently specified depth, exercising existing
split, prefix, budget, pending and restart paths without a second owner.

## Qualified boundary

Process evidence covers independent correction/rainfall arithmetic, common deficit,
limits, invalid-input and zero-depth rejection, split retry, pending completion,
duplicate/successor/gap ordinals. Runtime postimage `41178cb8e` passes the full
IrrigationSource O0/O2 exact gate, including mixed DCS1/DCS2 gift execution,
prefix budgets and decoded restart. Missing weekly input, nonfinite first-column
deficit and invalid second-column ordinal reject without any column publication.
Evidence checkpoint: `12f375739`. These are bounded short hydraulic fixtures,
not full-day weekly DCS1 execution or disk persistence.

## Next capability: profile-derived weekly deficit (proposed)

Keep the explicit supplied-deficit API intact. A separately named profile route
should derive cdef with the existing checked root-zone deficit helper using the
same committed water snapshot as the irrigation event. Reuse existing profile
geometry and water-capacity contracts; do not infer crop/root evolution.
Pass that single derived cdef to both weekly timing and DCS1 depth (or weekly
timing with DCS2). Derivation is needed only for a new eligible daily selection;
pending events and duplicate ordinals must not depend on fresh profile validity.
Invalid profiles must expose neither forcing nor advanced weekly metadata.
First qualify source-level arithmetic and bypass/rollback behavior, then add
explicit bootstrap routing with mixed-column preflight and restart tests.
This paragraph is a work plan, not implementation or qualification evidence.
