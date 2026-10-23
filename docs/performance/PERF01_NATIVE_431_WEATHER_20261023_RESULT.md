# Complete original-input application and saturated flux repair

23 October 2026. Qualification/admission state is owned by
`benchmarks/performance/PERF01_NATIVE_431_WEATHER_20261023_STATUS.json`.

## Result and limits

The fresh production repair completes both 97-day rainfall sequences with the
original eight nonlinear iterations, existing temporal setting0.001 and unchanged
hard water/solute acceptance. This is a constructed shared SWP/simple-crop/ETref
site,30cm/four cells, uniform plain MvG, prescribed bottom flux, zero tracer,
authentic1999 weather227/908mm. Both applications read the same original
SWP/CRP/MET bytes. It is **not** the earlier synthetic WOFOST/free-drainage case,
the original Andelst model or a regional production benchmark.

Three serial alternating O2 pairs per rainfall series, pinned to one available
core, give these full-process observations. Compilation is excluded; ordinary
front-end/input/output work is included. GNU13.3 was used for both applications.

| 97-day sequence | Original median wall s | SWAP5 median wall s | SWAP5 accepted substeps |
| --- | ---: | ---: | ---: |
| 1x rainfall | 0.023927 | 1.237268 | 9956 |
| 4x rainfall | 0.019708 | 1.087754 | 7154 |

SWAP5 4x is about12% faster than its1x counterpart here, not slower. More rain
does not necessarily produce more difficult transitions or more accepted steps.
The observed SWAP5/original ratios are about52/55. These are **not** accuracy-
matched or portable speed ratios: the original uses its historical adaptive
controller and compatibility initialization; SWAP5 uses external full/half
assessment, checked arithmetic/bounds and a Python preparation/publication route.
The original sub-25ms timings are especially sensitive to launch/scheduling.
The result is nevertheless clear: earlier matched-kernel timings cannot establish
complete-application speed. This application path remains substantially slower.
The next performance question is the controller/accepted-step workload, with
separate native/front-end profiling, not more relaxed mass conservation.

## Physical observations

| Quantity | 1x original / SWAP5 | 4x original / SWAP5 |
| --- | ---: | ---: |
| Runoff, mm |104.795380 /104.795350|783.405371 /783.405283|
| Soil evaporation, mm |24.188252 /24.304555|12.415099 /13.614832|
| Pond evaporation, mm |18.395432 /18.279128|30.168585 /28.968851|
| Actual transpiration, mm |55.343817 /55.343817|55.343817 /55.343817|
| Total storage change, mm |14.577160 /14.577150|16.967228 /16.967217|

Total evaporation agrees to about1e-11mm/day, but soil/pond partition does not:
the4x seasonal shift is about1.20mm, with one daily component difference0.722mm.
Do not call individual evaporation components equivalent. Maximum daily runoff
differences are0.00213/0.00858mm and storage differences0.00213/0.00825mm.
The crop is unstressed here; equal actual/potential transpiration is not a
stress-response qualification. Independently reconstructed current gross daily
balance is below6.1e-13mm; reported current residuals below4.7e-14mm. Original
reported residuals reach approximately5.9e-6/9.0e-6mm and remain visible.

An explicit **existing** `historical_zero` exfiltration convention is required
for this zero-tracer comparison. Its default remains `reject`: an actual fresh
default4x run still rejects chemical upward export at day69 while water succeeds.
This repair neither silently enables that option nor qualifies general
solute-bearing exfiltration.

## Diagnosis and repair

Original B1.11 completes both sequences. Before repair, current ordinary8-iteration
execution rejects water at day53 under1x;30 iterations finish1x but reject4x at
day69. Even64 iterations, a smaller minimum step and altered inner head/balance
criteria do not remove that4x rejection. Failures and generated probe sources
are retained, not omitted from the observation history.

After pond depletion, all nodes can retain positive pressure while top and bottom
both prescribe flux and net withdrawal requires desaturation. Physical saturated
storage has zero pressure derivative. The historical `dt*1e-7` pseudo-capacity
regularizes a matrix but supplies no real storage; reducing dt does not resolve
the pressure-offset degeneracy.

The [bounded contract](../science/PERF01_SATURATED_FLUX_RESTART.md) admits one
mass-guided **trial guess** after ordinary failure. The real MvG constitutive
provider brackets/bisects a uniform pressure translation; original frozen
conductivities are retained. The original Newton, surface and mass gates decide
acceptance again. No accepted-state correction, boundary law, equation, tolerance
or interface is changed. Ordinary successes and excluded variants retain their
original route. A tiny direct case demonstrates old rejection/new convergence;
another still rejects safely. This is not a universal saturation solver.

## Evidence and preservation

Fresh complete original/current O0/O2 builds,16 complete native applications,
three deterministic O2 repeats per arm/rain, identical O0/O2 physical totals,
and real midpoint48-day restart checks are retained. Both restarted final
`state.csv`, `endpoint.csv`, `restart.bin` are byte-identical to uninterrupted
execution; all remaining49 daily budget rows match exactly.

The existing21-provider typed controls run unmodified at O0/O2, including
warm-start/retry/desaturation/top derivative. The new small production contract
compares a freshly built exact predecessor and current implementation, checks
unchanged trial origins and hard mass, and verifies byte-exact excluded-provider
behaviour. Original FSI35 native rollback, worker isolation, surface and dispatch
oracles run at both optimization levels. Source-owner admission is separate.

The full predecessor owner and all147 predecessor corruption controls were
actually replayed at exact710b4173. Concurrent PR1387 adds an independent NUT
caller, not a change in the194-provider water application closure. Its complete
owner and163 controls were additionally replayed at exact188f75ef. These
results are retained as historical evidence,
not relabelled as fresh-current whole NUT execution. Successful old paths are
inherited under an exact insertion-only failed-solve refinement; the changed path
has new independent native coverage. Existing assertion bodies remain intact
behind exact successor dispatch. A stale three-row FSI35 predecessor-to-base
registration was encountered; the new exact source table is registered against
the qualified current source and original native replay, not by changing old
historical identities or assertions.

No full MC-SOL01/MC-NUT01 or frozen master-row promotion, broad F-CI, highest
low-air, RossFast expansion or new1e-6 temporal run is claimed or selected.
The general formulation around the soil surface remains future scientific work.
