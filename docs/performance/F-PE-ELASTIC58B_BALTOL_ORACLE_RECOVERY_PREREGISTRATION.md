# F-PE-ELASTIC58B — BALTOL02 refined-oracle recovery preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC58A — QUALIFIED_SMALL_DT_REFINED_ORACLE_SOLVABILITY_BLOCKER`

Parent postimage:
`research/f-pe-elastic58a-oracle-solvability@6d06018783a9a32db8e314c06a266d1679c6b57a`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Question

Does the already-qualified BALTOL02 effective Reference balance-rate floor
recover the ELASTIC58 32-substep physical oracle without weakening the hard
physical qualification gates?

## Frozen candidate/controller

Unchanged from ELASTIC58:

- alpha = `0.17320259355765216`;
- H_budget = `0.01 cm`;
- C-SAFE chooses the first full-converged, indicator-available dt satisfying
  `alpha * Binf <= H_budget`;
- independent profiles exactly `11020,8120,4015,3011`;
- states, forcing, regimes and candidate dt ladder unchanged.

The accepted-case replay must remain exactly `97`.

## Sole oracle change

Only the 32-substep refined oracle changes.

For every direct oracle substep with duration `dt_sub`, set the solver
convergence-request tolerances to the canonical BALTOL02 rule:

`compartment_balance_tolerance =
 max(1e-12, 2.8e-16 / dt_sub)`

`total_balance_tolerance =
 max(1e-12, 2.8e-16 / dt_sub)`.

All other direct-solver request values remain byte/semantically identical to
ELASTIC58/58A:
- head tolerances remain 1e-12;
- ponding tolerance remains 1e-12;
- nonlinear iteration cap unchanged;
- backtracking unchanged;
- constitutive/boundary/source terms unchanged.

## Hard mass authority

The BALTOL02 balance-rate floor changes nonlinear convergence only.

The independent accepted/oracle physical mass ledger remains a separate hard
gate:

`abs(mass residual) <= 1e-12 cm`.

No effective floor is applied to the published physical mass criterion.

## Refined oracle

For every C-SAFE accepted case:
- 32 equal direct Reference-Richards substeps;
- same forcing over the interval;
- same mode-7 free drainage;
- same constitutive parameters;
- same initial state.

If any substep fails, the physical-budget candidate remains unqualified for that
case.

## Frozen physical gates

For every completed accepted/oracle pair:

1. max |dh| <= 0.01 cm;
2. max |dtheta| <= 1e-5;
3. terminal qbot relative error <= 1%;
4. integrated bottom-exchange relative error <= 0.5%;
5. independent candidate and oracle mass residual <= 1e-12 cm.

No gate can move based on ELASTIC58B results.

## Gates

A1. Profile selection reproduces `11020,8120,4015,3011`.

A2. C-SAFE reproduces exactly 97 accepted and 95 EXHAUSTED sequences.

A3. Every oracle substep uses exactly the BALTOL02 effective balance-rate
formula.

A4. O0/O2 candidate and oracle semantics agree.

A5. Every accepted case either completes its 32-substep oracle or is explicitly
classified oracle-incomplete.

A6. Every completed pair is evaluated against all five frozen physical gates.

A7. alpha, H_budget and C-SAFE logic are not refit.

A8. zero `src/**` production changes.

## Decision

If oracle solvability is not materially recovered, close as an oracle blocker.

If oracle solvability is recovered but any physical gate fails, classify
`PHYSICAL_BUDGET_FALSIFIED`.

Only if all 97 accepted cases complete and all physical gates pass may the
0.01-cm budget advance as a research candidate.

No production admission is authorized by ELASTIC58B.
