# PPA-WU05-A17 preregistration — serialized inner-callback transaction integration

Date: 2026-10-01

Status: `PREREGISTERED / PRODUCTION_ADMISSION_CANDIDATE_PATH`

Baseline:
`research/ppa-wu05-a16-inner-callback-prototype@51584ec8f340ae01e6e7d2d34e66c9fc011c1394`

Canonical reconciliation:
`integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`.

Dependencies:

- corrected A11 source-faithful perched carrier;
- A15 qualified exchange derivative;
- A16 qualified inner-Richards callback prototype.

## Purpose

Integrate the A16 current-iterate provider into the real serialized FMR macropore
transaction while keeping the existing A8-A10 outer fixed-point path unchanged by default.

## Execution policy

Add one explicit numerical/runtime switch:

`inner_richards_exchange_enabled`

Default: false.

When false, the existing A8-A10 outer macropore predictor/corrector route remains
unchanged.

When true:

1. configure the read-only A16 provider from accepted macropore state;
2. bind it to the Reference-Richards request;
3. perform one nonlinear Richards solve with current-iterate A6/A11 rate and A15 derivative;
4. recompute the final A6 rate receipt from the converged matrix candidate;
5. build the macropore candidate exactly once from that final receipt;
6. publish history/candidate only through the existing transaction layer.

No accepted macropore continuation state is mutated inside HeadCalc.

## Gates

### G1 — serialized active perched interval

A real serialized FMR interval must:

- enter the explicit inner callback route;
- produce nonzero source-faithful perched exchange during nonlinear evaluation;
- converge under existing Reference-Richards criteria;
- materialize a nonzero corresponding macropore storage transfer when the final rate is active;
- pass matrix and macropore mass gates.

### G2 — exact internal mass ownership

The matrix exchange integrated over the accepted interval and the opposite macropore
candidate transfer must cancel within the existing internal-exchange tolerance.

No source may be applied by both inner callback and outer overlay.

### G3 — reject/discard/replay

A deliberately rejected candidate must leave committed matrix and all seven accepted
macropore continuation fields unchanged.

Retry from the same checkpoint must reproduce the uninterrupted accepted result.

### G4 — restart

After accepted candidate publication and persistence restore, the next interval must
reproduce matrix state, seven-field macropore state, and internal exchange receipt.

### G5 — preservation

With `inner_richards_exchange_enabled=.false.`:

- A8 route remains unchanged;
- A9 top input remains unchanged;
- A10 rapid drainage remains unchanged.

A15, corrected A11 and A16 prototype gates remain green.

### G6 — decision

If G1-G5 pass on one persisted postimage:
`QUALIFIED_INNER_CALLBACK_PRODUCTION_ADMISSION_CANDIDATE`.

Canonical admission remains a separate explicit step.

## Hard constraints

- no new persistent macropore state;
- no mutation of committed state from HeadCalc;
- no legacy macropore globals in explicit provider mode;
- no weakening mass or convergence tolerances;
- no simultaneous outer exchange overlay when inner callback is active;
- no duplicate matrix/macropore exchange ownership.

## Bounded scope

A17 is limited to the current standard SWAP no-covering-layer, single-column serialized
Reference-Richards macropore envelope.

Not included:

- covering-layer extension;
- arbitrary/multiple rapid levels beyond A10;
- dynamic crack continuation feedback inside Newton;
- RossFast;
- parallel MultiSWAP.
