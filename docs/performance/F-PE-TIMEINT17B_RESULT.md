# F-PE-TIMEINT17B result — endpoint failure versus route-event attribution

Date: 2026-09-29

Status:

`TIMEINT17B_ENDPOINT_SOLVER_DOMINANT`

Secondary classification:

`TIMEINT17B_SHARED_DYNAMIC_TOP_BLOCKER`

Canonical base incorporated before result write:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

Qualification authority:

- workflow run: `36530500976`;
- job: `109282889959`;
- conclusion: SUCCESS.

## Frozen question

TIMEINT17B asked whether the failed TIMEINT17A/A2 same-route qualification was dominated by:

1. genuine dynamic-top route transitions; or
2. endpoint nonlinear solve failure before route semantics could be assessed.

The frozen primary bank was TIMEINT17A2.

No numerical settings, fixtures, tolerances or temporal formulas were changed.

## Result

All 48 TG requests in the frozen A2 bank terminated as:

`ENDPOINT_SOLVE_FAILURE`

Aggregate census:

- TG runs: 48;
- complete same-route TG runs: 0;
- ineligible TG runs: 48;
- endpoint-solver failures: 48/48 = 1.00;
- explicit route-event mismatches with converged endpoint/accepted state: 0/48 = 0.00;
- onset event evidence: false;
- release/runoff event evidence: false;
- accepted physical mass diagnostics: PASS;
- process/output failures: 0.

Frozen primary classification:

`TIMEINT17B_ENDPOINT_SOLVER_DOMINANT`

This exceeds the preregistered >50% endpoint-solver threshold by a large margin.

## KLAG comparator

The identical frozen A2 fixtures were also run with KLAG Backward Euler.

All paired KLAG requests likewise terminate with endpoint-solve failure.

Using the preregistered same-fixture / comparable-first-terminal-step criterion:

- shared dynamic-top solver signals: 45;
- TG endpoint failures: 48;
- shared fraction: 0.9375;
- TG-specific endpoint robustness signals: 0.

Therefore the secondary attribution is:

`TIMEINT17B_SHARED_DYNAMIC_TOP_BLOCKER`

The blocker is not specific to the Thomas-Gladwell correction.

## Scientific interpretation

TIMEINT17A and A2 cannot be interpreted as evidence that dynamic-top physical route events destroy TG accuracy.

TIMEINT17B shows that the endpoint solve fails before route-event semantics can be established throughout the frozen A2 bank.

The fact that KLAG fails essentially the same requests at the same first terminal step is decisive: the dominant obstruction belongs to the shared dynamic-top endpoint solve/composition, not to the second-order TG temporal correction.

This also explains why repeated same-route bank redesign did not help.

The bank was not primarily too close to a physical route boundary. The solver could not robustly realize the requested dynamic-top endpoint state under the frozen numerical envelope.

## Mass and transaction interpretation

Accepted physical mass remains clean.

Failed terminal trials publish no accepted water and do not contribute synthetic mass.

No evidence of:

- accepted-state mass leakage;
- theta/head projection inconsistency;
- history mass relabeling;
- TG-specific transaction mutation.

The blocker is endpoint numerical/path robustness under dynamic-top coupling.

## Decision

Do not open TIMEINT17 P1 known-time event localization.

Do not open TIMEINT17 P2 endogenous route localization.

Do not increase MAXIT or loosen tolerances as a rescue inside TIMEINT17B.

Open a separate work unit:

`F-PE-TIMEINT17C — shared dynamic-top endpoint nonlinear-path attribution and repair`

TIMEINT17C must investigate the endpoint solve path shared by TG and KLAG.

Primary questions:

1. Why does the current dynamic-top endpoint solve consume the frozen nonlinear/backtracking envelope even for small A2 intervals?
2. Is the failure caused by inconsistent surface residual/Jacobian treatment, route candidate switching inside Newton, top K authority mismatch, or ponding-variable handling?
3. Can the shared endpoint solve be repaired without changing physical semantics, tolerances or temporal acceptance rules?

Only after shared endpoint robustness is independently qualified may TIMEINT17 return to event semantics.

## Production boundary

No production `src/**` change in TIMEINT17B.

No tolerance change.

No MAXIT change.

No timestep-controller change.

No event localization.

No default change.

`LEGACY_NUMERICS` remains production default.
