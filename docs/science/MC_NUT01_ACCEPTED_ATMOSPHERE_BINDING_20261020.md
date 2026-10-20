# Historical nitrogen: accepted dry-surface atmosphere binding

Status: canonically admitted bounded successor, PR1333, actual merge `6a2985776d2f242572725d8c18489260296c6732`.

Baseline: canonical `e57a94e5f229415111563f8c52822ac3c7ba5491`.
Owner: existing MC-NUT01-HIST-COMPLETE. No MC-SOL01 physical module changes.

Original SWAP 4.3.1 `management_soil` lines 400–402 defines the N
carrier as `0.01*(igrai+isnrai+igsnow+igird-iintc+irunon-iruno)/outper`.
Evaporation is separate. This successor binds the existing production
`pond_input` atmosphere to that expression for the subset with no snow,
interception or persistent surface water. Rain, irrigation and runon are
integrated over the accepted substeps; runoff is already a depth. Thus
`qN=0.01*sum(dt*(rain+irrigation+runon)-runoff)/day` in m/day.
The existing net surface carrier remains the water authority.

Selection requires `atmospheric_n_surface=.true.`, an allocated `pond_input`
and no explicit `historical_top_water`. Supplying both is an error, so there
is no duplicate N application. Other atmosphere providers and snow remain
excluded. Every substep must carry converged gross/surface diagnostics and
zero beginning/end pond storage; negative daily aggregate is rejected.
These diagnostics are consumed only from the completed backend candidate's
accepted substep trace, after existing hydraulic/carrier validation. This
contract does not promote arbitrary converged diagnostics to accepted state.

Only the existing joint crop/Soil-N transaction stages the computed scalar.
Hydraulic or chemical failure discards the entire candidate. No new state,
restart schema, transport equation or surface N store is introduced.

Qualification selects a new actual Reference/WOFOST81/Soil-N trajectory,
O0/O2, fresh-process resumes, invalid-source and hydraulic/chemical rollback,
and preservation of all previous endpoint bytes. The existing strict owner
must also execute unchanged at the pinned predecessor. Full F-CI and
RossFast/highest low-air are not selected: the shared water/transport source
and their admission contracts are unchanged. The aggregate owner remains
daily; fractional dates and extended output are separate open requirements.

The first fresh higher-rain candidate was hydraulically and chemically accepted
on day one (1291 hydraulic substeps), but failed the final crop/residue gate.
Naive daily root summation made fully supplied crop water appear slightly
deficient and generated a spurious leaf-death flux. The successor compensates
the accepted root integral only on this opt-in atmosphere route. It never
substitutes potential water uptake, changes accepted water, broadens the
existing eight-rounding crop equality guard or relaxes a mass tolerance.
This failed candidate remains evidence; it is not a qualification PASS.

An independent quad-precision diagnostic sums the actual first-day accepted
root trace (2582 accepted half-step records from1291 accepted transactions).
The naive m/day integral is7.9999999999999810e-6; compensated is
8.0000000000000013e-6; quad reference is
8.00000000000000038337388819087436869e-6. Relative errors are
2.4225142291472990e-15 and1.1858461261560205e-16 respectively.
The corrected real joint day completes with status0. This diagnostic explains
why the original eight-rounding crop guard is sufficient after accurate
integration. It is separate from the complete qualified trajectory.

## Completed actual physical qualification

Fresh GNU Fortran13.3.0 O0/O2 with bounds/FPE checks passes the actual
Reference Richards/WOFOST81/Soil-N production composition. The new dynamic
atmosphere profile spans12 days, native amendment events, active crop/root
states and nutrient uptake. Weather/material/grid choices are synthetic
qualification inputs; this is a coupled model calculation, not a calibrated
field prediction or complete original-model replay. The trace-only driver
is a separate synthetic process fixture (21 invalid cases per optimization).

| Whole-system N, kg/m2 | Value |
| --- | --- |
| Initial | 0.66592190132155538 |
| External input | 0.0062479886961157695 |
| External output | 0.00032461208981581679 |
| Final | 0.67184527792785542 |
| Signed residual | -1.0446287931897835e-16 |
| Absolute residual | 1.0446287931897835e-16 |
| Relative absolute residual/(initial+input) | 1.5541142331774496e-16 |
| Maximum daily N residual | 1.1528139587954709e-16 |
| Crop N uptake | 5.1528020441996171e-6 |

Maximum accepted water-step residual is5.1869587184422139e-15cm.
Unchanged hard gates are1e-12kg/m2 daily,1e-10kg/m2 cumulative, and
1e-10cm water. These tolerances retain their admitted double-precision and
physical-scale rationale; no threshold was widened. Gross N is applied
once, in the existing mineral/reactive top-source ledger. Internal N transfer
and uptake cancel from the joint inventory as in the predecessor.

All12 predecessor endpoint files (six profiles per optimization) remain
byte-exact. The new12-day endpoint is O0/O2 exact, SHA256
`604ace30a0f0b1c06fe941c9c25e5d42c9b4492e5a2ab41efdca03e1207b2c55`.
Four new fresh processes resume at days1 and6 under both optimizations;
each reproduces the complete uninterrupted endpoint, including cumulative
stocks and fluxes. At day6, forced hydraulic rejection, stale chemical
forcing and forbidden clean-only routing retain byte-identical complete
restart payloads. The explicit-plus-automatic source conflict also rejects.
The earlier48 transition restarts, harvest/fallow/calendar and gross-profile
rollback assertions remain selected and pass again.

Measured physical round: compilation235.388s, linking0.869s, main native
execution181.992s, fresh restarts190.996s (see raw events for exact totals).
No full F-CI, RossFast or highest-low-air campaign was selected.

Reproduce with the original immutable reproductive literal and GNU Fortran:

```bash
ulimit -s unlimited
export OMP_NUM_THREADS=1 PYTHONDONTWRITEBYTECODE=1
export FC=gfortran
export REPRODUCTIVE_PROCESS_RESULT_DIR=/absolute/path/to/fresh-literal
python tests/nut-crop/run_reproductive_process.py
export REPRODUCTIVE_LITERAL_FILE=$REPRODUCTIVE_PROCESS_RESULT_DIR/literal.f90
export N_HIST_RESULT_DIR=/absolute/path/to/fresh-results
python tests/nut-crop/run_hist_complete.py
```

The literal SHA256 is
`b64c01e310927bad85f40a467ac356c300c4f72a062d60cc113927f68ac76c14`.
The owning evidence additionally records full compiler commands, all raw
streams, exact source inputs and separate failed/censored diagnostic context.

## Concurrent MC-SOL01 grid admission reconciliation

Canonical advanced to1158562fccf62bff0c3b7bb4e2e3c8371fae74be (PR1332)
while these numerical gates ran. Its application/grid changes, original guard
handoff, status and hosted evidence are retained. Every actual NUT numerical
input remains exact, so no additional physical run is selected for this delta.
The unchanged original complete grid/NUT authority is executed at that exact
predecessor. The current candidate separately verifies all178 executed grid
providers against the official O0/O2 build inventories.

Only the grid admission entry point receives an opt-in handoff to this strict
NUT successor. Its previous114-line body remains byte-identical under an exact
code-transform check. Current application/tests/examples/status remain exact
against1158562f. The NUT successor owns exactly seven postimages, including
this admission handoff; no shared transport or solute application equation is
changed. This dependency is required to preserve both simultaneously admitted
workstreams, rather than bypass either source-freeze guard.

Retained-stock current native qualification, thermal/empty phase comparisons
and all54 TCS6 trajectories pass. The source-bound successor and nine
corruption controls pass on the reconciled candidate. The unchanged original
predecessor authority and its eight controls also pass. Main immutable evidence
has decoded SHA256`adf78708256bd1716ae616b6c67227138270413eb8c9f3c3c6b24b76d172d35e`,
266252compressed bytes and5221regular members.

## Actual canonical receipt

Qualified head `9a345b00b311a6b4795fa993a20b3497b2646c91`, exact qualified tree `723f1e2a56cdc1b26addf8149a272ce160144cf5`,
actual canonical merge `6a2985776d2f242572725d8c18489260296c6732`, production source tree `06d4d60b83432f4fbd54178437d29d47d4efb16d`.
Both actual-merge NUT and grid admission entrypoints PASS. Master receipt
`882aa4824741c771ea5170477e1adf92ec9a5981` preserves234 other rows and all243 dispositions.
No new hosted Actions run was selected or created. Admission/control capsule
`integration/audits/evidence/MC_NUT01_ACCEPTED_ATMOSPHERE_ADMISSION_20261020.tar.xz.b64`, decoded SHA256`040b5005de2b23478c1633ed3690269a6f3804ff3634bd0eefbecdc5d747c039`,
retains actual-merge proof, nine controls, original controls, strict docs logs
and exact admission/master context. Full historical MC-NUT01 remains open.

For the separately preserved crop/residue owners, use a fresh output directory:

```bash
export REPRODUCTIVE_LITERAL_SHA256=b64c01e310927bad85f40a467ac356c300c4f72a062d60cc113927f68ac76c14
export CROP_N_RESULT_DIR=/absolute/path/to/fresh-retained
python tests/nut-crop/run_b112_retained_joint.py
python tests/nut-crop/run_b112_retained_phases.py --providers "$CROP_N_RESULT_DIR" --output /absolute/path/to/fresh-phases
python tests/nut-crop/preserve_b112_tcs6.py --providers "$CROP_N_RESULT_DIR" --output /absolute/path/to/fresh-tcs6
python tests/nut-crop/verify_hist_native_successor.py
python tests/nut-crop/verify_accepted_atmosphere.py --self-test
```

The default source/evidence gate also passes without supplied predecessor
worktree paths: it stages and checks the exact original authorities itself.
