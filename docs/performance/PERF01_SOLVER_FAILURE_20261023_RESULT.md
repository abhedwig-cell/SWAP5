# Native solver work and water/flux accuracy research

Research on canonical3461a520, reconciled through779224e5. The current checked
O0/O2 native Boesten-capable build supplies193 verified reusable objects. Every
executed input and reused artifact is checked. Production sources, application,
interfaces, defaults and restart schemas remain unchanged. Generated research
executables exercise the existing four-cell30cm, zero-tracer, simple-crop/ETref
97-day1x/4x fixture. These are native process timings after input preparation.

## Why early solver rejection does not fix the main cost

The passive nonlinear observer preserves all physical output bytes. At O2 the
failed nonlinear phases take0.0189/0.0286s,4.1%/5.1% of timed nonlinear phase
work. Successful phases take0.4475/0.5361s. This is distinct from PR1398's69%/76%
native time in rejected transactions: a transaction can discard three fully
converged solves because their time-discretization error is too large.

Successful solves include2,601/7,123 phases that recover after an exhausted,
nonimproving line search. A generated early-exit policy fails1x day18 and4x day7
at both O0/O2. Its modified HeadCalc also runs during the application's ordinary
day retry. This is not a test of restoring the original HeadCalc for that retry.
All four failed complete joint generations equal separately reconstructed last
completed-day restart bytes. The early-exit policy is rejected, with raw failures
retained. Returning earlier is not equivalent to the original nonlinear solve.

The passive temporal observer also preserves every physical byte. Every temporal
rejection is dominated by pressure head:

| Original proposal assessment | 1x | 4x |
| --- | ---: | ---: |
| Full/two-half assessments |18,249|20,687|
| Temporal rejects, all head-dominated |13,459|16,460|
| Rejected, water L1 plus pond difference below0.01mm |10,817|12,915|
| Rejected, water/pond state exactly identical |611|1,285|

The water L1 observation is `sum(abs(theta_full-theta_half)*dz)` plus absolute
pond-storage difference. It detects redistribution as well as total storage.
These observations alone do not establish a new acceptance rule.

## Changed-accuracy experiments

A generated water-only metric uses that storage-depth difference with a0.001cm
budget and the existing groundwater-head guard. Every finite/domain, solver and
hard mass gate remains. It cuts base O2 native medians from0.753 to0.0438s at1x
and0.751 to0.0229s at4x, with O0/O2 identity and actual day48 restart. Base water,
runoff and total evaporation/transpiration criteria pass. This changes the
accuracy metric; it is not an implementation-only speedup or accuracy-matched
comparison to4.3.1.

An independently declared synthetic root discriminator enables substep empirical
oxygen stress, sets h2=-10cm, h3l/h3h=-25/-50cm and h4=-400cm. The incumbent has
18/6 drought days and80/91 oxygen-stress days. This is the existing lightweight
empirical route, not the retired highest-low-air suite. The water-only metric
fails the declared0.01mm daily criterion: maximum runoff difference0.0734/0.0417mm,
storage0.0374/0.0376mm and transpiration0.0925/0.0485mm. All balances still close.
Thus total-water closure alone is insufficient to control plant response.

The final generated prototype uses separate budgets:

- water-state L1 plus pond:0.001cm;
- full/two-half root-uptake integral difference divided by trial duration:
  0.001cm/day;
- full/two-half total external water-output difference divided by trial duration:
  0.001cm/day.

The root and export rate errors are normalized by their own rate budget before
combining with the storage-depth budget. The identical numerical budget values
allow the prototype's direct maximum. This does not assert common physical units.
The original groundwater guard is retained. Unavailable root metadata rejects.
The first metadata attempt correctly rejects day1: the incumbent generic result
does not publish native plain/empirical uptake. A generated one-line backend
projection exposes the existing real `sum(qrot)*dt`, without changing any sink.

An intermediate version divided the state error by dt as well. Its1x native time
increased0.572 to0.819s;4x fell0.658 to0.454s. That additional state-rate requirement
is not selected. Both it and the water-only counterexample remain evidence.

Three alternating O2 pairs for the final separate-budget prototype:

| Fixture | Rain | Incumbent native, s | Prototype native, s | Ratio |
| --- | --- | ---: | ---: | ---: |
| Base |1x|0.771|0.0332|23.3x |
| Base |4x|0.672|0.0193|34.9x |
| Active root stress |1x|0.358|0.0456|7.85x |
| Active root stress |4x|0.253|0.0259|9.76x |

Host variation is visible between cohorts. Compare paired arms within each row.
Python preparation/publication is outside these native timings; the earlier
approximately0.15s envelope has not been remeasured with this prototype. The
prototype has no production front-end option. No end-to-end or regional speed
guarantee follows.

## Water, crop and state qualification

All declared final base and active-root criteria pass at O0/O2. Actual32 midpoint
continuations across the selected studies reproduce complete state/endpoint/
restart bytes and every remaining daily budget. The final daily-state supplement
relinks the actual selected transaction and backend objects; its physical outputs
exactly equal the ordinary timed runs.

| Final active-root difference | 1x | 4x |
| --- | ---: | ---: |
| Maximum daily runoff, mm |0.005111|0.002585|
| Seasonal runoff, mm |+0.007682|-0.000815|
| Maximum daily storage, mm |0.006106|0.004930|
| Maximum daily transpiration, mm |0.006106|0.004930|
| Seasonal transpiration, mm |-0.012785|-0.004115|
| Maximum daily head difference, cm |0.15335|0.15335|

Independent original daily rain/bottom reconstruction closes below7.7e-13mm
across retained scientific daily budgets. Base runoff differs by zero/0.002480mm
per day. Maximum daily base head difference is2.203/0.1538cm, while maximum theta
difference stays below1.39e-4. Total evaporation agrees to rounding, but separate
soil/pond allocation can shift up to0.6624mm/day and0.8991mm seasonally. The
generic export guard does not separately bound these two evaporation components.
That limit, coarse mesh, zero tracer and bounded root/crop configuration remain
explicit. No general global-error, positive-solute, seasonal or detailed-rain
policy qualification is inferred.

## Recoverability and admission scope

`PERF01_SOLVER_FAILURE_20261023_STATUS.json` owns the recovery point and sealed
raw evidence under `benchmarks/performance`. `seal_perf01_solver_failure.py`
reconstructs physical criteria, median timings, the negative outcomes, original
forcing closure, generated source projections and ten corruption controls.
The scientific stages contain184 native processes, including four expected early
policy failures and four successful rejected-generation prefix reconstructions,
plus60 compile/link events. Intermediate development command failures do not
qualify additional cases. The current native/NUT owner and52 controls pass.
Concurrent NUT demand-candidate and accepted-trace FCT changes are preserved;
their production delta lies outside this measured native closure.

This unit qualifies a reproducible research prototype. A production numerical
option still needs typed geometry/metric contracts, explicit caller eligibility,
input validation and its owning preservation/admission proof. The generated
application-global geometry binding is not a production API. Full Reference
remains available. No1e-6 run, RossFast expansion, highest-low-air or unrelated
full F-CI was selected. Invariants2,5,7,13,23,24,26 are preserved in production.
