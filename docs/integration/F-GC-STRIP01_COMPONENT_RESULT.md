# STRIP01 real SWAP component and short coupling results

Research only, 2026-10-02. A/B remain qualified. C is partial; D/E are not
qualified. No canonical admission, paper claim, production ABI change or
production ownership change. Runs were local; this session dispatched no Actions.

## Physical and numerical scope

See [frozen domain specification](F-GC-STRIP01_RESEARCH_DOMAIN.md). Real FMR
Reference Richards solves occupy 0 to -6 m; confined MODFLOW occupies -6 to
-10 m, T=2 m2/d, Ss=1e-5 /m. Fifty identical B01 sand columns receive 1 mm/d.
The sole lateral sink is a MODFLOW DRN in cell 1, stage -5 m, C=100 m2/d.
SWAP has no independent lateral sink. Fixed-plane head materialization is
used; no equation equating SWAP phreatic GWL with MODFLOW head is imposed.

The first zero-elasticity SWAP model retains the default timestep-dependent
saturated numerical capacity. A separately preregistered physical variant
uses the existing elasticity provider, Ss=1e-5 /m in SWAP saturated cells.
SWAP then owns compression and water-table storage above -6 m; MODFLOW owns
compression below it. Their domains are disjoint. The SWAP profile is initially
hydrostatic at -4.5 m; an additional equilibrium-start diagnostic uses -5 m,
equal to drain stage, to remove the abrupt initial drainage load. This
additional case does not erase or qualify the failed -4.5 m case.

Mass tolerance remains 1e-12 cm within SWAP, temporal head budget 1e-5 cm,
retry ceiling 8, committed substep ceiling 32. Research outer maximum 40,
interface rate tolerance 1e-10 m3/d/cell, combined volume tolerance 1e-8 m3/window.
No threshold was widened. All comparisons below use the final source panel.

## Component falsification

| Case | Outcome | Interpretation |
| --- | --- | --- |
| Hydrostatic, no rain, fixed head -4.5 m, dt=1e-4 d | PASS, 50 identical columns | Mass, immutable trial origin, exact replay and one commit |
| Rain 1 mm/d, no physical elasticity, dt=1e-4/1e-3/1e-2 d | FAIL | Nine temporal rejections each; zero nonlinear or mass rejections |
| Rain, initial/interface head shifted to -4.55 m | FAIL | Exact h=0 at an initial node is not sufficient to explain failure |
| No rain, interface lowered by 1e-6 m | FAIL | Changed-bottom-head case also exhibits nonlinear rejections |
| Rain, fully unsaturated head -6.5 m, dt=1e-7 d | PASS | Diagnostic outside the confined-aquifer domain; not a replacement C case |
| Physical SWAP elasticity, rain, dt=1e-4/1e-3/1e-2 d | FAIL | Temporal head bounds reduced but still exceed unchanged budget |
| Physical SWAP elasticity, rain, dt=3e-6 d, head -4.5 or -5 m | PASS | Small accepted component windows, exact replay and commit |

Failed component trials were also repeated from the same origin: identical
failure outputs and unchanged committed physical state were checked. A pass
in the unsaturated control does not authorize an aquifer head below -6 m.

### Source-supported temporal diagnosis

`src/solver/mod_b110_default_mvg_provider.f90`, b110_moiscap, sets saturated
capacity C=dt*1e-7 /cm without physical elasticity. The temporal indicator in
`src/solver/mod_reference_richards_temporal_indicator.f90` computes a bounded
M norm and converts it to an infinity head bound by dividing by
sqrt(min(C*dz)). Saturated cells therefore make the conversion increasingly
ill-conditioned as dt decreases. This is a source-supported explanation of
indicator scaling, not proof that the actual temporal solution error exceeds
the budget or proof that the indicator is mathematically incorrect.

At the last rejected attempt, head bounds for requested windows 1e-4, 1e-3,
1e-2 d are 0.43977995, 1.39070626, 4.39779789 cm respectively: approximately
sqrt(dt) scaling. With physical elasticity they are 2.74862469e-4,
2.74862459e-3, 2.74862368e-2 cm: approximately linear scaling. The unchanged
budget is 1e-5 cm. Accepted physical-elasticity startup dt=3e-6 d is an
exploratory smaller-window result, not retrospective qualification of the
frozen failed panel. The reproducible plot is
`integration/f-gc/strip01/research/startup_temporal.svg`.

## Real coupled experiments and combined balance

The harness uses the existing prepared-solve session and ctypes API publisher.
Every SWAP corrector starts from a captured committed origin. MODFLOW finalizes
once only after convergence and candidate availability; SWAP then commits
once. The outer numerical initial secant is -0.01 m2/d and has no physical
storage interpretation. It has not been qualified for substantial head changes.

The -4.5 m initial case fails at the first MODFLOW-corrected SWAP trial.
MODFLOW moves cell 1 to -4.93436884 m and cell 2 to -4.55077503 m; SWAP then
records nine nonlinear rejections. This is a real coupled failure with a
poorly qualified startup predictor and an abrupt drain load, not a proven
MODFLOW defect. Inputs, corrected heads, original heads and logs are retained.

At equilibrium start -5 m, four windows of 3e-6 d pass, total duration
1.2e-5 d (about 1.04 seconds). Combined water balance in this restricted case:

P - Q_DRAIN = delta S_SWAP + delta S_MF.

P is inward top flux integrated over fifty 1 m2 footprints. SWAP storage
includes soil water and ponded water, including its physical compression in
the elastic variant. MF confined compression is Ss*4m*sum(delta H)*1m2.
Interface bottom exchange leaves SWAP and enters the API package; it cancels
in the combined balance. There is no interface physical storage and no Sy in MF.

- Total rain: 6.000000000000001e-7 m3.
- SWAP storage increase: 5.999999928008037e-7 m3.
- MF storage increase: 7.076899066760235e-15 m3.
- Drain outflow: 2.600245352368802e-15 m3, essentially zero here.
- Maximum combined per-window closure residual: 1.2206896865355223e-15 m3.
- Maximum interface rate residual: 4.476197190689445e-14 m3/d/cell.

Trial state identity, accepted-origin flux replay and exactly one revision
increment per column/window pass. This is only a short smoke test. Almost
all rain remains in SWAP; it does **not** demonstrate far-cell-to-drain transit,
a developed mound or useful wet/dry response.

Extending after the fine startup window to dt=1e-4 d accepts two windows but
fails in window 2 (zero-based), corrected trial in column 2, with 170 nonlinear
rejections over 202 attempts and the 32 committed-substep ceiling. Last
indicator is below budget, so this failure cannot be classified solely as a
temporal rejection. Extending instead to dt=0.01 d fails in window 1 before
its first groundwater correction, with mixed nonlinear/temporal rejection.
Partial accepted records remain diagnostic; no completed-period qualification
or full-run water closure is claimed for failed extensions.

## Implementation repairs and evidence integrity

The historical F-GC46 build manifest lacks later module dependencies. The
research builder resolves source USE dependencies without editing that gate.
Research initialization supplies the actual top-flux provider and prepared
MvG parameters, including the existing elasticity preparation contract. The
initial elasticity attempt omitted preparation and was rejected before solve;
this research glue error was repaired, rather than weakening admission checks.
The final complete panel was rerun with the repaired glue. Initial intermediate
experiment failures remain separately identified in the record; qualification
uses the final hashed source manifest and final panel only.

Native sources are unmodified. The grid stub supplies geometry/legacy bindings;
constitutive evaluation and Richards trials use real production providers and
backend. The linked Bartholomeus object emits an executable-stack linker
warning retained in the build log; no deployment/security claim is made here.

Archive `integration/f-gc/strip01/evidence/research_C_20261002.tar.gz` contains
all final panel commands, logs, component JSON, native MF inputs/listings,
heads/budgets, partial failed records and source SHA256 manifest. Archive SHA256:
`80a5bdbf50e135d9eb5fd96f565c0435a1b033f8420ab9ceb37b3ac0a1be7b3e`.
The failed cases exit nonzero; the panel runner checks those expected outcomes
and labels its overall output as execution, not full qualification.

```bash
python tests/fgc/strip01/build_research.py --compiler /path/to/gfortran --output /tmp/strip01-build
python tests/fgc/strip01/run_research_panel.py --swap-library /tmp/strip01-build/libstrip01_swap.so --mf-library /path/to/libmf6.so --output /tmp/strip01-panel
python tests/fgc/strip01/analyze_research.py --results /tmp/strip01-panel --output /tmp/strip01-analysis
```

Environment: GNU Fortran 13, MODFLOW6 6.8.0, FloPy 3.9.5, xmipy 1.5.0,
bmipy 2.0.1, Python 3.12.14. No engine binaries are committed. The independent
phase-A oracle, native A/B evidence and their tolerances remain unchanged.

## Remaining qualification work

The next substantive step is a separate component oracle comparing actual
head/flux trajectories under changing interface head across timestep refinement,
plus nonlinear stagnation/residual diagnostics. This must distinguish a loose
indicator bound, roundoff-sensitive stopping rule and genuine trajectory error
before a shared numerical repair or different temporal route is justified.
The research initial secant also needs a derivative or safeguarded predictor
qualification for substantial initial drainage. Do not increase tolerances,
retry/substep ceilings or fit elasticity solely to obtain a green test.

A physically long phase C, far-cell lateral transport, Hupsel forcing, accepted
window convergence, restart continuation and physically interpretable head/GWL
separation remain unqualified. D/E are deferred under the user's phase-order
requirement. These negative findings are candidates for later numerical/coupling
work; this unit is not closed and not admitted to canonical governance.


Subsequent qualification: [stationary route, numerical refinement and bounded dry-day result](F-GC-STRIP01_REFINEMENT_RESULT.md). The original configuration failures above remain preserved.
