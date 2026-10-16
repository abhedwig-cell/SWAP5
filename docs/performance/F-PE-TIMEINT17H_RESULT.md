# F-PE-TIMEINT17H result — globalization merit and state-scaling attribution

Date: 2026-09-29

Status:

`TIMEINT17H_MIXED_MERIT_SIGNAL`

Canonical base:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

Qualification authority:

- workflow run: `36535199990`;
- job: `109297652276`;
- conclusion: SUCCESS.

## Frozen question

TIMEINT17H asked whether the current raw residual-L2 backtracking merit is materially misaligned with the complete nonlinear convergence contract on the endpoint failures reproduced by TIMEINT17.

The audit did not change solver behavior.

## Coverage

Coverage gate:

PASS.

Audited terminal-failure Newton iterations:

`768`

Tested backtracking candidates:

`2078`

Scope:

- routes: FLUX, HEAD, RUNOFF;
- materials: B01, B12, O05, O14;
- modes: TG and KLAG;
- four dt levels;
- process failures: 0.

## Aggregate result

Iterations where the current selected factor differs from the tested factor minimizing composite convergence merit:

`212 / 768 = 0.27604`

Iterations where an available tested factor improves composite merit by at least 10% relative to the current selected factor:

`140 / 768 = 0.18229`

Frozen H0 trigger for `TIMEINT17H_MERIT_MISALIGNMENT` required both fractions >= 0.25.

The first condition passes.

The second does not.

Therefore:

`TIMEINT17H_MIXED_MERIT_SIGNAL`

H1 is not authorized.

## Dominant composite-merit component at the current selected factor

Counts:

- compartment balance: 202;
- total balance: 485;
- head-update scaling: 81.

Total-balance scaling is therefore the most frequent dominant component, but not uniquely dominant across the full bank.

## Route and mode decomposition

### FLUX / TG

- audited iterations: 128;
- selected-factor mismatch: 0.30469;
- >=10% improvement available: 0.21875;
- median selected composite merit: about 2.972;
- median best tested composite merit: about 2.467.

### FLUX / KLAG

- mismatch: 0.35156;
- >=10% improvement: 0.20313;
- median selected merit: about 3.218;
- median best merit: about 2.823.

### HEAD / TG

- mismatch: 0.28906;
- >=10% improvement: 0.17188;
- median selected merit: about 4.715;
- median best merit: about 3.583.

### HEAD / KLAG

- mismatch: 0.24219;
- >=10% improvement: 0.17969;
- median selected merit: about 6.452;
- median best merit: about 3.652.

### RUNOFF / TG

- mismatch: 0.21875;
- >=10% improvement: 0.14063;
- median selected merit: about 3.788;
- median best merit: about 3.237.

### RUNOFF / KLAG

- mismatch: 0.25000;
- >=10% improvement: 0.17969;
- median selected merit: about 5.303;
- median best merit: about 3.934.

No route/mode family independently establishes a simple globally sufficient scaled-line-search repair under the frozen H trigger.

## Interpretation

The current raw residual merit is not perfectly aligned with the complete convergence contract.

However, the discrepancy is not strong enough to justify replacing the existing backtracking acceptance rule with the preregistered H1 composite-merit rule.

This preserves an important negative result:

- globalization remains the correct research layer after G;
- simple merit rescaling alone is not yet supported as the repair.

The remaining evidence is consistent with loss of local Newton-model quality away from the local convergence region, especially because:

- G certifies the Jacobian;
- E shows nondecrease/stagnation and post-step-gate failures;
- H shows only partial factor-selection misalignment.

## Consequence

Do not execute H1.

The next bounded work may assess trust-region/model-quality behavior observationally before selecting any trust-region radius or state transformation.

## Production boundary

No production `src/**` change.

No tolerance change.

No MAXIT/MaxBackTr change.

No physical or route/event change.

`LEGACY_NUMERICS` remains production default.
