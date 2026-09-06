# SWAP-011 qualification evidence

B1 admission status: **CANDIDATE, NOT YET ADMITTED**

This page records the qualification already completed in the SWAP 4.3.1 technical-audit line. It is evidence for admission, but it does not substitute for the exact final patch payload.

## Reference and final implementation progression

The audit first established a deliberately simple numerical-reference implementation that differentiates the actual active `K(h)` relation. This removed the derivative-consistency failures for the affected hydraulic models and served as a correctness oracle.

The production candidate was then optimized so the normal path did not pay for avoidable duplicate constitutive evaluations. The qualified final line uses model-specific/lazy constitutive state and preserves a finite-difference fallback only where needed for numerical/branch safety.

For the final qualified patch line, the production source changes are limited to:

```text
MOD_MvG_functions.f90
WC_K_models_04_11.f90
MOD_RIA.f90
```

`headcalc.f90` remains byte-identical to B0 in that final line.

## E5 qualification gate

Recorded E5 evidence:

- 36/36 strict full SWAP runs passed;
- Newton iteration histograms/routes matched the qualified reference route exactly;
- `result.end` was byte-identical for the gate cases;
- direct focus included hydraulic models 3, 7, 10 and 12 plus 24 additional cases;
- measured runtime improvement versus the numerical-reference implementation was about 9.0% to 19.2%, with median about 12.3%;
- only the three source files listed above differed in the qualified patch tree.

This gate establishes that the optimized implementation did not gain performance by changing the solved physical problem or accepted nonlinear route for the tested scope.

## E6 broad D2-style qualification

Recorded E6 evidence:

- 150/150 runs completed normally;
- 60/60 D2/reference versus E5 Newton routes matched exactly;
- K0 `result.end`: 30/30 byte-identical;
- K1 `result.end`: 16/30 byte-identical;
- maximum reported H-RMSE: `1.43e-11 cm`;
- maximum reported nodal deviation: `9.98e-11 cm`;
- median E5/reference runtime ratio: `0.791`, about 20.9% faster;
- a 31/31 follow-up timing set was faster for the qualified implementation.

The non-byte-identical K1 cases remained at numerical round-off scale according to the reported state metrics, while the Newton route was unchanged.

## E7 upstream-package gate

The E7 step removed unused exploratory derivative wrappers, retained the lazy-state/fallback production route, and packaged the result for upstream transfer. Strict and optimized builds passed the E7 sanity checks; the focused model 3/7/10/12 routes retained exact Newton histograms and byte-identical `result.end` in the recorded sanity set.

The audit-line status after E7 is:

```text
FIX_TESTED
READY_PATCH_UPSTREAM
```

## B1 interpretation

The evidence is strong enough to classify SWAP-011 as a demonstrated legacy implementation defect with a qualified correction. It is therefore eligible for B1 in principle.

Formal B1 admission is intentionally still blocked on one provenance item: the exact final E7 `fix.patch` payload must be recovered, stored and checked against the byte-exact B0 preimage. Until that happens, `b1-manifest.yml` must remain unchanged.

## Invariants / constraints

- mass-conservation requirements are unchanged;
- physical configuration is unchanged;
- the correction changes a Newton Jacobian derivative so that it is consistent with the residual's actual conductivity relation;
- no performance policy or alternate physics is introduced;
- SWAP5 reference mode should eventually qualify against this corrected behaviour once SWAP-011 is formally admitted to B1.
