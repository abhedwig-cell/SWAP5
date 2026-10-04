# PPA-WU05-A28 field-depth solver iteration-budget probe

Date: 2026-10-04. Status: preregistered bounded exact-only diagnostic.

## Question and decision boundary

The frozen 10-node/100-cm exact fixed-64 prescribed-qbot predictor at `h0=-45 cm`, `dt=0.01 day`, `rain=1 cm/day` fails after 16/16 nonlinear iterations. A build-local diagnostic measured first-failed-attempt compartment balance residual `1.1446891872597525e-12 cm` against `1e-12 cm`, and absolute total balance `1.8374766524616952e-12 cm` against `1e-12 cm`; typed-bottom invalidation was false. This supports one narrow hypothesis: the bounded fixture iteration budget, rather than the mass-balance tolerance itself, prevents a candidate from converging.

Run one fresh-process exact fixed-64 predictor initialization at the identical input, changing only the test-bridge maximum nonlinear iterations from 16 to 32. The setting is an experiment-only qualification-fixture control. Production sources, physical parameters, initial state, forcing, qbot perturbation sizes, timestep, solver tolerances, backtracking limit, RFM policy, and coupling contract remain unchanged. Do not run MODFLOW or A28.

## Frozen pass/fail rules

- PASS only if predictor initialization completes all plus/minus centered-FD trials and response composition, all trial mass closures and transaction checks pass, and no solver retry exhaustion occurs.
- FAIL if any plus/minus trial remains incomplete, retries exhaust, or response composition/finite gates fail. Record the terminal diagnostic and stop; do not increase to 64, alter tolerances, change forcing/timestep, or run A28.
- An initialization PASS is only permission to proceed to a separately scoped predictor qualification review. It does not qualify centered-FD sensitivity, coupled exact correctness, or approximate A28 use by itself.

## Evidence and scope

Record the exact branch/head, generated bridge hash, run and artifact IDs, iteration limit, plus/minus terminal heads and derivatives if available, per-trial transaction status/retries/rejections/mass closure, accepted-state checks, discard/replay results, and response-composition gates. The predictor test remains exact fixed-64 and predictor-only. No production code or defaults may be changed for this experiment.
