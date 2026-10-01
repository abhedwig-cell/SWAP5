# A27 finite receiver and two-way split result

Date: 2026-10-01
Status: LOCALLY_TESTED_RESEARCH_RESULT; NOT_PRODUCTION_ADMITTED
Tested postimage: b09568352f022eb43bd0b20f36db10485b299046
Current canonical reconciled: 44c6df02a58edee79f88dde8ca8aadbec26337fc
Compiler: GNU Fortran 13.3.0, O2, fcheck=all.
Runner: tests/fpm/run_ppa_wu05a27_finite_exchange.sh.
54 runs completed, 540 trajectory records. No Actions requested.

## Scope

Exact geometry and experiment: PPA_WU05A27_FINITE_EXCHANGE_PREREGISTRATION.md.
This is a research composition of the production Reference Richards solver
and the production standard saturated-exchange primitive with explicit
receiver geometry. It is NOT the full RFM runtime or standard corrector.
Mode field reverse_on: 0 omitted; 1 matrix-to-macro only; 2 signed two-way.
Case wet: 0 dry/empty; 1 wet/empty; 2 wet/initial storage 4 cm.
Receiver capacity 5 cm; area 0.05; level=-100+W/0.05.
At t=0.5 day bottom head changes from +80 to +40 cm for wet cases.

Conservative split uses accepted-state matrix/receiver heads, compartment
donor limits and receiver bounds. Trial amounts are passed as areic source/sink
rates into Richards. The identical signed amount changes receiver storage
only after successful matrix solve. There is no production rollback,
retry, restart, parallel execution or nonlinear-corrector claim.

Current canonical delta since previous reconciliation only changes q(gwl)
and serialized dispatch; the direct mode-5 Richards fixture dependencies
remain unchanged. This experiment runs the pinned A27 postimage; it does not
claim a new canonical production postimage.

## Results at dt=0.0005 day

| Ks cm/day | Initial receiver | Mode | Receiver change cm | Receiver end cm | Matrix storage change cm |
| --- | --- | --- | ---: | ---: | ---: |
| 1 | empty | omitted | 0 | 0 | -0.203765 |
| 1 | empty | matrix-to-macro only | 0.697245 | 0.697245 | -0.349870 |
| 1 | empty | two-way | 0.697245 | 0.697245 | -0.349870 |
| 5 | empty | omitted | 0 | 0 | -0.802042 |
| 5 | empty | matrix-to-macro only | 2.247002 | 2.247002 | -1.098259 |
| 5 | empty | two-way | 2.240500 | 2.240500 | -1.097410 |
| 1 | 4 cm | omitted / matrix-to-macro only | 0 | 4 | -0.203765 |
| 1 | 4 cm | two-way | -0.199675 | 3.800325 | -0.134724 |
| 5 | 4 cm | omitted / matrix-to-macro only | 0 | 4 | -0.802042 |
| 5 | 4 cm | two-way | -0.785214 | 3.214786 | -0.604380 |

All dry cases have zero exchange and zero state change.
Positive receiver change is uptake from matrix; negative is release to matrix.
Thus the filled-receiver recession tests demonstrate 1.997 and 7.852 mm
release in half a day. Empty-receiver tests show net uptake of 6.972 and
22.405 mm over the day in the two-way route.

These are illustrative controlled geometries and maintained groundwater
boundaries, not field-site estimates. Rainfall intake, MB routing, unsaturated
wall absorption and the complete RFM endpoint configuration are absent.
Do not use these numbers to predict full-runtime differences.

## Conservation and refinement

Every accepted interval passes independent combined matrix+receiver ledger:
    matrix_storage_change + receiver_storage_change - cumulative_bottom_inflow
within 1e-7 cm. The largest emitted solver residual is 2.465e-15 cm.
Recorded receiver storage stays 0..4 cm, within capacity 5 cm.
Bounds are asserted at every step, but no run reaches capacity 5 cm:
active capacity-limiter stress qualification remains outstanding.

Successive one-day receiver discrepancies for two-way cases:
| Ks | Initial receiver | coarse-medium cm | medium-fine cm |
| --- | --- | ---: | ---: |
| 1 | empty | 0.000652965 | 0.000326163 |
| 5 | empty | 0.002238377 | 0.001118799 |
| 1 | 4 cm | 0.000265433 | 0.000132672 |
| 5 | 4 cm | 0.000573814 | 0.000298634 |

All nonzero discrepancies contract approximately by two. This supports
first-order split convergence for this tested experiment, not universal
stability for nonlinear RFM/Richards coupling.

## Decision

Finite storage does not remove the physical need for signed exchange across
the tested wet filling/recession cycle. An RFM envelope intended to cover
such a cycle should represent both directions. This supports a conservative
two-way split as a research implementation candidate before considering
a monolithic nonlinear solver.

It does not establish that a two-way RFM implementation is completed,
qualified or faster. The old production route is unchanged.
A27 full paired benchmark remains OPEN.

## Recommended next implementation contract

Keep surface intake, receiver exchange and MB deep receipt separate.
For finite IC endpoints, compute signed hydraulic exchange from explicit
geometry and heads. Matrix loss must equal IC gain and conversely.
Retain donor/receiver bounds, accepted-state immutability, and whole-column
ledger. Bind losses as matrix sinks and gains as sources with the correct
areic/volumetric conversion at the owning solver seam.

Avoid appending an independent Darcy release to the existing Philip/Darcy
wall law: define branch selection first to prevent duplicate wall transfer.
Research fixture uses the standard saturated law and does not resolve that
RFM model-form decision. MB fast-through ownership remains unchanged.

Before production changes: persist a dedicated signed-exchange contract
covering saturation transition and receiver geometry, implementation gates,
active capacity and drying tests, retry/replay, restart, and full A/B/C
rainfall/recession comparison. These affect shared source/sink and ledger
semantics and must not be silently folded into a performance benchmark.
