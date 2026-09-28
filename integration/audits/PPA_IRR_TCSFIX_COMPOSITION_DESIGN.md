# TCSFIX composition: next bounded capability

Proposed branch-local process extension, baseline `1307a90d4`. No implementation,
qualification or production admission is claimed by this design.

## Existing authority and gap

`PPA_IRR_TCSFIX_FILTER_PREREGISTRATION.json` pins the corrected-reference
irrigation member SHA and lines 249-255, 395-400 and 551-562. Its status record
qualifies only an isolated counter filter. The existing pure helper accepts a
candidate only when the interval is satisfied, resets accepted counter to one,
and otherwise increments below the interval. TCS6 plus TCSFIX is forbidden.
Do not reuse the weekly counter carrier for this different counter lifecycle.

## First implementation boundary

Reread the pinned release member before implementation. Compose the existing
TCS1-4 timing helper, TCSFIX post-filter and scheduled DCS2 event materializer in
a separately named pure process API. Counter and interval are explicit inputs;
counter output remains a detached proposal. Existing APIs/defaults stay unchanged.
Evaluate timing, then filter, then depth/event construction. Do not materialize
an event and cancel it afterward: that would introduce spurious splitting and
could validate depth on a branch that should never select an event.

Pending continuation must bypass new timing/filter evaluation. Failed or split
proposals retain the input counter; a successful retry applies its transition
once. Eligibility/daily invocation ordering must be resolved from source before
coding, not inferred from the weekly route. No runtime counter owner is added
in this first slice, and repeated caller invocation is not a calendar guarantee.

## Required evidence

Independent fixtures cover interval-minus-one/equality/above and startup366,
candidate versus no candidate, TCS1-4 timing composition, suppressed gift with
an otherwise split interval, accepted split/retry, pending continuation and
invalid inputs. Replay O0/O2 with exact transcripts and preserve the existing
composition gate. Preregister any shared compile-list change. Owner, daily
identity, restart, profile-derived DCS1, solute and general calendar ingestion
remain separate follow-ups. No mass or solver tolerance may be relaxed.

## Source ordering review completed

At checkpoint `ee7ffb3de`, reread `SWAP/irrigation.f90` directly from the supplied
nested release archive (outer `SWAP_4.3.1.zip`, inner
`SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP`). Lines 451-562 put both timing and
TCSFIX inside scheduled eligibility: irrigation enabled, schedule enabled,
no prior event, emerged crop and open irrigation window. Lines 551-562 apply
the counter filter after timing; depth/rate begins at lines 564-565 only for
the surviving event. Therefore an ineligible request must not increment the
counter. An eligible daily request with no timing candidate does increment it
only while below the configured interval. Pending continuation must not enter
this selection branch.

Implementation decision: add a separate `mod_ppa_irr_tcsfix_composition` module
with a named TCS1-4/DCS2 routine, explicit `daily_invocation`, `dayfix` and
`interval_days` inputs, and `proposed_dayfix` output. Reuse the timing helper,
filter helper and scheduled materializer. Do not add dependencies to the existing
TCS1-4 composition module or modify its widely shared compile lists. Add a
dedicated small runner compiling the new module after its existing dependencies;
replay the existing composition runner independently for preservation.

Initialize proposed counter to input and publish a filtered proposal only after
the materializer returns success. Validate counter and interval at the explicit
API boundary even for bypass calls; bypass applies to observations and new event
selection, not malformed configuration. No invocation identity is persisted by
this pure API. A caller that retries or publishes must own that later lifecycle.

## Next detached source binding

Process implemented at `7b38d9e21`, with expanded guards tested at `82884ace6`.
Add a separately named adapter that calls this process into local proposals,
then the existing water-only source binder. Initialize outward event/counter to
inputs and outward flux empty; publish all three together only when binding
succeeds. An allocatable forcing output must not retain a prior successful value
on failure. Test positive rate, no-gift source, split/retry and a late forcing
boundary rejection after successful process selection. Do not connect this
adapter to bootstrap or persist its counter until a distinct ownership and daily
identity contract is recorded. Reuse existing observation types where possible;
do not change the provider ABI or existing production compile dependencies.

## Daily identity staging contract

Use a distinct TCSFIX metadata type, never the weekly type: enabled, day-bound,
nonnegative explicit ordinal, counter initially366, and interval_days1..366.
Disabled state has strict defaults; an unbound enabled state retains initial
counter366/ordinal0. A first invocation binds its supplied ordinal; duplicate
ordinals suppress evaluation, backward/gapped ordinals reject, and nondaily
continuation retains identity. Check ordered nonnegative subtraction to avoid
overflow. Interval is immutable across this initial lifecycle; reset/reconfiguration
requires a separate future operation. The detached identity helper owns nothing.

The later daily process adapter must publish counter and identity together only
on process success, then the source adapter only on binding success. Persistent
integration must place metadata in the existing irrigation carrier, prohibit
simultaneous weekly/TCSFIX activation, validate clone/restart/commit transitions,
and keep default-disabled paths unchanged. No bootstrap activation is authorized
by merely implementing the detached helper; its owner integration requires gates.

Structural transition guard: require valid enabled endpoints and unchanged
interval. Same ordinal/binding permits only unchanged counter. First binding or
exact successor permits retaining the counter (ineligible/pending), incrementing
by one only below interval, or resetting to1 only at/above interval. Reject
activation, disablement, unbinding, gaps, backwards movement and interval edits.
This is necessary structural validation, not proof that a scientific event was
selected; the process remains responsible for that decision.

## Carrier dependency inventory and implementation order

Reviewed at `231e932a0`: existing weekly ownership spans
`mod_fmr_serialized_reference_backend` (carrier, candidate constructor, validation,
prepared proposal scratch, trial validation and candidate injection),
`mod_fmr_serialized_multiswap_runtime` (proposal forwarding), and
`mod_fmr_production_application_bootstrap` (array preflight/per-column forwarding).
The backend imports weekly metadata from the already shared irrigation process
module. Search finds 84 test/tool files mentioning that shared module or the new
identity module; introducing another prerequisite into the backend would affect
many independently maintained build lists.

Stage 1: move only TCSFIX metadata type and pure identity/transition validators
into `mod_irrigation_process`, and retain `mod_ppa_irr_tcsfix_identity` as a
compatibility re-export plus daily preparation. No semantic or carrier change.
Replay dedicated composition and existing owner gates against that ref.

Stage 2: add default-disabled TCSFIX field and trailing constructor argument to
the existing carrier; validate both identities and mutual exclusion. Clone and
decoded restart must preserve the new field. Reject enabled TCSFIX execution
until an explicit proposal channel exists; never silently drop its state.

Stage 3: add a trailing typed proposal channel through backend/runtime/bootstrap,
validate transitions and pending counter retention before trials, inject into
the same hydraulic candidate and clear scratch on every exit. Preflight all
columns before execution. Test invalid second-column metadata without earlier
publication and mixed disabled/weekly/TCSFIX preservation. Only then expose an
explicit source-adapter bootstrap route. No separate state owner or default
activation is introduced at any stage.
