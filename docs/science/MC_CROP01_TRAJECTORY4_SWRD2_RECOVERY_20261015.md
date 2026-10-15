# Persistent SWRD2 daily production recovery

Workstream: MC-CROP01 / crop, RT/F-KT state and application binding.
Separate authorized successor to the closed SWRD3 work unit. PR1241 remains
merged at `2dfacf1c177c9b117dcc74b3f17c91f167debd39`; do not reopen it.

## Current recoverable boundary

Branch: `work/crop-swrd2-20261015`. Canonical reconciliation:
`451e35ccd1797aa96fb4354dabc465cceff18635`, with unchanged predecessor
production tree `b8ac1c1c12096bc40478a58c5c8ac36ba687e3e0`.
The only live delta after trajectory3 was the harvest phase design note.
No harvest/rotation implementation or adjacent PR is incorporated here.

Current science tree: `fe8a6c1b569e641dccb6b0cc163d3318e7e6d9c0`.
Exact postimages, phase, evidence and next operation are maintained in
`integration/audits/MC_CROP01_TRAJECTORY4_SWRD2_STATUS.json`.
Source/contract implementation and current direct/physical testing are complete;
shared owner qualification and complete current moving preservation must reach
terminal PASS before admission. A checkpoint is not qualification or merge.

## Implemented bounded scope

Explicit SWRD2 with SWDMI2RD=0/1, static density, actual/potential daily depth,
accepted water scaling and optional accepted deepest-root oxygen suppression.
The existing rate owner owns the equations. Its optional two-depth state lives
inside the existing F-WOF38 committed crop transaction. No application depth
cache, duplicate biomass, water store or solver policy is added.

Both true current-day and lagged authentic-weather schedules use that owner.
Before emergence depth is zero; emergence initializes RDI without applying
another day's extension. Accepted growth, potential shadow, depth and receipt
publish atomically; rejection/retry/rollback/duplicate delivery cannot advance
depth. The real Richards sink sees only committed actual geometry. Whole-owner
opaque weather/crop/soil continuation carries the new state and configuration.

SWRD3 and default modes keep depth state absent. Immutable crop/application
parameters must match. Emergence already sets `active_event`, so its existing
matching guard also rejects independently valid foreign RDI before publication.
An initial review hypothesis to the contrary was refuted by an actual Fortran
driver, not repaired in production. Preserve the diagnostic and interrupted
owner records; do not reintroduce a speculative fix or call the hypothesis a
production failure.

## Scientific evidence and cost

Current direct contracts:30 O0/O2 native executions,39 production providers,
18.315741s wall (14.119128 compile,3.933801 link,0.082267 native).
Twenty are the retained original contracts and ten are new persistent-depth
transaction/oxygen/missing-input/restart cases. The39-provider closure is needed
for the real kernel/crop accepted-state interface; no mock replaces that owner.

Current real daily physical batch:28 programmes,226 providers per O0/O2,
440.797243s wall. Compile367.218036s, link1.533414s, native-plus-assertions
68.068526s. Original weather and SWRD3 plus new oxygen-gated, water-scaled OFF
and unscaled SWRD2 drivers preserve complete original scientific assertions.
All current original20 direct and16 weather/SWRD3 stdout records match the
immutable predecessor byte-for-byte. This is a current execution comparison,
not a relabelling of old N/thermal runs as new-tree executions.

Science capsule decoded SHA256
`9058db4010e20c515d2802090be8b1a3483aab493b7de3a108a11f8ddcf38b01`,
251844 bytes,1318 members, includes all raw outputs, flags/provider identities,
generated drivers/oracles, manifests and executed Git history. Actual direct
head `634b23454a5954c18bc876fada52efe49fb23b05` and physical head
`eb92c9dec75374391cf7754b0edfed0c1a9e79e6` remain independently identifiable.
Later validator/documentation commits do not change these executed inputs.

The predecessor SWRD3/thermal qualification/preservation validator also passes
at its exact canonical451e35cc checkout. Its old full execution remains bound
to its original9747341e source plus its admitted exact thermal default projection;
it does not qualify the new fe8a6c1b state/production semantics.

The existing ten shared owner/coupling gates are selected because shared crop
state/application binding changes. Completed prefix source/reference/heat was
retained only with exact original input and raw stdout hashes. An interrupted
F-KT22 attempt is censored, not PASS; it executes afresh on resume. A later
live-MODFLOW attempt stopped before execution on missing `bmipy`; its real
failed exit/raw logs are retained. Restore the dependency and resume only that
failed gate and the remaining gate, without rerunning successful source-bound
prefixes. The standard owner controller and full matrix remain authoritative.

Six admission routes must require both current science and current owner proof
without recursion. Historical mutation controls run against their valid frozen
positive proofs; corrupt old data against a stale source is not a meaningful
negative test. New current corruption/source controls remain separate.

## Admission and limits

One complete local moving F-CI OFF is selected only after stable candidate
science/owner/control PASS, followed by immutable raw evidence, exact tree and
live overlap/canonical reconciliation. No hosted workflow dispatch. Highest
long low-air is NOT_SELECTED_POLICY; a short existing owner numerical case is
not highest qualification. Full compile/link/native split and pure physics cost
remain UNKNOWN unless actually instrumented. Do not count parent controllers
and their child events twice, or count censored/failed attempts as qualified cost.

No complete SWRD2/density/lifecycle claim: SWDMI2RD=2 requires a real density
owner and accepted drought/supply composition; SWRDC=1 daily persistence,
advanced stress selectors, native weather disk codec, harvest/reset/fallow and
rotation remain separate. The source's independently selectable supply branch
must not acquire guessed static WROOT_NODE values. WOFOST81 N/fixation remains
unchanged. Full master census/qualification is not claimed; preserve dispositions
unless the exact owning capability admission actually supports a promotion.
