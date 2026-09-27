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

## Bootstrap routing contract for the next implementation

Branch-local design decision at recovery `91020b04e`: use a trailing optional
logical per-column `weekly_profile_mode` array on the exact, next-prefix and
window adapter entry points. Absence or false retains the supplied-deficit route,
even when a profile array happens to be supplied for other columns. Do not add
a selector to the daily identity/value carrier or infer routing from allocation.

Validate mask shape before snapshot export; a true entry requires timing 6 and
the profile container with matching column count. Missing containers reject
before runtime publication. Leave profile payload validation to the named source
route so pending events and duplicate ordinals still bypass fresh derivation.
Derive only from the exported committed hydraulic snapshot and forward the
existing detached event/weekly proposals to the existing publisher. No new
state owner, restart field, tolerance change or calendar inference is permitted.

Qualification must cover mixed supplied/profile columns, omitted versus false
mask preservation, missing/wrong-sized containers, nonweekly true entries,
invalid second-column payload with no publication, split retry and pending
decoded restart. This contract is not evidence of implemented bootstrap routing.

## Implemented branch-local routing and restart boundary

The routing contract above was implemented at `034870dd7`. Later evidence in
the status JSON qualifies mixed supplied-DCS1/profile-DCS2 exact execution,
new-selection window execution, pending next-prefix split completion and
pending window replay. The profile-selected input can contain a nonfinite
supplied deficit because the named route replaces it with the checked derived
value; a false mask does not perform that replacement.

Persistence scope review: `src/runtime/mod_fmr_committed_restart.f90` explicitly
defines an adapter-facing, serialization-neutral decoded continuation record,
not a byte-level file format. The tested bundle export/restore uses that decoded
record contract. Earlier next-step references to a required external codec do
not establish an additional migration requirement for this bounded route.
No disk serialization or production restart registration is claimed here.

Tested postimage `a99c037d9` additionally covers profile-derived DCS1 runtime
amounts and fresh-selection two-prefix windows through gift completion and a
zero-source remainder. Both columns commit with unchanged mass tolerances and
without duplicate counting. Remaining work includes successor invocation with
changed explicit profiles and broader daily execution. Full-day numerical
completion remains separately unresolved. These additions must not weaken
existing publication or mass checks.
