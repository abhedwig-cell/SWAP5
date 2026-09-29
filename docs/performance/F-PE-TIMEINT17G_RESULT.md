# F-PE-TIMEINT17G result — full-column residual/Jacobian attribution

Date: 2026-09-29

Status:

`TIMEINT17G_FULL_JACOBIAN_CONSISTENT_GLOBALIZATION_BLOCKER`

Canonical base:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

Qualification authority:

- workflow run: `36534596938`;
- job: `109295675903`;
- conclusion: SUCCESS.

## Frozen question

TIMEINT17G asked whether the complete 16-node tridiagonal Jacobian used by HeadCalc is the finite-difference derivative of the actual residual operator on the nonlinear iterates that fail in the TIMEINT17 A2 bank.

This extended TIMEINT17D from the dynamic-top provider and top row to the full column.

No solver decision, physical equation, timestep, tolerance, conductivity staging or route logic was changed.

## Coverage

Eligible audited nonlinear iterates:

`768`

Coverage includes:

- materials: B01, B12, O05, O14;
- routes: FLUX, HEAD, RUNOFF;
- dt: 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- terminal endpoint failures from TG and matched KLAG trajectories.

Coverage gate:

PASS.

## Full-column Jacobian result

Audited nonlinear iterates with at least one failing tridiagonal entry:

`0 / 768`

Failing-iteration fraction:

`0.0`

Mismatch localization:

`NONE`

Counts:

- TOP: 0;
- INTERIOR: 0;
- BOTTOM: 0.

The full tridiagonal residual/Jacobian pair therefore satisfies the preregistered finite-difference authority throughout the audited failing nonlinear iterates.

## Classification

Frozen classification:

`TIMEINT17G_FULL_JACOBIAN_CONSISTENT_GLOBALIZATION_BLOCKER`.

## Combined TIMEINT17 evidence

The attribution chain now excludes:

- route-bank interpretation as a sufficient explanation;
- hidden route switching during Newton;
- dynamic-top provider availability failure;
- provider surface-head derivative error;
- top-row Jacobian error;
- interior/full-column Jacobian error.

TIMEINT17E/F additionally show:

- FLUX frequently fails through line-search nondecrease/stagnation;
- HEAD/RUNOFF frequently reduce residual but remain outside the full convergence contract;
- dominant residuals are usually interior rather than at the dynamic top node.

The remaining blocker is therefore nonlinear globalization/state scaling, not local residual/Jacobian algebra.

## Consequence

Stop residual/Jacobian defect hunting inside TIMEINT17.

The next bounded research question may compare globalization strategies while preserving:

- the same residual;
- the same analytic Jacobian;
- the same physical mass contract;
- the same A2 fixtures;
- the same accepted-state transaction semantics.

Candidate research families include:

- a merit-function line search with an explicit sufficient-decrease condition;
- safeguarded/damped Newton using residual-based step acceptance;
- trust-region or Levenberg-type globalization;
- variable/state scaling before globalization.

No candidate is selected by this result alone.

Before opening a repair workunit, reconcile existing SWAP5 solver/globalization authority and relevant Richards-equation literature.

## Stop rules

TIMEINT17G does not authorize:

- increasing MAXIT;
- relaxing balance/head/ponding tolerances;
- changing dt;
- changing physical equations;
- changing K staging;
- changing route/event semantics;
- production source edits.

## Production boundary

Research diagnostics only.

`LEGACY_NUMERICS` remains production default.
