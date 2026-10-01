# TOP03 temporal controller route decision

## Result and scope

Two standalone research controllers were evaluated against 2048/4096 fixed-grid integrations. Ninety-six trajectories per optimization build; O0/O2 outputs and trace records agree exactly except CPU time. The maximum aggregate mass residual is 1.785e-13 cm. No production runtime or numerical-policy source changed, no Actions run started, no kernel candidate/receipt/commit was exercised.

State-only acceptance is falsified as a sufficient accuracy check for coupled throughput. In the consistent four-node, initially wet, prescribed-bottom-head profile, the state-only controller accepts one full/two-half window at budgets 0.01 and 0.0025 cm. Its accepted two-half top transfer is -2.3674801587183563 cm versus -2.881597243716140 cm on the 4096-step reference: difference 0.5141170849977836 cm (17.8414%). Final depth-weighted theta difference is only 7.947464267482607e-5 cm. The 2048-to-4096 top difference is 0.000326314644301 cm. Both final soil states are close while cumulative top and bottom throughput differ. Exact control-volume closure does not certify temporal accuracy.

Adding independently accumulated top and bottom transfers to the estimator rejects that coarse window. However, the specified linear-in-time allocation of the research error budget is falsified as a general repair within the tested step floor. Only 8 of 72 controller trajectories complete: 6 constant-bottom-flux wet controls and 2 state-only prescribed-head profiles exhibiting the throughput discrepancy. The other 64 report floor exhaustion, retaining only previously accepted local research progress. Eighteen of 24 uniform references complete; the six incomplete references are separately reported nonlinear failures in free drainage, not accuracy controls or ground truth.

A dry shallow prescribed-head onset illustrates the budget problem. At a full trial duration 3.814697265625e-6 day, all three Richards solves converge and pass mass checks. The full/two-half defect is 9.271594468635e-5 cm; the 0.01 cm window budget permits only 1.52587890625e-7 cm at that duration. The next reduction crosses the full-step floor 2e-6 day. It would be incorrect to describe this example as a Richards failure, or to silently loosen tolerances to obtain admission. Some deep initially wet cases make partial progress before exhausting the floor; partial progress is not a complete exchange window.

## Consequence for the route

The post-solve surface materializer and component receipt architecture remains the preferred mass/transaction design. Moving transfer into Newton would still substitute a trial provider evaluation for accepted interval transport. This experiment gives no reason to do that.

The outstanding numerical contract must explicitly include interval throughput as well as state accuracy. A simple replacement of exact identity by a state tolerance is unsafe; adding throughput with this linear time-budget allocation is also insufficient. Both negative results are persisted, and neither is production policy authority.

Next research should separate rapid imposed-head onset from later evolution and test a justified allocation of error across that event, with complete-window throughput comparisons and reference refinement. Do not infer a certified global bound from summing local embedded estimates. In parallel with that scientific analysis, the already documented near-saturation free-drainage convergence issue remains a separate solver limitation. Do not change the physical bottom mode or count a failed solve as accepted progress.

Production admission remains false. The actual top-active participant receipt/replay/exactly-once fixture remains blocked until an admitted temporal policy can create a valid complete candidate. PR #956 stays draft on the existing branch.

## Reproduction

Use GNU Fortran 13.3 and the repository runner with stock headcalc:

```sh
RUNNER_TEMP=/tmp/top03-controller-g2 bash tests/fapp/run_sw_rib_top03_temporal_controller.sh tests/fapp/top03_consistent_shallow_stubs.f90 2 > /tmp/top03-controller-g2c.log 2>&1
RUNNER_TEMP=/tmp/top03-controller-g3 bash tests/fapp/run_sw_rib_top03_temporal_controller.sh tests/fapp/top03_deep_column_stubs.f90 3 > /tmp/top03-controller-g3c.log 2>&1
python tests/fapp/analyze_sw_rib_top03_temporal_controller.py --logdir /tmp
```

Result: `TOP03_TEMPORAL_CONTROLLER_RESULT.json`; raw O0 records and traces: `evidence/temporal_controller/`. The result records O0/O2 identity, original log hashes and final research source hashes. The scientific preregistration preceded execution at commit 17fb8d0d15f04f3dcedfacc0e3338ddcdbd72fad; final additions publish whole-column endpoint states and diagnostic traces without changing controller rules.
