# A27 evolving-column reverse-exchange attribution result

Date: 2026-10-01
Status: LOCALLY_TESTED_BOUNDED_MECHANISM_RESULT; full A27 remains OPEN
Canonical: 19f09b818b1bb30c1428919074c00098dbd062bd
Tested source postimage: c6c716e225a2673b498d617aa569327cec686034
Compiler: GNU Fortran 13.3.0, O2, fcheck=all.
Runner: tests/fpm/run_ppa_wu05a27_column_ablation.sh
No production source or shared contract changed. No Actions run requested.

## Experiment

See PPA_WU05A27_COLUMN_ABLATION_PREREGISTRATION.md and the persisted harness
for exact retention coefficients and geometry. 100 cm column, ten 10 cm cells,
cell centers 5..95 cm depth, interior center distances 10 cm, boundary distances
5 cm. Prescribed pressure-head bottom mode 5, h_bottom=water_table+100 cm.
Zero top flux. Initial hydrostatic heads h=water_table-z. Wet water table
-20 cm elevation, dry water table -200 cm elevation. Matrix Ks 1 or 5 cm/day;
horizontal exchange conductivity 0.1*Ks. One day; three fixed dt values
0.002, 0.001, 0.0005 day; trajectories sampled at 0.1 day intervals.

Reverse route on: standard saturated-exchange primitive, accepted-state-frozen
per step, maintained drained receiver at depth 100 cm, diameter 20 cm,
shape factor 0.1. Water is removed as a separately integrated preferential
receipt. Receiver is an external drainage boundary, not a finite closed IC
reservoir. The off experiment removes only this route.

Provider sink rates use cm/day per compartment, not volumetric rates:
sink_node = exchange_amount_node / dt.
This follows the actual Richards residual's unweighted sink term.
Cumulative external receipt integrates SUM(sink_node)*dt.

## Completed results

All 24 runs complete, with 240 output records.
At the finest timestep, one-day wet-case results are:

| Matrix Ks cm/day | Reverse receipt cm | Bottom inflow cm | Storage change cm | Max head departure cm |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.985522 | 0.778313 | -0.207209 | 13.140467 |
| 5 | 4.708547 | 4.081682 | -0.626865 | 15.526393 |

Off wet runs stay at the initial hydrostatic state with zero receipt and zero
bottom flux. Dry on/off cases do likewise. Therefore the on/off pressure-head
difference equals the reported departure for these exact controls.

Whole-column gate at every accepted step:
    storage - initial_storage - cumulative_bottom_inflow + cumulative_reverse_receipt
has magnitude at most 1e-7 cm (otherwise the runner stops).
Maximum emitted solver integrated mass residual: 1.754e-15 cm.

The exchange modifies both flow and matrix states. Similar storage totals would
miss most of its effect here: fixed groundwater replenishes 0.778 and 4.082 cm.
These are illustrative boundary-supported cases, not predictions for a closed
soil column or measured field sites. No rainfall was applied.

## Refinement

Absolute differences between coarse/medium and medium/fine one-day runs:

| Ks | Observable | coarse-medium | medium-fine |
| --- | --- | ---: | ---: |
| 1 | receipt cm | 0.000210075 | 0.000105023 |
| 1 | storage cm | 0.000055309 | 0.000027640 |
| 1 | max head departure cm | 0.000364771 | 0.000182253 |
| 5 | receipt cm | 0.001085550 | 0.000542532 |
| 5 | storage cm | 0.000058940 | 0.000029943 |
| 5 | max head departure cm | 0.000603658 | 0.000304157 |

Discrepancies contract approximately by two, consistent with this explicit
first-order process split. This is actual evolving-column refinement, unlike
the previous frozen-state directional sweep. It is not refinement evidence for
the complete standard corrector or RFM runtime.

## Interpretation and production advice

The omitted mechanism can produce material preferential receipts and head
changes in an unponded wet column. Its absence cannot be assumed harmless
merely because mass conservation or end storage looks satisfactory.

Retain the exclusion of matrix-fed preferential drainage from any claimed RFM
replacement envelope. This is an explained model-form difference, not an
unexplained E3 or proof that standard SWAP is universally ground truth.
The direction follows the saturated hydraulic gradient and the experiment
uses the production standard exchange primitive.

A dry control demonstrates negligible reverse exchange in this experiment;
it does NOT qualify full RFM equivalence for dry rainfall cases.
A finite isolated IC reservoir may equilibrate and reduce the effect.
Quantifying that is a separate case, not supported by these drained-receiver
numbers. MB passage-wall differences remain another independent model boundary.

There is no RFM performance/stability claim. CPU diagnostics in the CSV are
not repeated wall-clock benchmark timings. Solver counters describe the
attribution runs only and cannot compare complete runtimes.

## Negative harness evidence

Earlier local attempts are invalid for hydrologic interpretation:
- inherited bottom mode 7 was free drainage instead of prescribed head;
- bottom head/face geometry needed alignment;
- an initial volumetric conversion divided areic sink by dz.
The wet baseline failed under the mistaken free-drainage configuration.
All these test-harness defects were repaired in the persisted tested postimage;
no physical parameter was fitted to obtain equivalence. Earlier outputs are
not mixed into the final evidence.

## Evidence and remaining work

Raw trajectories/counters: evidence/PPA_WU05A27_COLUMN_ABLATION.csv.
One-day summary: evidence/PPA_WU05A27_COLUMN_ABLATION_SUMMARY.csv.
Prior directional proof: PPA_WU05A27_RESULT.md.

Next: complete same-physics-description standard/RFM parameter mapping and
evolving A/B/C production-runtime harness; include finite IC storage and
rainfall-event cases. Run repeated wall-clock and worker-scaling benchmarks
only after the physical cases and unsupported-envelope classification exist.
Full A27 preregistered deliverables remain incomplete. This result does not
authorize changes to admitted RFM physics or a canonical admission.
