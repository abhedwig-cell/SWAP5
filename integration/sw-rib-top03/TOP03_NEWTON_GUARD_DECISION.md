# TOP03 Newton trial guard route decision

## Result

The two preregistered caps on the initial Newton direction remove the extreme-trial boundary switching but do not repair any of the original nonlinear failures. This distinguishes a visible numerical symptom from a sufficient explanation of the TOP03 blocker.

Each cap was tested on 702 trajectories in each O0/O2 build: 2808 guarded integrations total. Numerical records and failed-solve snapshots agree exactly between optimizations except CPU time. The physical residual, Jacobian, constitutive relations, boundary equations, pressure and mass tolerances, line-search progress condition and 80-iteration limit were held unchanged. Production source did not change.

| Research cap | Original failures repaired | Original failures retained | New failures | Within-solve type switches |
| --- | ---: | ---: | ---: | ---: |
| 1 * max(1 cm, abs(h)) | 0 | 109 | 0 | 0 |
| 0.1 * max(1 cm, abs(h)) | 0 | 109 | 21 | 0 |

The unguarded baseline has 40 observed within-solve type changes in 20 trajectories. Both caps remove those changes, yet retain every original failed trajectory. Cap 0.1 also introduces failures including previously complete fixed-flux and fixed-head cases. A direction cap alone is therefore explicitly falsified as a sufficient general repair. This does not falsify all trust-region/globalization or active-set methods.

Both caps preserve all 156 analytical saturated/pond-establishment controls. Maximum aggregate mass residual is <=1.905e-13 cm. Among trajectories complete in both baseline and cap runs, the maximum top-transfer difference is <=1.817e-13 cm. This is a narrow complete-window transport preservation result, not proof that all internal states or incomplete trajectories agree.

Total nonlinear iterations across the factorial set are 1,285,898 unguarded, 1,286,177 at cap 1 and 1,326,803 at cap 0.1. These counts include partial/failed trajectories; they are cost diagnostics, not a portable performance benchmark.

## Consequence

Do not promote these caps to production. They can suppress enormous intermediate pressure proposals but do not establish reliable convergence, temporal accuracy or a valid external-top participant candidate. Do not increase the iteration ceiling or relax head/mass convergence to hide the retained failures.

The next discriminating diagnosis is the stalled free-drainage iteration itself: trace residual, proposal, accepted line-search factor and constitutive/boundary terms through the terminal iterations. Determine whether the incomplete boundary Jacobian/fixed-interior-conductivity staging causes noncontractive iteration or whether a saturation transition requires a different safeguarded nonlinear solve. Earlier finite-difference boundary Jacobian probes were also insufficient and remain negative evidence; do not repeat them as an assumed repair.

Complete-window temporal throughput acceptance remains a separate unresolved prerequisite. The surface mass materializer stays post-solve; component receipts cannot qualify or commit a rejected physical trajectory.

## Evidence

Preregistration checkpoint: 8559048762c44ce3223f42e46b446f5503b99e48. Generator: `tests/fapp/make_top03_newton_guard_probe.py`; only generated scratch headcalc is altered. Result, final source hashes and log hashes: `TOP03_NEWTON_GUARD_RESULT.json`. Raw O0 numerical records and identical O0/O2 stop snapshots: `evidence/newton_guard/`.

```sh
# Repeat for geometry 3 with top03_deep_column_stubs.f90 and for cap 0.1.
RUNNER_TEMP=/tmp/top03-guard-g2-c1 bash tests/fapp/run_sw_rib_top03_newton_guard.sh tests/fapp/top03_consistent_shallow_stubs.f90 2 1 > /tmp/top03-guard-g2-c1.log 2>&1
python tests/fapp/analyze_sw_rib_top03_newton_guard.py --logdir /tmp
```

GNU Fortran 13.3 with O0/O2, bounds/runtime checks and floating-point traps. Canonical/AGENTS unchanged during the phase. No Actions run requested. PR #956 remains draft; no production admission, canonical merge or live Ribasim qualification.
