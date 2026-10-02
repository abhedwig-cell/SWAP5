# A27 bounded wall-history approximation diagnostic

Status: PROPOSED_RESEARCH_ONLY. Date: 2026-10-02 UTC.
Completed exact-cohort reference: f5a7c4165c9db7c82a3fdd7e611d9e9030c2ec2c (400 cases).
The exact interval list reproduces mixed-age uptake but grows with accepted timestep count, including positive-S IC-input histories. Preserve these negative bounded-state findings.

Research numerical approximation, identical across cases:
- mode 8: at most 8 contiguous wet-history intervals per matrix node;
- mode 9: at most 16 intervals per node.
These are numerical history resolutions, not physical pore parameters or per-case fitted values.

After successful interval preparation, reduce to the fixed limit before calculating the trial flux. Merge the adjacent pair with smallest relative age separation abs(age1-age2)/(age1+age2+dt); ties select the first pair. Conserve interval length and length-integrated seed S. If total S-weight is positive, assign S-length-weighted mean age; otherwise use length-weighted mean age. Retain complete disjoint geometric coverage. The frozen-S square-root law is not closed under such averaging; this is an explicitly approximate route, not exact preservation. It must be measured against mode 7.

Repeat 2 Ks x 5 states x 10 modes x 5 dt = 500 cases. Compare modes 8/9 to 7 at identical soil/state/dt using entire 0.1-day-sampled trajectories: receiver storage, integrated exchange, bottom transfer, top/mid/bottom matrix head/theta, mass balance, refinement, maximum cohort count and packed bytes. CPU realizations are retained but not a portable speedup claim or a full paired production benchmark.

Preregistered internal approximation screen (not full A27 production E1): maximum sampled receiver, integrated-exchange and bottom cumulative differences <=0.01 cm, selected matrix theta difference <=0.001, selected head difference <=1 cm. Report absolute errors and every failing case, not only pass counts. These prospective diagnostic thresholds do not override the full production equivalence criteria and are not adjusted after results.

Keep age mixing falsifiers: a successful bounded approximation is still not an exactly sufficient scalar state. Fail closed on invalid limit/geometry. Acceptance and reject/replay history remain trial-local, and production A26H, source repair, persistence and central admission boundaries remain unchanged.

If neither fixed limit meets the screen in the growing positive-S IC-input regime, classify this particular numerical approximation as unsuitable there. If one passes, recommend it only as a research continuation candidate for independent physical closure validation and the unrun full production A/B/C benchmark.
