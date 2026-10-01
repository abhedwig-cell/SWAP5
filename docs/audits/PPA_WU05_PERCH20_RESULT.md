# PPA-WU05-PERCH20 result — reduction numerical continuation restart

Date: 2026-10-01

Status: `CLOSED_QUALIFIED_NUMERICAL_CONTINUATION_RESTART`

Research baseline:
`research/ppa-wu05-perch19-frreduq-retry-ladder@7de6d7cec0d1904e956387aaef62ae4690f76a92`

Canonical reconciliation:
`integration/f-ci-canonical@2a0b23a2c4e547f6de2613884207d10b2fce462e`

Qualified postimage:
`0b29dbf38ecdd95fc900bb8dbc744a8d05708e9f`

Qualification run:
`36877838884` — SUCCESS.

## Decision

`QUALIFIED_MACROPORE_REDUCTION_NUMERICAL_CONTINUATION_RESTART`

PERCH20 closes the persistence blocker identified by PERCH19.

The source-faithful macropore reduction controller is now represented as explicit FMR
numerical continuation rather than as fields in the seven-field physical macropore state.

## Registered layout

PERCH20 adds:

`FMR_NUMERICAL_CONTINUATION_MACROPORE_REDUCTION = 2`.

The optional physical-state layout remains:

`FMR_OPTIONAL_STATE_LAYOUT_MACROPORE`.

The dedicated typed state carrier is:

`fmr_b110_macropore_reduction_state_t`.

It carries the normal physical B1.10/macropore state plus:

- reduction level / source `IDecMpRat`;
- stable accepted-step counter / source `NStep`;
- previous accepted reduction timestep / source `dtold`.

No field is added to `macropore_continuation_state_t`.

## Lifecycle qualification

The focused restart lifecycle gate passes.

Qualified behavior includes:

- clone/snapshot preserves the reduction continuation exactly;
- the registered template/layout combination is accepted;
- mismatched numerical-continuation layout fails closed;
- persistence export/restore preserves all continuation values bitwise;
- restart-state/template matching recognizes the dedicated layout.

## Transaction qualification

The serialized candidate/commit/reject gate passes.

Run `36877838884` proves:

- candidate continuation is derived from accepted continuation plus the current trial;
- rejected/discarded candidate does not mutate committed physical or numerical state;
- commit publishes physical state and reduction continuation atomically;
- restart reproduces the committed candidate;
- the next interval begins from the restored reduction continuation;
- the tenth stable accepted step recovers the reduction level;
- the restored execution reproduces the same recovery transition.

The full/half temporal contract is handled explicitly: the accepted candidate is the
second half-step state, so source `dtold` records the accepted half-step duration rather
than the original full trial duration.

Markers from the qualified gate include:

- `PPA_WU05_PERCH20_REJECT_ISOLATION=PASS`;
- `PPA_WU05_PERCH20_COMMIT_PUBLICATION=PASS`;
- `PPA_WU05_PERCH20_RESTART_CONTINUATION=PASS`;
- `PPA_WU05_PERCH20_TENTH_STEP_RECOVERY=PASS`;
- `PPA_WU05_PERCH20_TRANSACTION_CONTINUATION_GATE=PASS`.

## PERCH19 preservation

The same qualification run passes the PERCH19 source-ladder gate.

Therefore the persistence layer preserves:

- exact factors `1, 0.1, 0.01, 0.001`;
- failure escalation;
- accepted recovery semantics;
- the A18 source-backed active perched route.

## Production boundary

The perched inner-Richards capability now has qualified research evidence for:

- source-backed solver-stable perched hydraulic authority;
- current-iterate inner A6/A11 exchange;
- source-faithful A15 Jacobian semantics;
- A17 serialized transaction ownership;
- PERCH19 exact FrReduQ retry/recovery controller;
- PERCH20 numerical-continuation publication, reject isolation and restart.

The remaining work is governance/integration rather than a known missing physical or
numerical mechanism.

Because current canonical contains the separate RFM workstream and the historical generic
A11-A18 namespace collision, production admission must be reconstructed from the
then-current canonical branch under the collision-free PERCH namespace. Historical
research documentation must not be merged wholesale.

## Next safe step

Open:

`PPA-WU05-PERCH21 — canonical reconstruction and production admission qualification`.

PERCH21 must:

1. start from then-current `integration/f-ci-canonical`;
2. carry only the required perched code and collision-free PERCH evidence;
3. three-way reconcile shared runtime/backend files with admitted RFM changes;
4. preserve current canonical RFM gates;
5. replay the A18 Andelst perched authority through PERCH19/PERCH20;
6. replay default macropore preservation;
7. qualify one production-admission postimage before opening the admission PR.
