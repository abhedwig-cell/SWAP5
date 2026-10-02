# TOP03 terminal-iteration diagnosis and residual-progress result

## Confirmed mechanism and bounded intervention

Observational instrumentation exactly reproduces all 702 unguarded numerical records, stop snapshots and iteration counts per optimization, excluding CPU. This rules out the trace itself as a numerical perturbation. O0/O2 trace records agree exactly.

The existing line-search test permits a candidate if its squared residual norm decreases OR its maximum compartment residual is below the mass threshold. In the latter case, pressure corrections may still exceed their original convergence thresholds. The terminal trace observes 368 such nondecreasing-residual candidates while pressure remains unconverged. Of the 109 failed solves, 62 end with compartment and total residual criteria met but pressure corrections still above the pressure tolerance. Six terminate with backtracking exhausted. The remaining failures must not be attributed solely to the small-mass shortcut.

A preregistered research-only variation retains residual descent and permits the small-mass shortcut only if the scaled pressure correction also meets both original head tolerances. It does not loosen final convergence, increase the iteration ceiling, alter physics or add mass. The original exhausted-backtracking behavior remains unchanged.

| Result per optimization | Instrumented original | Pressure-aware shortcut |
| --- | ---: | ---: |
| Complete trajectories | 593 | 622 |
| Failed trajectories | 109 | 80 |
| Original failures repaired | 0 | 29 |
| New failures | 0 | 0 |
| Terminal pressure-only failures | 62 | 3 |
| Observed nondecreasing shortcuts while pressure unconverged | 368 | 0 |
| Terminal exhausted line searches | 6 | 9 |

Both variants pass all 156 analytical saturated/pond-establishment controls. Maximum aggregate mass residual is 3.998e-13 cm. Complete-in-both interval top transfers differ by at most 3.020e-14 cm. These transport/control checks are not proof of equality of every internal state. O0/O2 numerical, stop and trace identity holds for both variants. The two variants together require 2808 local integrations.

The intervention demonstrates that the permissive progress shortcut is causally involved in some failures. It does NOT prove that every pressure-only failure has been repaired: the altered iteration path can move the first failing substep, and pressure-only failures can become balance failures. Eighty complete-window failures remain, all under free drainage in this bounded factorial set. The finest shallow dry/wet and deep initially wet free-drainage profiles still fail. These must not be promoted as complete exchange windows.

## Example

In the shallow dry/free-drainage constant-head case with 512 subdivisions, the original failed substep 24 oscillates near bottom pressure -0.0281421 cm. Iteration 73 increases the squared residual norm from approximately 3.648e-20 to 1.681e-19 while the maximum rate residual remains below 2.048e-9 cm/day. The head correction is approximately 1.404e-10 cm, exceeding the 1e-12 cm pressure criterion. Several further full steps similarly increase residual before a one-third step reduces it. At iteration 80 pressure still has not converged. This is not a large accepted hydraulic excursion or a provider receipt; it is an incomplete nonlinear solve.

The tiny pressure tolerance is an existing bounded BASE configuration, not an empirically justified hydrologic accuracy norm. Its practical appropriateness can be studied under the owning numerical policy, but this experiment did not relax it. Changing it would require separate complete-window accuracy evidence; it must not be presented as fixing the residual/Jacobian mechanism.

## Route and next step

Keep the pressure-aware progress condition as a research candidate, NOT production source or admission authority. Its bounded benefit is supported; its sufficiency is falsified by the 80 remaining failures.

Next diagnosis should inspect the retained residual/boundary iteration and validate a provider-consistent derivative or safeguarded root step against the actual residual, including candidate-dependent free-drainage conductivity and top-face conductivity with frozen interior conductivity. Earlier finite-difference boundary probes were insufficient and should inform, not be ignored by, that work. Also treat exhausted line-search handling as a separate numerical-policy decision.

The independent temporal problem remains: exact identity rejects transient candidates, state-only acceptance can mask cumulative throughput, and the tested linear time-budget controller exhausted its step floor. Successful nonlinear integration alone would still not authorize participant publication/commit. Production source, transactional APIs and final acceptance are unchanged; PR #956 remains draft. No Actions run was requested.

## Evidence

Initial trace checkpoint d91e99a4a1a2d49178f34dd6c1efca6cbd68eb02; source extension checkpoint 71bb2d49c68639df7b48df167380c007d82acf5a before strict-progress execution. Result/source/log hashes: `TOP03_TERMINAL_TRACE_RESULT.json`. Raw O0 numerical records, failed-solve snapshots and terminal-iteration records grouped by profile: `evidence/terminal_trace/`. Exact O0/O2 identity is independently asserted by `tests/fapp/analyze_sw_rib_top03_terminal_trace.py`.

```sh
# Repeat for geometry 3 using top03_deep_column_stubs.f90.
RUNNER_TEMP=/tmp/top03-terminal-g2-stock bash tests/fapp/run_sw_rib_top03_terminal_trace.sh tests/fapp/top03_consistent_shallow_stubs.f90 2 > /tmp/top03-terminal-g2-stock.log 2>&1
RUNNER_TEMP=/tmp/top03-terminal-g2-strict bash tests/fapp/run_sw_rib_top03_terminal_trace.sh tests/fapp/top03_consistent_shallow_stubs.f90 2 strict > /tmp/top03-terminal-g2-strict.log 2>&1
python tests/fapp/analyze_sw_rib_top03_terminal_trace.py --logdir /tmp
```
