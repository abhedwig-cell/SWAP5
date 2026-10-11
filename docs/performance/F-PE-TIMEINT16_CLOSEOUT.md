# F-PE-TIMEINT16 closeout — conservative second-order Thomas-Gladwell successor

Date: 2026-09-29

Final status:

`QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`

Canonical authority incorporated before closeout:

`integration/f-ci-canonical@7d4aa0cb6790f293ff486f716c6c4eadd7d18eb8`

Final branch-head qualification authority:

- run `36525820591`;
- inverse: SUCCESS;
- P0 smooth mechanism: SUCCESS;
- event-startup attribution: SUCCESS;
- provider-consistent stage: SUCCESS.

## Executive conclusion

TIMEINT16 identifies a conservative, second-order, one-step Richards temporal mechanism that is compatible with SWAP5's existing accepted-interval physical mass contract.

The successful mechanism is not the naive fully implicit Thomas-Gladwell composition.

The qualified mechanism is:

`TG_KPRED_STAGE`

with current-step provider-consistent hydraulic coefficient staging.

On the frozen smooth fixed-flux bank it delivers:

- median refined head order about `1.998`;
- median refined moisture order about `1.998`;
- physical interval mass residuals order `1e-14 cm`;
- constitutive roundtrip error order `1e-17`;
- native endpoint balance residual below `1e-12 cm/d`;
- median deterministic work per step equal to KLAG Backward Euler.

This is the first TIMEINT route in the current sequence that simultaneously satisfies:

1. second-order temporal convergence;
2. exact consecutive-state physical interval mass semantics;
3. one-step accepted-state ownership;
4. constitutive consistency of accepted moisture and pressure head;
5. no material deterministic per-step work penalty on the frozen bank.

## Negative authorities preserved

### P0

`CLOSED_TG_SECOND_ORDER_NOT_REPRODUCED`

The direct fully implicit endpoint composition is conservative and cheap but remains approximately first order.

### TIMEINT16B

`TG_ORDER_REDUCTION_PERSISTS_AFTER_STARTUP`

Event-local BE startup does not restore second order.

Both head and moisture remain approximately first order, while collocation and physical balance diagnostics pass.

These negative results are retained as authority.

They prevent future reintroduction of the same operator composition under a different label.

## Positive authority

### TIMEINT16C

`QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`

The current-step predictor is:

`theta_tilde = theta_n + h * theta_dot_n`.

The predictor is projected to a consistent head and evaluated through the same constitutive provider used by the benchmark.

The resulting `K_tilde` is fixed inside the endpoint nonlinear solve.

The final accepted moisture state is:

`theta_(n+1) = theta_n + 0.5 h (theta_dot_n + theta_dot_p)`.

The accepted pressure head is the exact constitutive projection of that accepted moisture state.

The current-step K prediction is not history extrapolation.

No previous accepted K is required.

## Relation to TIMEINT14

TIMEINT14 remains valid.

BDF2 is discretely conservative in a multistep algorithmic state but incompatible with the unchanged exact physical consecutive-state interval publication contract unless temporal-history mass is given separate semantics.

TIMEINT16 avoids that conflict.

The accepted physical storage increment is the ordinary consecutive-state increment, and the fixed-flux test bank closes against independently known current-interval external mass.

No hidden history debt is needed.

## Relation to TIMEINT15

TIMEINT15 remains valid.

The tested Crank-Nicolson/trapezoidal residual decomposition preserves physical mass but does not reproduce second-order convergence in SWAP's current operator composition.

TIMEINT16 demonstrates that one-step second order is nevertheless achievable.

The key is not generic endpoint averaging; it is stage-consistent evaluation of the nonlinear hydraulic coefficient field.

## Literature interpretation

The final result is consistent with the Thomas-Gladwell / Kavetski line:

- moisture is the conserved temporal state;
- derivative and state approximations must be collocated consistently within the step;
- nonlinear coefficients may be evaluated on a sufficiently accurate forward predictor rather than solved fully implicitly at the final state;
- the accepted physical state remains a moisture/head pair satisfying the constitutive relation.

The SWAP5 result therefore provides repository-specific evidence for the same mechanism.

## Transaction semantics

The qualified mechanism is compatible in principle with the existing transaction architecture.

A production-shaped implementation will need explicit trial-owned state for:

- accepted-origin physical derivative;
- current-step moisture predictor;
- predicted hydraulic coefficient field;
- endpoint predictor solve;
- accepted TG moisture/head projection.

The following must remain commit-safe:

- no accepted state mutation during failed trials;
- no accepted derivative/history mutation before commit;
- no predicted K persistence across rejected trials unless owned by trial state;
- exact physical interval mass publication from accepted consecutive physical states and physical in/out.

Unlike BDF2, no previous interval storage history is required by the temporal formula itself.

## Next research sequence

TIMEINT16 closes the smooth fixed-flux mechanism question positively.

The next work must be split rather than bundled.

### F-PE-TIMEINT17 — event and dynamic-boundary semantics

Priority:

1. dynamic top / ponding;
2. hard forcing events;
3. event-local restart or reinitialization rule;
4. physical interval quadrature across boundary-mode transitions;
5. transaction rollback through those transitions.

No adaptive controller yet.

### F-PE-TIMEINT18 — variable-step TG / LTE

After event semantics are stable:

1. derive variable-step Thomas-Gladwell coefficients;
2. derive accepted-state temporal error estimate;
3. qualify smooth variable-step order;
4. establish ratio safeguards if needed;
5. only then connect to AUTO timestep control.

### F-PE-TIMEINT19 — production-shaped work and provider integration

After TIMEINT17/18:

1. remove test-only inverse assumptions;
2. use production constitutive inverse/mixed-state authority;
3. introduce typed temporal mode/state;
4. preserve `LEGACY_NUMERICS` as default;
5. qualify runtime and regression matrix;
6. prepare production admission only if all physical regimes pass.

## Performance implication

The positive TIMEINT16C result is especially relevant to the broader SWAP5 performance program.

On this bank, the second-order mechanism does not require the structural ~2x solve cost seen for two-stage methods such as TR-BDF2/ESDIRK.

It also avoids the BDF2 physical interval-publication mismatch.

The measured deterministic work ratio versus KLAG BE is approximately `1.0`.

This creates a credible route to larger accepted timesteps without paying a second nonlinear solve per interval.

That performance hypothesis is not yet production-qualified and must not be converted into a speedup claim before end-to-end event/dynamic-boundary testing.

## Production boundary

No production `src/**` change is admitted in TIMEINT16.

No user-facing numerical option is added.

No default changes.

No mass-balance gate changes.

No adaptive timestep tuning.

`LEGACY_NUMERICS` remains production default.

## Closure

TIMEINT16 is closed as a positive research mechanism qualification.

Final classification:

`QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`

The Thomas-Gladwell reconstruction line is therefore not closed negatively.

It advances to dynamic-event and variable-step qualification as a conservative second-order successor candidate.
