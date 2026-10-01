# PPA-WU05-A12 result — active perched serialized FMR runtime

Date: 2026-10-01

Status: `BLOCKED_RUNTIME_ARCHITECTURE / ZERO_EXCHANGE_PREDICTOR_ERASES_TRANSIENT_PERCHED_TOPOLOGY`

Baseline: `research/ppa-wu05-a11-perched-zone-carrier@f0291d8c5c153417465a5bd8f464bd4a2fd88c33`

Canonical reconciliation point: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

Final falsification postimage: `a725ca0d2b4e12290414a2e3c373a62daa67d044`

## Decision

A12 does **not** qualify the A11 perched carrier for production runtime admission.

The A11 carrier itself remains qualified. The blocker is the current A8-style outer
predictor/corrector ordering:

1. the runtime initializes the matrix/macropore exchange overlay to zero;
2. it solves one full Reference-Richards predictor with zero macropore exchange;
3. only after that solve does it derive matrix saturated/perched topology and evaluate
   A6 macropore rates;
4. subsequent outer correctors therefore start from the predictor topology.

For transient perched water this ordering can remove the perched saturated lens before
`QInIntSat` is ever evaluated.

That is materially different from the exact B1.11 source path, where MACRORATE is called
from MACROPORE during nonlinear `headcalc` evaluation and the saturated/perched carrier
already exists from accepted-state MACROSTATE bookkeeping.

## Evidence

### Carrier/configuration path was not lost

A12 explicitly enabled:

- `perched_detection_enabled=.true.`;
- `critical_under_saturated_volume_cm=0.02`.

The configuration is copied into `fparams%macropore`, then into the serialized backend
model's `macropore_config`, and that exact rate template is passed to
`macropore_runtime%execute`.

Therefore the zero perched receipt is not caused by the A11 opt-in flag being dropped.

### Stable serialized runtime still erases the perched lens

Run `36836155603` completed the serialized transaction without temporal, mass or solver
rejections and with whole-column residual near machine precision.

The matrix candidate before any successful perched receipt was:

- H1 = `-8.2783491492510848 cm`;
- H2 = `-7.4296105458703270 cm`;
- H3 = `-7.0033168493124007 cm`;
- H4 = `-7.0980085874639629 cm`;
- stored groundwater level = `-2.0 cm`.

The initial test state had positive perched-lens heads above an unsaturated separator.
All candidate heads became negative in the zero-exchange predictor.

Observed result:

- `macropore_perched_exchange_active = false`;
- `macropore_perched_interflow_cm = 0`.

### Physically layered fixture gives the same structural result

Run `36836401286` used a localized low-conductivity layered profile and a shorter
`1e-4 d` interval. The transaction again completed with:

- temporal rejections = 0;
- mass rejections = 0;
- solver rejections = 0;
- mass residual = approximately `2.923e-16 cm`.

The resulting matrix candidate was:

- H1 = `-4.1705063513411140 cm`;
- H2 = `-3.1404780717433942 cm`;
- H3 = `-2.4767609479047978 cm`;
- H4 = `-2.5166502088784615 cm`;
- groundwater level carrier = `-2.0 cm`.

Again:

- perched active = false;
- perched interflow = zero.

Thus a numerically healthy serialized FMR transaction still reaches the first A11
rate evaluation only after the transient perched topology has disappeared.

## Explicitly falsified workarounds

The following routes were tested and rejected rather than promoted into production:

1. **Extremely small interval**
   - `fmr_dt=1e-7 d`;
   - produced about 1902 solver rejections;
   - not a viable production qualification route.

2. **Whole-column extremely low vertical conductivity**
   - produced about 2368 solver rejections;
   - creates an artificially stiff column rather than a useful perched test.

3. **Suppressing temporal subdivision only**
   - the transaction then completed cleanly but perched exchange remained zero.

4. **Changing the prescribed bottom head to match the nominal main groundwater state**
   - did not change the diagnostic matrix candidate;
   - not the controlling cause.

5. **Further fixture tuning**
   - deliberately stopped after the layered, no-retry falsification;
   - continuing to tune forcing or hydraulic parameters until one positive receipt appears
     would amount to qualification-by-fixture rather than demonstrating a robust runtime
     contract.

## Architecture interpretation

A11 proved that the exact 4.3.1 perched carrier and A6 `QInIntSat` composition can be
represented without new continuation state.

A12 shows that representation alone is insufficient in the current production runtime.

The present outer-coupling sequence is:

`zero-exchange Richards predictor -> derive macropore rates -> outer correctors`.

The exact legacy source integrates macropore rates inside nonlinear Richards evaluation.
For a state-dependent topology such as perched groundwater, these two orderings are not
generally equivalent.

A source-order-aware first exchange estimate could potentially seed the predictor from
the accepted matrix state, but that is a **new runtime coupling decision** and is outside
A12's preregistered scope. Moving perched/macropore physics into the inner nonlinear
Richards loop would be an even larger architecture change and is explicitly outside the
currently admitted A8-A10 envelope.

## Preservation

No A12 code is canonically admitted.

The current canonical A8/A9/A10 chain is unchanged.

A11 remains a qualified research/follow-up result for the source-faithful perched carrier.
Its qualification run `36834246991` remains valid because A12 has not falsified the
carrier equations or source map; it has falsified the current runtime ordering as a route
to active transient perched production admission.

The frozen Status-A denominator remains unchanged.

## Next safe step

Open a separate bounded architecture workunit before further production attempts.

The first question should be narrower than “move macropores into HeadCalc”:

> Can the existing outer-coupled runtime obtain a source-order-aware initial macropore
> exchange estimate from the accepted matrix state and use it to seed the first Richards
> solve, while preserving A8/A9/A10 mass, transaction, restart and convergence contracts?

Only if that route is qualified should active perched production admission be reopened.

If that seed cannot preserve the source semantics, the next decision boundary is an
explicit inner-Richards macropore coupling design. That must not be introduced silently
inside A12.
