# Explained: 2.706810392011cm runon/hysteresis groundwater difference

## Decision

The maximum is a **time-discretization effect at the short fixed surface
irrigation on day5**, not the later runon pulse or day199 restart defect. The
SWAP5 Newton pond derivative permits large converged steps which original431
rejects for nonlinear nonconvergence. Convergence and exact mass conservation
do not establish time accuracy. Do not restore the incomplete derivative or
weaken a mass guard to reproduce the old result. No production change is made.
The original-input scientific comparison remains NOT_QUALIFIED.

## First divergence and causal localization

The archived literal-input full trajectories have identical initial CSV state.
Their first accepted step is the same0.0002day, ending17.28seconds after start.
Its GWL differs by1.06533e-9cm and its water stock by about5.1e-12cm. The actual
source includes SWAP5's additional Newton mass polishing and unchanged strict
guard. The following step is0.0002day in SWAP5 and0.0004day in original431:
their adaptive grids have already separated. At day1 end GWL differs by
0.000456289042cm. This tiny first difference must not be confused with the
material maximum.

The maximum appears on2002-01-05, day5: surface irrigation24mm supplied at
12mm/hour, lasting two hours. Both models use exactly28.8cm/day during the
pulse and2.4cm integrated input; missing water or a different irrigation rate
is ruled out. On that day SWAP5 has0.190725404235cm runoff, original431 zero.
The storage difference-0.122125309420cm plus drainage difference
-0.068532590508cm accounts for that runoff to the original numerical residual.
Runon starts later; day199 history cannot cause a difference on day5.

Accepted-step traces are diagnostic-only, with explicit source/executable
hashes. Their daily CSVs are exactly unchanged from uninstrumented executions.
Fresh current-source O0/O2 five-day prefixes also match the archived admitted
prefix exactly despite the subsequently admitted, inactive frost extension.

The decisive original431 counterfactual changes **only the Newton derivative**
of the existing implicit linear pond/runoff relation, using the same analytic
expression as SWAP5. It changes no residual equation, forcing, date, parameter,
convergence tolerance or physical process. Both original counterfactual runs
have exactly identical day0-through-day4 CSV rows.

| First attempts at start of day5 | Original derivative | Exact pond derivative |
|---|---|---|
| dt=0.04day (57.6min) | Rejected: nonlinear nonconvergence | Accepted |
| dt=0.013333333333day | Rejected | Not needed at that instant |
| dt=0.004444444444day | Rejected | Not needed at that instant |
| dt=0.001481481481day (2.133min) | Accepted | Not needed at that instant |

With the exact derivative, original431 itself develops0.223887082113cm runoff
and day5 GWL-47.332385693797cm, versus-44.789135257493cm with its old derivative.
That2.543250436304cm displacement explains about94% of the original2.70681cm
gap by a derivative-only intervention, with the first four days held exact.
The old solver's rejected steps were providing incidental temporal refinement.
The remaining difference in this coarse counterfactual is not claimed exact:
SWAP5 retains additional mass polishing and the pond small-flux correction.

## Short matched temporal refinements

All comparisons below stop after five days. The nominal shortened original run
is byte-exact in every CSV row to the first five days of its archived complete
literal-input run. Diagnostic DTMAX changes are applied explicitly to both
models; they are not relabelled identical original input or new release defaults.

| DTMAX, days | Original431 day5 GWL,cm | SWAP5 day5 GWL,cm | SWAP5 minus original,cm |
|---|---:|---:|---:|
| 0.04 | -44.789135257493 | -47.495945649504 | -2.706810392011 |
| 0.004 | -44.917478156679 | -45.047957421163 | -0.130479264484 |
| 0.0004 | -44.887547670654 | -44.872190917562 | +0.015356753092 |
| 0.00004 | -44.911456579571 | -44.910273943962 | +0.001182635609 |

Every refined SWAP5 endpoint is identical between O0 and O2. Refined runs have
zero day5 runoff in both models. The finest observed difference is99.9563%
smaller than the nominal gap. This is convergence evidence for the causal
classification, not a mathematically established limit or a scientific PASS.
The sign changes at an intermediate grid and no Richardson order is asserted.
The remaining0.00118cm is retained, not rounded to zero.

No water/solute guard or scientific criterion is relaxed. All actual SWAP5
daily mass checks use their existing1e-10 bounds. Original431 results retain
their own nonzero balance residuals; they are not qualified against SWAP5's
strict mass contract. Original oxygen/reference/nominal-runon failures remain
unchanged. Only the water variant is reexecuted for this groundwater cause;
no new chemical qualification follows from the shared earlier trajectory.

All physical trials last five days; the slowest refinement model run took
6.58seconds. Four-day/year/full periods were not repeated. Compiler work is
separately bound to each recorded build/command and is not model runtime.

## Identity and evidence

Actual canonical baseline:0f12c639da5c4dadf488282dc8e110d2a8ad1874.
Fresh O0/O2 runtime builds/executions were persisted at3dea7cc74; no src/app/
reference/tools change is introduced on this branch. The preceding admitted
pond repair is PR1694/fec7b4415. The exact old input/CSV dependencies were
checked against22 immutable member hashes from supplementary audit68e74d5ac.
The original executable SHA256 is
499b5d9c72a908af9282f5479a5b93e4488da5019620f9252c3117786cbca8a3.

RESULT.json, TRACE.json, SWAP5_TRACE.json, SWAP5_REFINEMENT.json, FINEST.json and
TANGENT_COUNTERFACTUAL.json preserve observations, endpoints, guards, commands
and identities. RAW.json/RAW.zip seal raw sources, inputs, outputs, complete
accepted-step and rejection witnesses and their hashes. Compiler objects,
modules and executables are omitted from redistribution, with identities in
the corresponding metadata. Private diagnostic binaries never publish or
rebind a production checkpoint and are not production B1 successors.

## Reproduce and next decision

Recover the old supplementary audit RAW.zip at exact commit68e74d5ac into
C:/SWAP5-testing/pondmx-canonical-audit01 and retain its manifest. Use the exact
source/compiler-validated C:/SWAP5-RC2/provider. Begin with a fresh output root.
With C:/msys64/ucrt64/bin on PATH, run these persisted scripts in order:

```powershell
python -B tests/runon_gwl/refine.py
python -B tests/runon_gwl/trace_reference.py
python -B tests/runon_gwl/trace_swap5.py
python -B tests/runon_gwl/refine_swap5.py
python -B tests/runon_gwl/finest.py
python -B tests/runon_gwl/tangent_counterfactual.py
```

The requested explanatory work package is complete. If lower cost and temporal
accuracy for short pulses are selected next, the concrete implementation target
is an explicit event-local temporal-accuracy policy that detects this under-
resolved pulse, with original equations, balances, restart and runtime checks.
It must be assessed against the measured refinement sequence. A globally
1000-times-smaller DTMAX, a return to the incomplete tangent, or an untested
silent event cap is not admitted by this investigation. No tolerance or default
is changed, and full scientific equivalence remains open.
