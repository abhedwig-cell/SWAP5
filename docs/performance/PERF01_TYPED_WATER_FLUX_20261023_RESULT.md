# Typed water-state and flux candidate

Implemented on `work/perf01-typed-water-flux-20261023`, reconciled with canonical
`5659a644` (PR1405 drainage and PR1406 FCT joint research). Local bounded native
tests pass. Owner qualification against pinned canonical `ef2110c6` now passes;
later PR1409/1410 reconciliation and canonical admission remain pending.
This is an explicit changed-accuracy option, not a default change or an
accuracy-matched comparison to4.3.1.

The [production contract](../science/PERF01_WATER_FLUX_TEMPORAL_POLICY.md) replaces
generated geometry with physical parameter `dz`, introduces a source-compatible
model-owned sibling-outcome assessment, and retains the engine's existing hard
solver, mass, acceptance and rollback gates. Existing models delegate their exact
state comparison. The backend additionally publishes real uptake metadata only
for the enabled option. No physical sink law or restart schema changes.

The native input is `water_flux_temporal=.true.`; the CLI is
`--water-flux-temporal --retain-step-proposal --temporal-tolerance .001`.
The fixed0.001cm state/head and0.001cm/day uptake/export budgets are explicit;
another native legacy tolerance rejects. The first domain remains the tested
four-cell30cm zero-tracer plain-evaporation frozen-conductivity crop route.
Thermal, implicit pond, Boesten, positive tracer, seasonal/detailed forcing and
active drainage combinations are excluded. No new1e-6 run, RossFast extension
or highest-low-air test was selected.

The composed current build executes62 native processes:52 successful and10
expected input rejections. Base and active empirical-root97day1x/4x cases pass
all previously declared PR1404 criteria at O0/O2. Eight actual day48 continuations
are byte-exact, including remaining daily budgets. Every final typed physical
file is byte-exact to the sealed research prototype. Default proposal and
no-proposal outputs remain byte-exact to their independent versioned incumbents.
Independent original rain/bottom water reconstruction closes below7.7e-13mm.
The separate soil/pond evaporation limitation is unchanged.

| O2 native process, paired medians | Incumbent, s | Typed option, s |
| --- | ---: | ---: |
| Base1x |0.5632|0.02676|
| Base4x |0.6265|0.01815|
| Active root1x |0.2811|0.03299|
| Active root4x |0.2197|0.02318|

These are three alternating pairs per row, after preparation. The Python/native
publication envelope is not included or remeasured. Host/cohort variation rules
out comparing absolute timings across separate historical cohorts.

The direct34-case estimator driver, unchanged pond/transaction assertions and
context tests pass O0/O2. The old context fixture was stale on canonical itself:
it omitted explicit complete-mass declarations. Both unchanged-baseline builds
reject that old fixture; adding those declarations preserves every original
state/rollback assertion and passes against both old and current transaction
sources. Expected stale-fixture failures are retained, not labelled as PASS.
The current Boesten/root/positive-solute joint rejection/retry/ABA and fresh V3
decode also pass O0/O2 on the composed providers.

The sealed2273-member evidence archive and independent replay have six corruption
controls. `PERF01_TYPED_WATER_FLUX_20261023_STATUS.json` records recoverability and
the pending owning boundary. No current native drainage/NUT owner PASS or
production admission is claimed. Its source guards correctly refuse an
unregistered shared-interface delta; completing that successor requires current
affected execution evidence and preservation of all incumbent assertions.

Earlier development captures remain distinct: an incomplete qualification had
finished O0 before the O2 bundle existed; both builds are now preflighted. Earlier
builds were superseded when actual guarded sources/canonical drainage changed.
Only the composed final captures define the table and62-process result above.

PR1407 was subsequently preserved through canonical `ef2110c6`. Its two changed
organic providers lie outside the actual measured native closure. Complete
capsule replay rechecks all executed current inputs and passes after that merge.
Current owner dispatch now reaches `verify_nut_single_zero_pool.py`; its successor
preservation remains pending. This source reconciliation grants no NUT PASS.

## Pinned owner qualification completed

The current owner replay now passes with all 134 predecessor controls and 241
combined source/raw/negative controls. Fresh current HIST executes all 78 native
processes (56 process restarts); 208 affected compiles are fresh and 446 unchanged
compile closures are reused with exact source, flags, toolchain and artifact
seals. All original scientific assertions remain unchanged. Current single-zero
NUT executes 14 coupled cases and 28 process restarts. O0/O2 drainage469 and
Boesten481 complete and restart files are byte-exact to admitted files. Twelve
SOL research water traces and 24 actual FCT joint cases pass. Drainage day470
and wet-day7 remain fail-closed with the complete committed generation intact.
Full MC-SOL01/MC-NUT01 migration is not closed.

The 3732-member owner capsule preserves this qualification separately from the
2273-member typed option capsule. A subsequent fetch found canonical
`247b9f5b`: PR1409 changes two organic providers used by HIST/NUT, while PR1410
adds reactive FCT research. This later composition is not covered merely by
the pinned owner PASS and must be reconciled before admission.
