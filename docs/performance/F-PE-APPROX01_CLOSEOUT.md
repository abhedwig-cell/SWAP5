# F-PE-APPROX01_CLOSEOUT — practical MultiSWAP tangent cadence

Date: 2026-09-26

Status: `CLOSED_WITH_QUALIFIED_OPT_IN`

PR:
`#629 — F-PE-APPROX01: practical MultiSWAP tangent cadence`

Branch:
`work/f-pe-approx01-tangent-cadence`

Stacked parent:
`F-PE-DIR01@584af6ce2e6e4a6cd2c790e6341805e56085127b`

## Purpose

APPROX01 opened the practical performance phase after exact directional optimization had reduced but not removed the production bottom-head tangent cost.

The workunit deliberately kept the physical SWAP solve exact and tested one approximation only:

reuse a recently accepted bottom-head coupling tangent within a bounded same-origin envelope.

## Why tangent reuse was selected

On the DIR01 postimage the production bottom-head directional route still cost roughly 73% more than the corresponding Reference solve.

Local exact-P0/P1 opportunities had become small or semantically invasive.

The tangent was therefore the clearest place to trade bounded derivative exactness for a much larger runtime reduction without approximating the physical Richards state itself.

## Lever01 fixed-cadence frontier

Exact physical solves were retained on every evaluation.

Only fresh tangent construction was skipped according to cadence.

Paired timing showed approximate median gains:

- lag-2: about 18-22%;
- lag-4: about 28-34%;
- lag-8: about 32-40%.

The physical solve checksum remained identical.

However, fixed cadence alone was rejected as the production rule because tangent error grew with bottom-head corrector amplitude.

## Material / regime error matrix

The qualified matrix covered:

- B01;
- B12;
- O05;
- O14;
- wet / mid / dry states.

The controlling case was consistently O05-wet.

At approximately ±0.5 cm bottom-head excursion:

- lag-2 worst relative tangent error: about 0.8%;
- lag-4/8 worst relative tangent error: about 1.6%.

For the same local sweep, the worst lag-4/8 bottom-flux linearization error was below about 0.8% of the actual flux excursion.

At larger excursions fixed cadence degraded:

- ±1 cm: lag-4 about 3.2% worst relative tangent error;
- ±2 cm: lag-4 about 6.6%.

## Adaptive frontier

The selected rule combines:

- maximum bottom-head displacement from the refresh head;
- maximum cache age.

Qualified research setting:

- head threshold: 0.5 cm;
- maximum age: 8 evaluations.

Across the tested amplitude frontier this rule gave approximately:

- ±0.5 cm: 83% tangent evaluations avoided;
- ±1 cm: 67% avoided;
- ±2 cm: 33% avoided.

The current worst relative tangent error remained about 1.65% or lower over the 4x3 material/regime matrix.

This dominated a universal fixed cadence as a practical rule.

## A1 production-shaped opt-in

A1 implements the adaptive tangent cache in the real FMR groundwater participant.

Properties:

- default OFF;
- explicit opt-in;
- exact physical SWAP solve on every trial;
- cache restricted to one captured origin and one coupling window;
- same lineage/revision required;
- head displacement <= 0.5 cm;
- bounded age;
- finite cached tangent required;
- invalidation on new origin, abandon, commit and failed/exchange-invalid trial paths.

Published trial responses explicitly report:

- fresh versus reused tangent provenance;
- reuse age;
- tangent refresh head.

A cached tangent is therefore never represented as a newly computed exact accepted-trajectory tangent.

## Participant-level performance

Three independent 20,000-trial production benchmarks on the final qualified implementation gave:

- approximately 20.72% speedup;
- approximately 22.51% speedup;
- approximately 21.04% speedup.

Median:

approximately 21.04%.

Each replica produced exactly:

- 2223 fresh tangents;
- 17777 reused tangents.

Physical exchange sums were identical between cached and fresh modes.

Lifecycle checks confirmed:

- first tangent after origin capture is fresh;
- bounded same-origin reuse occurs;
- recapturing an origin forces a fresh tangent;
- stale cache is not reused across the origin boundary.

## Default exact preservation

A1 infrastructure is default OFF.

Parent-vs-current FGC44 stable output is identical with the cache disabled.

The existing FGC44 production participant gate also passes after its compile dependency list was reconciled with the current production modules.

Therefore adding A1 does not change the exact default route.

## Real SWAP + MODFLOW6 end-to-end qualification

The live MODFLOW6 coupling gate was run independently three times.

Every replica produced exact equality between fresh-tangent and A1 mode for:

- final MODFLOW groundwater head;
- final SWAP groundwater exchange flux;
- cumulative accepted interface ledger exchange;
- coupled iteration count.

In each run:

- fresh tangents: 1;
- reused tangents: 3;
- coupled iterations: 2 in both modes.

Measured coupling-loop speedups:

- 21.45%;
- 21.94%;
- 11.13%.

Median:

approximately 21.45%.

Mean:

approximately 18.17%.

The coupling loop is sub-millisecond in this fixture, so the spread is treated as timing variance. The robust performance statement is that all three independent runs were speed-positive while the qualified coupled endpoint and accepted exchange remained exactly unchanged.

## Error interpretation

A1 does not guarantee zero tangent error.

The qualified local matrix shows a bounded derivative approximation, with O05-wet controlling the tested envelope.

The reason coupled endpoint error is zero in the current MODFLOW fixture is not that A1 is mathematically exact. It is that the bounded cached tangent was sufficiently accurate for the coupled iteration to converge to the same physical endpoint.

That distinction remains explicit.

## Admission status

A1 is qualified as a production-shaped practical-performance opt-in.

This does not make it canonical until the stacked parent chain is admitted.

The exact default remains authority.

## APPROX01 decision

APPROX01 has met its closure condition:

- one explicit approximate mode was identified;
- its speedup/error frontier was measured;
- it was implemented as opt-in and default OFF;
- default exact behavior is preserved;
- local derivative error is bounded in a declared envelope;
- participant runtime gain is material;
- live SWAP + MODFLOW6 coupled behavior was qualified.

No second approximation lever is added to APPROX01.

## Next workunit

Preregistered:

`F-PE-APPROX02 — practical Richards solve-effort frontier`

Preregistration:

`docs/performance/F-PE-APPROX02_PREREGISTRATION.md`

APPROX02 will measure how nonlinear convergence effort, balance tolerances and timestep/substep policy trade runtime against hydrological state, flux, cumulative exchange, mass balance and coupled groundwater response.

## Closure statement

F-PE-APPROX01 is closed with A1 retained as the first qualified production-shaped practical performance mode.

Planning interpretation:

- participant repeated same-origin gain: about 21%;
- replicated coupled-loop gain: all runs positive, median about 21%, with a wider 11-22% observed band due to very short wall-clock intervals;
- exact physical SWAP solve retained;
- exact default route retained;
- current bounded local tangent-error envelope: about <=1.65% over the tested adaptive material/regime frontier.

The performance program should now proceed to F-PE-APPROX02.
