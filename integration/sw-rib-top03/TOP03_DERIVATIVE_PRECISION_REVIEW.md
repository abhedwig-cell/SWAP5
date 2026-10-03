# TOP03 derivative precision and recovery review

Date: 2026-10-03. Baseline: `1571f0f0752c737db15d4f68c6dcacc7b1c5fa40`.
Status: **bounded analytic mechanism reproduced; production admission remains open**.

## Recovered state and independent replay

The current branch is `work/sw-rib-top03-transactional-top-exchange`, draft PR #956. The joint-nearsaturation decision's final analytic-derivative and width-bracket sections supersede its earlier non-robust-candidate wording. The route status record had not incorporated those later results.

This review replayed the unchanged pinned runner locally with GNU Fortran 13.3.0, O0/O2, runtime checks and floating-point traps:

```text
bash tests/fapp/run_sw_rib_top03_joint_microrelief_probe.sh 0.2 pulse 1e-12 legacy extended analytic
bash tests/fapp/run_sw_rib_top03_joint_microrelief_probe.sh 2 pulse 1e-12 legacy extended analytic
```

Both runs complete all six refinements (1/2/4/8/16/32), and their O0/O2 raw output is identical. Newton totals are 3,046 and 3,329 respectively. Combined balance errors are at most 1.47e-14 and 1.22e-14 cm. The latter value corrects the earlier prose's 1.18e-14 maximum, which omitted the first refinement. Maximum per-step soil balance errors are 7.80e-15 and 1.88e-14 cm. These runs reproduce the prior records; they do not add a new physical envelope.

Full replay logs are retained under `evidence/derivative_precision_audit/`. No production source or numerical tolerance changed. The laws remain generated research providers; the bottom Jacobian term remains a test-only transformation.

## Corrected interpretation of the narrow-width oracle

The earlier five-head binary64 finite-difference oracle stopped the 0.02 cm trajectory run at h=-0.0001 cm. That stopping event is retained and was real, but it does not by itself establish a faulty analytic derivative.

A standalone compiled provider audit now samples 37 distinct strictly in-band heads over widths 0.02/0.2/2 cm. The O0/O2 records are identical. An independent Python Decimal oracle evaluates the declared smooth mathematical K law at 80 digits using the fixture's binary64 hydraulic parameter values. Its derivative is evaluated by a centered difference and checked again at half the perturbation. The largest step-halving discrepancy is 1.10e-14. All 37 analytic values satisfy the inherited gate `1e-6 + 2e-5*abs(reference)`.

At the previously failing head and width:

| Quantity | dK/dh |
| --- | ---: |
| Compiled analytic derivative | 1.5684549733050464e-5 |
| 80-digit finite-difference oracle | 1.5684031832802894e-5 |
| Original binary64 finite difference, eps=1e-6 cm | 1.0687006835041755e-5 |
| Absolute analytic versus high-precision difference | 5.1790e-10 |

The binary64 difference subtracts K values differing by only 2.14e-11 cm/day. Reducing eps from 1e-6 to 1e-10 cm does not reliably approach the high-precision value. The intermediate theta/effective-saturation calculation is near its saturated endpoint; cancellation and finite representation therefore matter before the final K subtraction. This is evidence of a precision-sensitive oracle/implementation path. It is not evidence that the analytic derivative of the declared smooth law is wrong.

The distinction is important: the high-precision oracle evaluates the mathematical law, not the staircase of its binary64 evaluation. Passing it does not qualify numerical conditioning of the implemented K map. The compiled provider's endpoint guard can return zero where the smooth law has a small nonzero derivative; the largest absolute difference in this audit is 6.73e-8, inside the existing absolute gate. Relative accuracy near those tiny derivatives is not established.

Accordingly, the earlier statement that this event rejects the narrow-band analytic implementation is superseded by **analytic law supported in the sampled material/band; binary64 conditioning and trajectory qualification unresolved**. The 0.02 cm trajectory remains unrun by the analytic counterfactual. No width is physically calibrated by this audit, and no production code or legacy failure record is changed.

Reproduce the audit with:

```text
python tests/fapp/audit_top03_joint_derivative.py --compiler gfortran --output /tmp/top03-derivative-audit
```

The machine record includes the compiler, pinned baseline, generator/audit hashes, all high-precision comparisons and five binary64 perturbations per sample. Its scope is one inherited MvG material without KSATEXM or elastic storage. It does not cover outside-band provider branches, demand-only DKDH combinations, full hydraulic parameter ranges, or extension options.

## Remaining gates and next safe work

The immediate candidate remains a common near-saturation theta/C/K law with a residual-consistent analytic free-drainage Jacobian. The existing continuous integrated microrelief store suffices in the reproduced case; a quintic surface law is not shown to be necessary. Soil transition width and physical surface hypsometry remain distinct parameters. Soil pressure head and external stage need an explicit common elevation datum, not an implicit equivalence between saturation and terrain height.

Before production porting, establish a stable theta-deficit/effective-saturation evaluation and consistent derivative demands over the owning provider's complete declared envelope. Reconcile concurrent HeadCalc/provider work rather than applying the scratch transformation directly to canonical. Then qualify top-boundary preservation and accepted-window state/top/bottom error budgets. Reject/replay, restart, exactly-once signed exchange, external storage ownership and real Ribasim publication remain separate open gates. A direct-solver mass balance does not close them.

No Actions run, canonical merge, production admission or background continuation is claimed.
