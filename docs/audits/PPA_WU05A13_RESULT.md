# PPA-WU05-A13 result — accepted-state macropore seed

Date: 2026-10-01

Status: `CLOSED_FALSIFIED_ACCEPTED_STATE_SEED`

Baseline: `work/ppa-wu05-a12-fmr-perched-runtime@812496a6f73361849507c151d876d78b4cc3b4ab`

Canonical reconciliation point: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

## Question

Can the current outer-coupled macropore runtime preserve transient source-faithful perched
exchange by deriving one initial macropore exchange vector from the accepted matrix state
and using that vector to seed the first Reference-Richards solve?

## Dependency correction discovered

A13 re-read the exact 4.3.1 source and found that the first A11 translation used the wrong
top compartment.

Exact active B1.11 uses:

`ICpTpPerZon = NPeGwl`

not `NPeGwl + 1`.

The `+1` and the nearby `ICpSatPeGwl` alternatives are commented source text.

The A11 carrier and oracle were corrected before evaluating the A13 hypothesis.

## G1 — accepted-state seed: PASS

With the corrected source mapping, the direct runtime probe reports:

- perched topology detected = true;
- raw `QInIntSat` amount = `5.3846153846153863e-8 cm`;
- limiter-accepted `QInIntSat` amount = `5.3846153846153863e-8 cm`.

Thus the accepted matrix state contains a valid source-faithful perched exchange signal,
and the existing A6 rate contracts can derive it deterministically without new persistent
state.

## Seeded predictor experiment

A13 changed only the explicit perched route.

For configurations with `perched_detection_enabled=.true.`:

1. the A11/A6 request is evaluated from the accepted matrix and macropore states;
2. its exchange vector seeds the first Richards overlay;
3. after the predictor, that seed and predictor-derived rate are combined with the same
   fixed-point damping contract already used by later correctors.

Configurations without perched detection retain the pre-A13 zero-exchange predictor path.

No mass tolerance, continuation-state field, restart contract, top-input formula or
rapid-drain formula was changed.

## G2 — serialized retained perched transfer: FAIL

To make the result attributable, the serialized A13 fixture disabled all other macropore
transfer paths:

- top input disabled;
- rapid drainage disabled;
- unsaturated absorption disabled;
- main-groundwater saturated exchange disabled.

Perched `QInIntSat` was therefore the only possible positive macropore storage source.

The serialized transaction completed numerically cleanly:

- completed = true;
- temporal rejections = 0;
- mass rejections = 0;
- solver rejections = 0;
- total mass residual approximately `2.92300905702092e-16 cm`.

Nevertheless:

- initial macropore storage = `0.20000000000000001 cm`;
- final candidate macropore storage = `0.20000000000000001 cm`;
- storage delta = exactly `0 cm`.

The accepted-state seed therefore does not survive the outer fixed-point process into the
transactional candidate.

## Interpretation

The failure is no longer attributable to:

- missing perched detection;
- the A11 off-by-one source translation;
- the inflow limiter;
- temporal subdivision;
- mass rejection;
- nonlinear solver rejection;
- competing top/rapid/main-saturated/unsaturated macropore sources.

A source-faithful perched exchange exists before the first solve, but the outer coupled
Richards/macropore iteration converges to a candidate with no retained perched transfer.

This falsifies the bounded A13 hypothesis that one accepted-state seed is sufficient to
recover the exact transient perched route while keeping macropore rate evaluation outside
the nonlinear Richards solve.

## G3/G4/G5

G3 reject/replay/restart qualification is not promoted because G2 physical transfer failed.

A11 corrected-source requalification is handled separately before any subsequent
macropore architecture work is promoted.

A8/A9/A10 remain canonically admitted and are not modified by A13.

A13 is not a production-admission candidate and must not be merged into canonical.

## Decision

`FALSIFIED_ACCEPTED_STATE_SEED`

The next architecture boundary is an explicit design/research workunit for evaluating
macropore rates within the Reference-Richards nonlinear trial path, matching the legacy
source ordering while retaining SWAP5 transaction ownership outside the solver.

That next workunit must begin as architecture/research. It must not silently insert
mutable macropore continuation state into HeadCalc or weaken rejected-trial isolation.

The frozen Status-A denominator remains unchanged.
