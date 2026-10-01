# PPA-WU05-A17 result — serialized inner-callback transaction integration

Date: 2026-10-01

Status: `CLOSED_PARTIAL_QUALIFIED_TRANSACTION_INFRASTRUCTURE / ACTIVE_PERCHED_E2E_BLOCKED`

Baseline:
`research/ppa-wu05-a16-inner-callback-prototype@51584ec8f340ae01e6e7d2d34e66c9fc011c1394`

Canonical reconciliation:
`integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

Qualified transaction-infrastructure postimage:
`31f8a789f7f0d4d8c44a418cf08a2529c39c9fbb`

Qualification run:
`36849023154` — SUCCESS

## Decision

A17 qualifies the serialized **inner-Richards macropore transaction infrastructure**.

It does **not** yet qualify active perched `QInIntSat` as a production-admission
candidate because no solver-stable Reference-Richards perched end-to-end fixture has yet
been established independently of the macropore callback.

Decision:

`QUALIFIED_INNER_CALLBACK_TRANSACTION_INFRASTRUCTURE_PERCHED_E2E_BLOCKED`

## Implemented route

`macropore_runtime_policy_t` now contains the explicit opt-in:

`inner_richards_exchange_enabled`

Default remains false.

When false, the admitted A8/A9/A10 outer predictor/corrector route is unchanged.

When true, the runtime:

1. configures the read-only A16 inner provider from accepted macropore state;
2. binds the provider directly to explicit Reference Richards;
3. evaluates A6/A11 rates in `vector_F`;
4. evaluates A15 derivative semantics in `jacobian_F`;
5. performs one nonlinear Richards solve rather than an outer exchange fixed-point;
6. recomputes the final A6 receipt at the converged matrix state;
7. materializes the macropore candidate exactly once;
8. publishes history/candidate only through the existing transaction path.

No persistent macropore continuation state is mutated from HeadCalc.

## Qualified transaction infrastructure

The solver-stable A7 Reference-Richards/macropore fixture was reused as the transaction
authority rather than forcing qualification through an unstable synthetic perched
profile.

Run `36849023154` passed at `-O0` and `-O2`:

- `PPA_WU05A17_INNER_DIRECT_ACTUAL_PROVIDER=PASS`;
- `PPA_WU05A17_INNER_SERIALIZED_TRANSACTION=PASS`;
- `PPA_WU05A17_INNER_REJECT_REPLAY=PASS`;
- `PPA_WU05A17_INNER_RESTART=PASS`;
- `PPA_WU05A17_TRANSACTION_INFRASTRUCTURE_GATE=PASS`;
- `PPA_WU05A17_TRANSACTION_INFRASTRUCTURE_O0_O2=PASS`.

Thus the inner route has qualified evidence for:

- real A6 rate evaluation from the current nonlinear iterate;
- A15 derivative composition;
- single ownership of matrix/macropore internal exchange;
- candidate publication after convergence;
- matrix/macropore mass closure;
- rejected-candidate isolation;
- deterministic checkpoint replay;
- commit publication;
- seven-field persistence and restart continuation.

## Preservation

The same exact postimage/run passed:

- A16 analytical current-iterate callback;
- A16 actual A11/A15 provider;
- A15 exact exchange derivative;
- corrected A11 perched source/carrier gate;
- full A7/A8/A9/A10 admitted macropore route.

Final preservation marker:

`PPA_WU05A10_RAPID_DRAIN_GATE=PASS`.

Therefore the new inner route is opt-in and does not alter the default admitted A8-A10
path.

## Active perched end-to-end investigation

A17 retained the earlier synthetic perched test as falsification evidence but removed it
from the positive qualification gate.

### Four-node fixture

The four-node inherited A12 fixture demonstrated:

- the direct A16 provider can detect the initial perched state and produce nonzero
  `QInIntSat`;
- the accepted interval endpoint loses that thin perched topology;
- the resulting macropore candidate has zero perched storage transfer.

Several fixture defects were identified during this work:

- a configured bottom head had originally been paired with free-drainage bottom mode;
- the low-K separator was initially combined with arithmetic conductivity averaging;
- the tiny positive-head default MvG capacity makes a very thin saturated lens a poor
  transaction qualification case unless physical elastic storage is explicitly active.

Correcting these issues did not turn the four-node fixture into a robust persistent
perched authority.

### Six-node source-shaped fixture

A six-node profile was then constructed to provide a more credible perched topology.

The direct provider again detected the intended perched exchange.

However, the baseline Reference-Richards solve **without active macropore callback**
already failed its nonlinear convergence gate.

The decisive baseline evidence was:

- solver status = retry;
- nonlinear iterations = 64;
- internal retry requested.

Subsequent reductions of the perched exchange conductance did not remove the baseline
Richards instability.

Therefore the six-node case cannot be used to qualify or falsify A17 inner-callback
physics.

## Why the synthetic route was stopped

Continuing to tune heads, conductivities, forcing or timestep until one synthetic profile
happens to pass would amount to qualification-by-fixture.

A17 instead requires the next perched end-to-end case to establish, **before enabling
macropore exchange**, that the Reference-Richards baseline:

1. converges cleanly;
2. retains a source-defined perched zone over the accepted interval;
3. has a documented physical/source provenance;
4. passes the existing mass and transaction gates.

Only then may the inner callback be enabled on the same case.

## Production-admission decision

A17 is **not** a production-admission candidate for perched flow yet.

The transaction machinery needed by such an admission is qualified, but the required
independent active-perched end-to-end hydraulic authority is missing.

No canonical merge is requested from A17.

The frozen Status-A denominator is unchanged.

## Next bounded workunit

Open **PPA-WU05-A18 — solver-stable perched Reference-Richards authority fixture**.

A18 should establish the perched hydraulic case independently of A17:

- prefer a recovered exact SWAP 4.3.1 example/input or other source-backed profile;
- otherwise use a physically documented layered profile with independent baseline gates;
- require clean Reference-Richards convergence with the macropore callback disabled;
- require source-defined perched topology to survive the accepted interval;
- only after that baseline passes, replay the same case with A17 inner callback active.

If no such source-backed or independently qualified baseline can be recovered or built,
that is the real blocker for perched production admission.
