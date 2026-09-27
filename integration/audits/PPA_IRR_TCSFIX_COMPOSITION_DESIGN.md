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
