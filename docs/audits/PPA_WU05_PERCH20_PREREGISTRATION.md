# PPA-WU05-PERCH20 preregistration — reduction numerical continuation restart

Date: 2026-10-01

Status: `PREREGISTERED / NUMERICAL_CONTINUATION_PERSISTENCE`

Research baseline:
`research/ppa-wu05-perch19-frreduq-retry-ladder@7de6d7cec0d1904e956387aaef62ae4690f76a92`

Current canonical reconciliation:
`integration/f-ci-canonical@2a0b23a2c4e547f6de2613884207d10b2fce462e`

## Purpose

Persist the qualified PERCH19 reduction continuation through the FMR committed/restart
boundary without adding fields to the seven-field physical macropore state.

Persist exactly:

- reduction level / `IDecMpRat`;
- stable accepted-step counter / `NStep`;
- previous accepted/reduction timestep / `dtold`.

## Layout

Register a dedicated FMR numerical-continuation layout identity for macropore reduction.

The physical optional-state layout remains `FMR_OPTIONAL_STATE_LAYOUT_MACROPORE`.

The new numerical layout must be represented by a typed FMR state carrier extending the
normal B1.10 physical state, analogous to the already admitted Richards temporal-history
numerical continuation.

## Gates

1. clone/snapshot preserves physical state and reduction continuation exactly;
2. candidate reduction continuation is derived only from the accepted numerical
   continuation plus the current trial result;
3. discard leaves accepted physical and numerical continuation unchanged;
4. commit publishes both atomically;
5. restart export/restore accepts only the registered layout and restores all three
   continuation values bitwise;
6. next inner interval starts from the restored reduction factor;
7. ten-step/larger-dt recovery semantics survive restart;
8. PERCH19 A18 active result and default A8-A10 behavior remain preserved.

## Hard rules

- no new field in `macropore_continuation_state_t`;
- no mutation of committed continuation from a rejected attempt;
- no implicit reset to level zero at restart;
- no reuse of the temporal-history layout ID;
- fail closed on layout/type mismatch.

## Admission boundary

PERCH20 is research qualification. Eventual production admission is reconstructed from
then-current canonical under the collision-free PERCH namespace.
