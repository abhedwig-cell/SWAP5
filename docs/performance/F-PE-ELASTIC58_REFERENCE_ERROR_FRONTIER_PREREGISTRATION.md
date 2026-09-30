# F-PE-ELASTIC58 — independent reference-error frontier preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC57 — QUALIFIED_NONMONOTONICITY_ROBUST_REFINEMENT_CONTROLLER_PATTERN`

Parent branch head:
`research/f-pe-elastic57-controller-robustness@b09ab27c7e5cd1027975f42ad61511500e180d53`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Frozen conservative scaling:
`alpha = 0.17320259355765216`.

## Question

What realized endpoint error is obtained for a candidate mode-7 step when its
research defect indicator predicts the conservative quantity

`E_bound = alpha * Binf`

and the candidate is compared against an independently refined trajectory to
the same endpoint?

ELASTIC58 does not choose a production temporal budget.

## Independent reference trajectory

For every candidate case:

1. solve one candidate step of duration `dt`;
2. construct a reference trajectory from the same initial state and forcing
   using `Nref` sequential equal substeps;
3. require every reference substep to converge;
4. evaluate two reference levels:
   - `Nref=8`;
   - `Nref=16`;
5. the case is reference-qualified only when both levels converge and their
   endpoint pressure-head difference satisfies

`max|h_ref16-h_ref8| <= max(1e-5 cm, 0.1 * max|h_candidate-h_ref16|)`.

The reference criterion is an oracle-stability requirement, not an acceptance
tolerance for production.

## Bank

Use the four ELASTIC55 profile/material holdouts:
- 11060;
- 10260;
- 8016;
- 3030.

Preserve each profile's:
- geometry;
- Staringreeks retention materialization;
- generated Ss;
- frozen Ksat/lambda parent values.

States:
- h0 = -75, -20, +2, +10 cm.

Forcing perturbations:
- delta = -0.035, +0.035 cm/day.

Regimes:
- OFF;
- FIXED_1E6;
- GENERATED.

Candidate dt:
- 0.015625;
- 0.0078125;
- 0.00390625;
- 0.001953125 day.

Total requested candidate cases:
`4 profiles * 4 states * 2 forcing * 3 regimes * 4 dt = 384`.

## Observations

For every candidate-full-converged case record:
- Binf;
- `E_bound = alpha*Binf`;
- candidate endpoint;
- ref8 endpoint if available;
- ref16 endpoint if available;
- oracle convergence/stability classification.

For every reference-qualified case record:
- `H_REF = max|h_candidate-h_ref16|`;
- `THETA_REF = max|theta_candidate-theta_ref16|`;
- signed and unsigned storage difference;
- `H_REF / E_bound` where E_bound > 0;
- whether the frozen global envelope also bounds the independent reference error.

## Frontier

Report the observed relationship between E_bound and H_REF without fitting a
new acceptance budget.

Pre-register these descriptive E_bound bands:
- <= 0.01 cm;
- (0.01, 0.05] cm;
- (0.05, 0.10] cm;
- (0.10, 0.25] cm;
- (0.25, 0.50] cm;
- > 0.50 cm.

For each populated band report:
- count;
- max H_REF;
- median H_REF;
- max H_REF/E_bound.

No band is declared acceptable in ELASTIC58.

## Hypotheses

H1. The frozen global envelope remains conservative relative to the independent
ref16 endpoint error for the reference-qualified bank.

H2. Smaller E_bound bands correspond to smaller realized H_REF distributions.

H3. The independent reference frontier can support a later explicit numerical
budget decision without reusing nonlinear solver tolerances.

## Gates

A1. All 384 candidate cases execute.

A2. O0/O2 candidate and reference classifications agree.

A3. Reference-qualified cases satisfy the frozen ref8/ref16 stability rule.

A4. Binf is finite/nonnegative whenever candidate full solve converges.

A5. Alpha remains exactly frozen and is not refit.

A6. No production `src/**` changes.

## Decision

A green ELASTIC58 qualifies an independent error frontier only.

It does not authorize:
- a production temporal budget;
- production mode-7 indicator admission;
- production controller integration;
- relaxation of hard mass acceptance.
