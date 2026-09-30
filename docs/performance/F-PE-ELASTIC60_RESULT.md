# F-PE-ELASTIC60 — independent-budget C-SAFE compatibility result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic60-budget-controller-compatibility`

Qualified postimage:
`58a68d1d7a399795b8f0e6d3f512bde971f3765c`

Canonical dependency:
`integration/f-ci-canonical@656ddea918c58267a08c2b626d498c998daccc60`

Workflow run:
`36692492418`

Job:
`109812690594`

Conclusion:
SUCCESS.

## Question

Can the previously qualified mode-7 defect indicator, frozen global scaling and
refine-only C-SAFE pattern operate against an independently calibrated
Reference head-error budget without false acceptance?

## Frozen authorities

Global scaling from ELASTIC54:

`alpha = 0.17320259355765216`.

Independent Reference-only mode-7 head budgets from ELASTIC58R:

- Se=0.65:
  `4.6839388616604083e-6 cm`;
- Se=0.85:
  `8.1523527498461590e-5 cm`;
- Se=0.98:
  `1.9893113165281307e-3 cm`.

No alpha or budget was refit.

## Domain

The exact ELASTIC58R E0 domain was preserved:

- B01, B12, O01, O05, O14, O18;
- Se = 0.65, 0.85, 0.98;
- DRYING, NOMINAL, WETTING perturbations around free-drainage equilibrium;
- bottom mode 7;
- swkimpl=0;
- ELAS OFF;
- 16 homogeneous cells;
- zero distributed sources/sinks.

Candidate dt ladder, coarse to fine:

`0.0256, 0.0128, 0.0064, 0.0032, 0.0016 day`.

## Controller contract

For every candidate dt the controller used only:

1. converged full Reference solve;
2. typed integrated mass residual availability and hard `1e-12 cm` mass gate;
3. research mode-7 Binf;
4. frozen alpha;
5. exact-stratum independent Reference budget.

Acceptance criterion:

`alpha * Binf <= H_budget(Se)`.

No observed full-versus-two-half error was used in the decision.

After the controller selected a dt, the already executed two-half trajectory was
used only as an independent validation oracle.

## Primary result

Across all 54 physical cases:

- accepted: `22`;
- exhausted safely: `32`;
- false accepts: `0`;
- accepted cases without independent oracle: `0`;
- accepted before minimum dt: `17`.

Thus the controller is not equivalent to unconditional minimum-dt execution.

Classification of the primary safety test:

`ZERO_FALSE_ACCEPT_WITH_INDEPENDENT_REFERENCE_BUDGET`.

## Accepted-dt distribution

- dt = 0.0256 day: `9` cases;
- dt = 0.0128 day: `1` case;
- dt = 0.0064 day: `3` cases;
- dt = 0.0032 day: `4` cases;
- dt = 0.0016 day: `5` cases.

The remaining 32 cases exhausted the frozen ladder rather than being accepted
outside the budget.

## Independent-oracle margin

Among accepted cases:

maximum observed Reference full-versus-two-half error as fraction of the
independent budget:

`0.4737825530`.

Maximum estimated bound fraction:

`0.9809581706`.

Therefore:
- every accepted observed error remained below the independent budget;
- the closest controller estimate remained just inside the frozen budget;
- the observed Reference disagreement retained substantial margin relative to
  the controller bound.

## Representative cases

### B12, Se=0.65

All three forcing cases were accepted at the largest candidate dt,
`0.0256 day`.

For WETTING:
- Binf = `2.4906813e-5 cm`;
- scaled bound = `4.3139245e-6 cm`;
- independent budget = `4.6839389e-6 cm`;
- observed HINF = `2.4692781e-9 cm`.

The conservative estimate uses about 92% of the budget while the realized
Reference disagreement is only about 0.053% of the budget.

### O14, Se=0.98, DRYING

Accepted at `0.0128 day`:
- Binf = `1.1176369e-2 cm`;
- scaled bound = `1.9357761e-3 cm`;
- budget = `1.9893113e-3 cm`;
- observed HINF = `9.4250099e-4 cm`.

This is the largest observed budget fraction among accepted cases:
approximately 47.4%.

### B01, Se=0.98, DRYING

Accepted at `0.0064 day`:
- scaled bound = `1.9514312e-3 cm`;
- budget = `1.9893113e-3 cm`;
- observed HINF = `2.7961191e-4 cm`.

The controller estimate reaches about 98.1% of the allowed budget but the
independent observed error remains comfortably below it.

## Exhaustion pattern

Exhaustion is concentrated in stricter low-Se budgets and difficult
material/forcing combinations.

This is a safe outcome under the preregistered C-SAFE contract:
the controller does not weaken the budget, extrapolate through missing
convergence, or accept after ladder exhaustion.

ELASTIC60 therefore establishes safety compatibility, not universal acceptance
coverage.

## Hypotheses

H1, zero false acceptance:
SUPPORTED.

H2, every acceptance has an independent two-half oracle:
SUPPORTED.

H3, at least one case is accepted before the minimum dt:
SUPPORTED, 17 cases.

H4, safe exhaustion may occur:
SUPPORTED, 32 cases.

## Gates

- A1 exact domain and dt ladder: PASS;
- A2 O0/O2 semantic identity: PASS;
- A3 controller decision firewall: PASS;
- A4 alpha and budgets frozen: PASS;
- A5 false accepts = 0: PASS;
- A6 oracle-unavailable accepts = 0: PASS;
- A7 every accepted oracle inside independent budget: PASS;
- A8 zero production source changes: PASS.

## Decision

Classification:

`QUALIFIED_INDEPENDENT_BUDGET_COMPATIBLE_CSAFE_RESEARCH_PATTERN`.

This is the first workunit in the ELASTIC temporal line where:
- a mode-7 trajectory-aware defect indicator;
- an independently calibrated Reference error budget;
- a pre-frozen conservative scaling;
- and a refine-only controller

are evaluated together without circular calibration and without false
acceptance in the qualified domain.

No production temporal-policy admission is authorized yet.

Remaining work before production admission includes:
- explicit production integration of the mode-7 indicator/controller path;
- end-to-end runtime cost of the one-extra-tridiagonal indicator;
- wider material/state holdout;
- preservation of the exact Reference fallback;
- broader F-CI14 multi-metric acceptance beyond head error alone.
