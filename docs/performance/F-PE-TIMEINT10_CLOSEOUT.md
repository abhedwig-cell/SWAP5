# F-PE-TIMEINT10 closeout — embedded BDF2/BE endpoint pair

Date: 2026-09-29

Final status:

`CLOSED_EMBEDDED_BDF2_BE_TOO_CONSERVATIVE`

## P0

The one-correction embedded BE construction qualified on B01/O05:

- 96/96 complete labels;
- strong rank correlation;
- zero false-safe;
- about 49.5% safe coverage;
- one extra tridiagonal backsolve;
- zero extra nonlinear solves;
- zero extra Jacobian assemblies.

This established that the construction contains genuine local temporal-error information.

## Blind holdout

On B12/O14:

- 143 complete labels;
- overall Spearman about 0.961;
- zero false-safe;
- but safe coverage falls to about 1.1%.

The signal is strongly and systematically conservative.

Median actual/E10 is only about 0.12.

## Scientific conclusion

A lower-order BE correction through the converged BDF2 Jacobian is too far separated in formal error scale from the BDF2 local truncation error.

The raw difference is useful as a conservative warning signal, but not as a practical adaptive controller because it rejects almost every safe blind step.

A post-hoc scale factor would likely restore coverage, but that is explicitly outside the preregistered authority and would simply return to fitted-estimator behavior.

## Consequence

The next useful direction is a genuinely co-designed embedded stiff pair whose main and embedded formulas have compatible asymptotic error scales and share nonlinear work.

The strongest candidate is TR-BDF2 / ESDIRK-style integration because:

- it is designed for stiff systems;
- it combines two implicit stages into a one-step method;
- embedded error formulas exist;
- it avoids dependence on long multistep history after events;
- history restart around dynamic-top regime transitions is simpler than variable-step BDF2 history management.

The cost question becomes whether its two implicit stages can be implemented with enough Jacobian reuse that the higher per-step cost is offset by larger accepted dt.

## Required successor

`F-PE-TIMEINT11 — TR-BDF2 embedded-pair mechanism and cost feasibility`.

TIMEINT11 should first remain on the smooth fixed-flux envelope and answer:

1. can the nonlinear Richards residual be expressed consistently at the TR stage and BDF2 stage;
2. can both stages reuse structural Jacobian/workspace machinery;
3. does the known embedded estimator behave conservatively without empirical scaling;
4. what is the deterministic work per accepted step relative to BE_KIMPL and BDF2_KIMPL;
5. only then should dynamic-top transitions be reintroduced.

## Production boundary

No production source change.

LEGACY_NUMERICS remains production default.

Variable-step BDF2 ratio<=2 remains qualified research authority.
