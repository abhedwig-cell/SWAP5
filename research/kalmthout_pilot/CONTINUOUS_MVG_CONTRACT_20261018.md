# Continuous conductivity experiment, not canonical admission

The historical default MvG provider sets K=Ks when Se > 1-1e-6.
For this parameter set its left-hand K is 4.570054660442483 cm/d;
its right-hand K is 4.75 cm/d. The 3.94% jump is inherited from B0
SWAP4.3.1 (MOD_MvG_functions.f90), not a new migration transcription error.

In the consistent 34-node/200cm test, this triggers non-vanishing full/half
pressure differences under explicit frozen-per-solve conductivity. Near the
failure the maximum difference tends to .04450758135 cm while the water-content
difference tends to machine precision. The unchanged temporal limit is .03 cm.
No Rutter source-identity mismatch was observed in the isolated hour diagnostic.

Research build `build_local.py OUT -O2 research/kalmthout_pilot/matched200_context.f90 continuous`
changes only that guard to `head >= 0`. At h<0 it evaluates the already present
MvG K(Se) expression, instead of imposing the discontinuous saturation plateau.
The retention equation, parameters, source/flux, hard mass gate, temporal gate,
Newton head and balance criteria are unchanged. The full-production residual
and Jacobian remain unchanged. This is a scientific hydraulic contract change,
not a tolerance fix. It needs hydraulic-owner qualification/reference-policy
review before any production/canonical admission. Do not infer historical bit
parity with the original plateau, or local Kalmthout validation.

The original 3cm pilot blockage is independently resolved with max_backtracking=32,
max_iterations=40; the default 8/4 fixture budget is insufficient. Those budgets
change effort only. Full original historical run, deterministic repeat, original
O0/O2 1700h identity and bootstrap owner O0/O2 tests have been executed.
