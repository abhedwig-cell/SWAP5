# F-PE-DIR01_CLOSEOUT — production bottom-head directional tangent exact-cost reduction

Date: 2026-09-26

Status: `CLOSED_WITH_RETAINED_EXACT_REPAIRS`

PR:
`#628 — F-PE-DIR01: production bottom-head directional tangent exact-cost reduction`

Branch:
`work/f-pe-dir01-bottom-head-tangent`

Stacked parent:
`PR #627 — F-PE-PROFILE04`

Canonical authority underneath the stack:
`integration/f-ci-canonical@c52454b31d6f5d6ae6ed6af56460f158ddb45008`

## Why DIR01 existed

PROFILE04 established that the MODFLOW production route explicitly requests a bottom-head accepted-trajectory response tangent and that this directional route added approximately 86-88% runtime above the corresponding Reference interval without adding a full nonlinear solve.

The raw tridiagonal backsolves explained only a small fraction of that increment.

DIR01 therefore owned one exact question:

Can the production-required bottom-head tangent be made materially cheaper without changing the physical solve, accepted trajectory, derivative semantics, transaction ownership or mass balance?

## Initial attribution

Function profiling and heap attribution showed that the directional increment was not one monolithic tangent cost.

The original directional route carried approximately:

- +32 malloc per application interval;
- +4 calloc;
- +36 free;
- about +2.6 kB malloc traffic plus +128 bytes calloc traffic.

The largest recurring categories were:

- transaction attempt-context ownership/copy work;
- request/result/trajectory vector allocation;
- default-MvG constitutive directional work;
- outgoing water-content directional evaluation;
- publication/copy chains;
- three accepted-step backsolves.

The raw backsolve kernel remained small.

## Repair01 — result-to-pending-to-accepted move ownership

Status:
`QUALIFIED_KEEP`

Repair01 replaced single-use direction-vector deep copies with ownership transfer where the source object was no longer required.

Observed effect:
- six malloc/free cycles removed per application interval;
- exact preservation of checksum, derivative and accepted-route diagnostics;
- approximately 0.8-0.9% directional interval speedup in the paired qualification.

This repair is retained.

## Repair02 — remove accepted-half attempt-context round-trip

Status:
`REJECTED_SEMANTICS`

A test-local experiment suggested approximately 2% runtime gain and removed a material context copy/allocation round-trip.

However, the transaction semantics could not be admitted safely. Repository reconciliation therefore rejected and reverted the production attempt.

DIR01 does not retain Repair02.

This result is important: generic transaction rollback/commit ownership must not be weakened merely because the common accepted path appears to make a context restore redundant.

## Repair03 — reusable incoming directional request workspace

Status:
`QUALIFIED_KEEP`

The original request builder allocated incoming pressure-head and water-content direction vectors repeatedly.

The qualified repair:
- moved the request carrier to worker-local reusable scratch;
- changed the request builder to explicit reset plus `intent(inout)`;
- retained optional source/sink absence semantics;
- reused the two incoming vectors when shape remained unchanged.

Deterministic heap effect:
- 6 malloc fewer per application interval;
- 6 free fewer;
- 192 fewer malloc bytes.

Replicated timing:
- independent job-median speedups approximately 1.17%, 2.42% and 2.02%;
- other paired production runs fell in the same approximate 1-2.5% range.

All preservation checks remained exact.

Repair03 is retained.

## Post-Repair03 rebaseline

A fresh bottom-head measurement still showed a very large directional increment.

The robust conclusion was not the absolute ratio from one hosted runner, but that the tangent route still remained a major repeated-execution cost.

Heap attribution after Repair01 + Repair03 showed approximately:

- +20 malloc;
- +4 calloc;
- +24 free;
- about +2210 malloc bytes;
- +128 calloc bytes;

per directional application interval relative to Reference.

This confirmed that ownership cleanup helped but did not remove the principal directional cost.

## Repair04 — compact trajectory-only attempt context

Status:
`REJECTED_NOT_MATERIAL`

Repair04 tested a compact attempt-context representation for the case where trajectory direction was the only active rollback owner.

The experiment preserved the qualified outputs and reduced payload bytes, but did not reduce allocation count.

Observed effect:
- about 384 fewer allocated bytes per interval;
- no malloc/free-count reduction;
- approximately 0.3-0.4% median/mean speedup.

That is below the threshold for carrying another production specialization.

Repair04 was rejected.

## Repair05 — fused default-MvG base conductivity + directional constitutive pass

Status:
`QUALIFIED_KEEP`

This became the most important retained DIR01 repair.

Before Repair05, every accepted directional step performed:

1. a default-MvG conductivity value pass at the base pressure head;
2. a second default-MvG directional constitutive pass over the same nodes.

Repair05 computes:
- exact base conductivity K;
- exact water-content direction;
- exact conductivity direction;

inside one smooth-branch node loop.

The direct-retention path remains unchanged.

### Exactness

A 12-case production matrix:

- B01;
- B12;
- O05;
- O14;
- wet / mid / dry;

showed for every case:

- bit-identical base conductivity K;
- bit-identical water-content direction;
- bit-identical conductivity direction;
- identical smooth-route availability and route semantics.

All maximum differences were exactly zero.

### Mechanistic proof

Pre-Repair05 profiling on 500,000 application intervals showed approximately:

- Reference `b110_default_mvg_evaluate_demand`: 1,500,306 calls;
- directional: 3,000,603 calls.

The directional route therefore carried almost exactly three additional constitutive value-provider calls per interval, matching the full + half + half internal transaction path.

On the Repair05 postimage:

- Reference: 1,500,303 calls;
- directional: 1,500,303 calls.

The repeated standalone conductivity value pass was actually removed.

### Runtime

Independent paired runs were consistently positive.

Observed aggregate examples include:

- about 5.0% median speedup;
- about 5.8% median speedup;
- about 3.1% median speedup on the production postimage.

Hosted-runner variance remains visible, so DIR01 does not promote one run as a universal constant.

A defensible planning range is approximately 3-6% directional interval speedup from Repair05.

### Preservation

The Repair05 postimage passes:

- FKT22 production compile;
- FKT22 O0 runtime;
- FKT22 O2 runtime;
- O0/O2 identity;
- default-off preservation;
- accepted trajectory route;
- accepted-step and backsolve counts;
- trajectory provenance;
- rejected-trial isolation;
- physical identity.

Repair05 is retained.

## Post-Repair05 rebaseline

Fresh current-postimage bottom-head timing:

- Reference median: approximately `8.738 us/interval`;
- directional median: approximately `15.106 us/interval`;
- directional / Reference ratio: approximately `1.729`;
- directional increment: approximately `+72.9%`.

The exact absolute values remain runner-dependent.

The robust qualitative result is that DIR01 reduced real repeated work, but the bottom-head tangent remains expensive relative to the Reference solve.

The post-Repair05 heap map still shows:

- +20 malloc;
- +4 calloc;
- +24 free;
- approximately +2210 malloc bytes;
- +128 calloc bytes;

per directional application interval.

The largest byte-volume owner remains the generic serialized attempt-context machinery. Repair04 showed that merely shrinking its payload is not a material optimization.

Remaining local computation includes the final accepted-candidate water-content directional pass and unavoidable tangent assembly/backsolve work.

## Repair06 — reuse accepted candidate capacity

Status:
`REJECTED_STALE_WORKSPACE_PROVENANCE`

Post-Repair05 profiling showed `evaluate_b110_default_mvg_water_content_direction` about three times per application interval and at roughly 4.8% of profiled directional self-time.

Repair06 tested the hypothesis that the Reference workspace already held:

`C(h_candidate) = dtheta/dh`

for the final accepted candidate, allowing:

`dtheta_out = C(h_candidate) * dh_out`

without another MvG pass.

The code-path audit falsified that assumption.

For the admitted `swkimpl=0` path, after the Newton head update:
- candidate pressure head is updated;
- the candidate constitutive demand requests only water content;
- `provider_capacity` is not refreshed;
- convergence is then tested on the new candidate.

Therefore the workspace capacity may still belong to the preceding Newton/Jacobian state.

It is solver scratch, not an accepted-candidate capacity publication.

Repair06 was rejected before production experimentation.

No solver-workspace semantic expansion was introduced merely to enable this optimization.

## What remains

After Repair01, Repair03 and Repair05:

- raw tridiagonal backsolves are too small to justify a dedicated exact workunit;
- compacting attempt-context payload without reducing allocator calls is too small;
- transaction-core shortcutting was rejected on semantics;
- accepted-candidate capacity reuse is invalid because provenance is stale;
- request allocation waste has been removed;
- one duplicated default-MvG value pass has been removed;
- publication/copy sites remain comparatively small;
- remaining directional constitutive and tangent work is increasingly tied to the actual derivative computation or would require broader solver-state redesign.

DIR01 therefore has no remaining clearly measured exact-P0/P1 target large enough to justify another repair cycle.

## Net interpretation

DIR01 must not add the individual Repair01, Repair03 and Repair05 percentages arithmetically and call that the total tangent speedup.

Different measurements were taken on different postimages and hosted runners.

The correct authority is the current postimage rebaseline.

Relative to the PROFILE04 starting point:
- the production-required bottom-head directional route remains expensive;
- the measured relative increment has moved from roughly 86-88% to about 73% on the current rebaseline;
- exact ownership and constitutive waste have been removed where evidence supported it;
- the remaining large gap is no longer dominated by one obvious removable exact overhead.

That is sufficient evidence to stop the exact tangent optimization phase.

## Next workunit

Preregistered:

`F-PE-APPROX01 — practical / approximate MultiSWAP performance phase`

Preregistration:

`docs/performance/F-PE-APPROX01_PREREGISTRATION.md`

The exact canonical stack remains the reference and default.

APPROX01 may explicitly trade bounded numerical exactness for materially larger end-to-end speedup, provided error envelopes, mass balance, relevant states, fluxes and coupled MODFLOW behavior are quantified.

## Repository / CI note

DIR01 is stacked on PROFILE04 PR #627 because PROFILE04 itself has not yet been admitted to canonical.

Some older preservation workflows compare exact historical source blob hashes and therefore fail after intentional, separately qualified production edits. Those failures are not numerical regression evidence; their preservation authorities must be rebuilt as part of later canonical admission.

DIR01-specific production behavior is qualified by:
- paired pre/post performance measurements;
- deterministic heap attribution;
- 12-case constitutive bit-equivalence;
- FKT22 compile/runtime qualification;
- explicit rejection of semantically unsafe or immaterial candidates.

## Closure statement

F-PE-DIR01 is closed.

Retained exact production repairs:

1. Repair01 — move ownership across the accepted directional result chain;
2. Repair03 — reusable incoming directional request workspace;
3. Repair05 — fused exact default-MvG base conductivity + direction.

Rejected candidates:

- Repair02 — transaction semantics not safe enough;
- Repair04 — not material;
- Repair06 — stale workspace provenance.

The remaining exact headroom is not strong enough to justify another DIR01 repair.

The performance program should now move to F-PE-APPROX01.
