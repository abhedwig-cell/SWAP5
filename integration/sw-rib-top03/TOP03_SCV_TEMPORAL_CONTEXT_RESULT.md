# SCV transaction correction and bounded qualification

Date: 2026-10-03. Status: **bounded correction qualified; no production admission**.
Source qualification commit: `8977d081ff8125174836dea6ef69fb2f11dac893`.
Implementation commit: `826e831`. Scientific baseline: `b52ad0d86`.
Remote source snapshot: `38ad618bc90f38288e0e16e57a4e976b3aad6d2d`; its
entire Git tree matches qualified local 8977d08. Recovered baseline is published
as `e926fa16150e06a0c2ef071bd3d700adab239c62`, with exact local b52ad0d86 tree.
These are connector-created commits with different commit metadata, not reruns.
Machine results and raw numeric records: `evidence/scv_temporal_context/result.json`.

## Reconciliation

The clean local SCV worktree was on work/sw-rib-top03-transactional-top-exchange
at b52ad0d86. The actual remote branch was at f5063889, a sibling research line
with no production source delta from common checkpoint 4166548d. Its tree was
verified identical to locally recovered 3af86fc. Another local sibling worktree
had uncommitted provider-generator research. It was inspected read-only and
left untouched. This work used an isolated SCV clone, with no new HeadCalc,
constitutive, lower-boundary, macropore, oxygen or crop change.

The published review snapshot retains the existing SCV source prerequisite
changes from the local baseline. Those older differences from the common
checkpoint are not new changes made by this transaction correction. It does
not overwrite or merge the shared remote TOP03 branch. Reconciliation with the
sibling/current canonical remains required before admission.

## Cause and correction

The legacy FMR callback returned huge() for every nonidentical ordinary B1.10
full/half endpoint. The full top-exchange context was also discarded before
comparison. An additive context-aware callback now receives snapshots of both
branches. Its default delegates to the unchanged legacy endpoint callback.
Only explicit unified-CV selects a finite norm of non-cancelling layer-water
error, pressure-head error, local surface storage error, and signed external
exchange integral error. The existing scalar tolerance bounds each channel
in cm; it is a conservative research budget, not application-calibrated policy.

Acceptance still selects the composed halves and their context. Rejection
restores the common checkpoint. SCV discard and incomplete outer windows clear
all exchange/soil-face scratch. Compact physical/restart layouts are unchanged.
The existing participant also contained a single-substep admission gate. SCV
alone now permits a completely accepted composed window using its selected
whole-window integrals. Component receipts still validate top and subsurface
terms separately, provenance, interval, and exactly-once commit.

Positive exchange is SWAP to external owner. With Qsoil=-qtop:
soil change = integrated Qsoil minus outward bottom exchange;
surface change = minus external exchange minus integrated Qsoil;
combined change = minus external exchange minus outward bottom exchange.
The Richards top term is internal to soil plus local surface and is replaced
by external exchange in the combined ledger. It is never booked twice.

## Completed gates

Commands on the persisted source, GNU Fortran 13.3.0, runtime/FPE checks:

```bash
bash tests/fapp/run_fapp09_ribasim_external_surface_water_profile.sh unified-cv
bash tests/fapp/run_fapp09_ribasim_external_surface_water_profile.sh preservation
```

Both finish O0/O2 with identical numeric output. The unified runner also compiles
and executes the independent exchange-only transaction fixture at both levels.
It rejects differing exchange integrals even when physical endpoints are equal,
then checks retry, selected-half context, composition and replay. Orthogonal
SCV norm probes cover soil redistribution, head, surface, exchange, malformed
geometry and nonfinite data. Real FMR tests cover tentative accept, reject,
discard, replay, subdivision, outer failure after accepted internal progress,
duplicate commit and decoded committed restart with a fresh backend. Both soil
and surface endpoints, exchange integral, mass and Newton work match on restart.

The participant test validates mismatched component receipts, total masking,
stale origin, changed-stage replay and exactly-once commit for real SCV trials.
This uses the existing adapter; no live Ribasim engine or external feedback is run.

## Before and after

The original 0.03125-day FAPP09 case was reproduced O0/O2 at b52ad0d86:
zero accepted substeps, three temporal rejects, 63 total Newton iterations,
no exchange carrier, even at temporal tolerance 1e15. Its last Richards solve
converged in six iterations. The before-work record adds only a diagnostic
print of the aggregate Newton count to the baseline driver.

After correction, tolerance 0.01 cm with retry budget 16 completes that window:
six accepted transactions, thirteen temporal rejects, 356 total Newton iterations.
Signed exchange is -7.5071855327774105e-4 cm; combined mass residual is
3.9797809145425411e-15 cm. The earlier two-retry budget is insufficient at this
finite tolerance. At attempted dt 0.0078125 day, the head difference was about
0.026435 cm, versus 1.919e-5 cm layer-water error and 5.117e-9 cm exchange error.
Head accuracy, rather than exchange accuracy, drives that rejection.

A preloaded 0.05 cm local store with dry external stage has a genuinely positive
accepted exchange of 6.3968082144248402e-6 cm over 0.0001 day, costing 2725 Newton
iterations. Thus both directions can pass transaction acceptance, but this
strict fixture demonstrates a substantial work cost.

The matrix covers external stages -1e-8/0/+1e-8 cm and a 0.02 cm pulse over
0.25 day, at refinements 1/2/4/8/16/32/64/128. Every tested window completes.
Signs below 1e-12 cm are excluded from direction counts. Stages around zero
are all below the 0.01 cm sill: this tests the dry branch, not sill activation.
The one-bin endpoint quadrature misses the pulse; it is not a accuracy estimate.

| Pulse refinement | Accepted substeps | Temporal rejects | Newton | Signed exchange (cm) |
| --- | ---: | ---: | ---: | ---: |
| 8 | 23 | 40 | 1217 | -0.003751996897326276 |
| 16 | 28 | 24 | 963 | -0.003751797542122539 |
| 32 | 38 | 9 | 821 | -0.003751700211632637 |
| 64 | 67 | 4 | 1171 | -0.003751651562709511 |
| 128 | 129 | 1 | 1968 | -0.003751627148982371 |

The 64-to-128 exchange difference is 2.44137e-8 cm, about 6.51e-6 relative.
Refinement decreases rejects but eventually increases total Newton work.
Across all 32 completed matrix runs, maximum soil and combined residuals are
2.070913e-14 cm. The surface identity residual is zero because external exchange
is materialized from local-storage and soil-face balance. This is an accounting
identity, not an independent integration of the provider's external flux.
Independent provider-flux evidence remains the earlier direct-solver study.

## Negative evidence and remaining boundary

A 2 cm jump in the dry FMR fixture, requested over 0.125 day, remains incomplete
after 472 internally accepted transactions, 385 solver rejects, 3997 temporal
rejects, 220314 Newton iterations and zero mass rejects. Committed soil/surface
state is unchanged and the selected exchange carrier is cleared. This is an
explicit negative regression, not a successful coupled run. The normal runner
requires that failure remain nonpublishing. No larger stage sweep follows it.

An exploratory 0.2 cm near-saturation-width counterfactual terminated at
`HeadCalc: dynamic top-boundary provider unavailable`. The archived diagnostic
log is a failed experiment. It does not establish a safe constitutive repair.
The concurrent stable-provider work must be reconciled before further wet-stage
qualification. This correction does not modify that source or suppress the error.

No global temporal-accuracy theorem follows from the full/half norm. The signed
integral does not bound gross counterflow or waveform error; the scalar head
and water budget needs application-specific separation/calibration. Restart
uses the existing decoded bundle contract, not a new serialized process test.
Atmospheric forcing, evaporation, runoff, snow, other bottoms and live Ribasim
storage feedback remain outside this bounded SCV qualification. A robust
production basis for SWAP5–Ribasim is therefore **not yet established**.
