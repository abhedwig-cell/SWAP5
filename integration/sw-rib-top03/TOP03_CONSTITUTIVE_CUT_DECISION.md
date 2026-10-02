# TOP03 actual-provider conductivity cutoff decision

## Outcome

The smooth analytic boundary derivative proposal is explicitly falsified BEFORE integration. At h=-0.001 cm its proposed derivative is approximately 26.1449 per day, but all four finite differences of the actual provider return zero. Four O0 runner invocations stop at this required oracle; neither analytic Jacobian variant reaches a physical integration, and their O2 phases are not run. Do not label those variants numerically qualified.

The failure reveals an actual source branch, not an error to hide by weakening the oracle. With the fixture air-entry head c(9)=0, the provider enters the near-zero-entry branch c(9)>-0.01 cm. Retention is linear above -0.01 cm. Conductivity additionally jumps to Ks whenever relative saturation exceeds 1-1e-6. The cutoff is not at exactly h=0, and it is not a smooth analytic MvG limit.

## Qualified source-bound oracle

The correct provider cutoff for this fixture is h=-0.012386042337589586 cm. Across bracketing widths decreasing from 1e-4 to 1e-9 cm, the conductivity jump does not vanish. At the finest bracket:

| Quantity | Value |
| --- | ---: |
| K on unsaturated side | 4.570054653885331 cm/day |
| K on shortcut side | 4.75 cm/day |
| Jump | 0.1799453461146694 cm/day |
| Jump relative to Ks | 3.7883231% |
| Central secant at +/-1e-9 cm | 8.9972673e7 per day |

Both geometries and O0/O2 reproduce all six oracle records exactly. The growing central secant reflects a nonvanishing discontinuity, not a reliable finite derivative. This helps explain why a finite-difference Jacobian near the branch can depend strongly on perturbation size. It does not show that all earlier derivative-probe failures have this cause.

The original B1.10 MOD_MvG_functions source contains the same shortcut. Its decoded hash is verified against its manifest: 4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1. Thus this is inherited reference behavior, not introduced by TOP03. The B1.11 module has a different manifest hash and was not recovered or asserted equivalent in this phase. The existing functions/headcalc eight-member B1.11 carrier does not include MOD_MvG_functions; it cannot establish that module's complete equivalence.

## Relation to the failed solves

In the original 109 failed grids, nine cross this conductivity cutoff in the last eight iterations, six repeatedly, and ten terminate within 1e-5 cm of it. After the pressure-aware progress improvement, 25 of the remaining 80 failed grids cross the cutoff, 19 repeatedly, and 21 terminate within 1e-5 cm. This is actual proposal/terminal-state evidence from the persisted traces, not an assumption from the pressure range alone.

The cutoff is therefore a concrete contributor candidate for a subset of retained failures. It is not a complete explanation of all failures. No claim is made that a coupled residual has no root: that would require a frozen-origin, source-consistent residual/bracketing test. A single discontinuous conductivity function is insufficient to prove absence of a whole-column root.

## Meaning for the route

The user's proposed investigation of an omslag was valuable. Besides flux/head switching at the surface, the constitutive provider has its own saturation shortcut transition. These must not be conflated. Adding a smooth derivative to an unsmoothed, discontinuous source residual is not a defensible general fix.

Before production changes, establish the reference-policy intent of this inherited shortcut and perform a bounded counterfactual or source-consistent branch/root test. Removing or smoothing the shortcut changes the physical/numerical reference behavior and must be declared and qualified as such, not described as a preservation-only Jacobian repair. A future counterfactual should hold accepted mass ownership and transactional publication fixed, compare complete-window transport and analytical controls, and report remaining failures and physical differences. Do not silently lower the threshold, add hysteresis, replace storage, or accept a failed solve.

Production TOP03 is still not qualified. Canonical advanced to 27b271c2 with ordinary prescribed-head application admission; this does not admit TOP03 or alter this standalone provider diagnosis. Shared backend reconciliation remains pending. No production source changed, no Actions run started, no canonical admission performed. PR #956 remains draft.

## Evidence and reproduction

Smooth-oracle checkpoint d6571001075a8eed3310d747657e5039f4edd62b; cutoff preregistration e4cdbdbd161ab994bab32f2b86bef5ff535ad333. Result, exact hashes, explicit negative-run scope and trace correlations: `TOP03_CONSTITUTIVE_CUT_RESULT.json`. Raw qualified cutoff records and failed smooth-oracle records: `evidence/constitutive_cut/`.

```sh
RUNNER_TEMP=/tmp/top03-cut-g2 bash tests/fapp/run_sw_rib_top03_constitutive_cut.sh tests/fapp/top03_consistent_shallow_stubs.f90 2 > /tmp/top03-cut-g2.log 2>&1
RUNNER_TEMP=/tmp/top03-cut-g3 bash tests/fapp/run_sw_rib_top03_constitutive_cut.sh tests/fapp/top03_deep_column_stubs.f90 3 > /tmp/top03-cut-g3.log 2>&1
python tests/fapp/analyze_sw_rib_top03_constitutive_cut.py --logdir /tmp
```

The analyzer also consumes the four failed smooth-oracle logs and the already persisted terminal traces. Negative runner exit 91 is expected research falsification, not a passing integration gate.
