# DATAQUAL04 transition diagnosis

RT/HY/MP/VQ, baseline872cf5aacdd87981206c9c1b6d05318d26fad3e1.
Continue issue1458 from authenticated DATAQUAL03 checkpoint2.748 and executable.
The committed checkpoint is NOT the location of the eventual internal failure:
initial real replay reaches internal trial time2.848675 before full rollback.

First select observation-only expansion of existing opt-in macro diagnostic at
small dt, retaining raw full/half state/pond/GWL/topology and step status. Keep
production numerics/outputs unchanged when diagnostic is off. No new source law,
tolerance relaxation, temporal-component removal or restart retagging.
Invariants3,7,13,21,23,26. Numerical/physical changes require causal evidence,
separate explicit scope and real component/default/model/restart O0/O2 checks.

Cold restore compiler/provider closure because workspace maintenance removed local
objects. Record this cost separately. Start with authenticated old-executor replay;
new-executor old-binding runs are origin-state diagnostics only. Primary restart
qualification requires newly source-bound runs. No full481, broad F-CI, low-air or
RossFast selection. Stop local microrepairs if evidence points to coupled residual
or moving active-set ownership; retain every failed/censored attempt.

## Bounded iteration-budget experiment

Actual rejected trials exhaust64 Richards nonlinear iterations, while accepted
full/half errors approach roundoff. Expose the existing max_iterations control
as solver_max_iterations (default64;1..256); nondefault values require experimental
mode in both wrapper and native reader. Bind the value into the prepared input,
forward from JSON and record it. This changes a work budget, never convergence
or conservation tolerances. Compare64/128/256 on the same authentic origin and
classify those handoffs as diagnostics. If larger budgets still stall, stop budget
increases and diagnose the residual/Jacobian; do not spend a new long season run.
Production/comparison retain64 and must reject nondefault budgets atomically.

## Failed-trial cost accounting correction

Budget128/256 probes have different measured work/iteration exhaustion but identical
reported cost.csv counts. The macropore rejection branch returns before copying
matrix solver diagnostics to trial_outcome_t. Copy the same existing solver cost
fields (and read-only last observation) before that early return. No change to
retry/acceptance, state or equations. Qualify measured added counters against the
recorded rejected-trial diagnostics, O0/O2 and unchanged accepted/default outputs.
Do not infer failure-side balances from their uncomputed huge() sentinels.
