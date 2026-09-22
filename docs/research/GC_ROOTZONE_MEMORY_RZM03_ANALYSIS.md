# GC-RZM03 qualification analysis

Date: 2026-09-22  
Decision: **QUALIFIED_BIDIRECTIONAL_SIGNED_TRANSFER**

Workflow run 35703505239 completed successfully. RZM03 passed 7/7 tests and
RZM01/RZM02 both remained green.

The main result is structural. Upward capillary supply does not require a
second constitutive branch in this analytical ladder. The already frozen laws
`q_v=C_v(h_r-h_l)` and `q_c=C_c(h_l-H_c)` carry downward, zero and upward
exchange through their sign. In particular, MODFLOW-to-SWAP supply is simply
negative accepted `E_c`. It increases SWAP inventory and decreases the
groundwater storage cell by exactly the same amount.

This preserves the fixed-interface interpretation. The root zone never sees
the MODFLOW head directly. Water supplied from below first enters the lower
SWAP state and is then transferred upward according to the internal
root/lower gradient. Therefore adding root-zone memory has not created a
second groundwater interface.

The zero-gradient control is stationary, and symmetric perturbations around
equilibrium produce opposite-signed exchanges. This is useful evidence against
one-sided clipping or hidden direction-specific bookkeeping. It is not evidence
that real unsaturated conductivity is linear or symmetric.

## Decision

Phase E is closed for the linear analytical surrogate. The next falsification
step is deliberately nonlinear: introduce one minimal state dependence while
keeping the same storage ownership, fixed plane, sign convention and exact
ledger. The purpose of RZM04 is not realism by accumulation. It is to determine
precisely which result from RZM01-RZM03 breaks first when the internal response
ceases to be linear, especially the exact scalar affine whole-window
condensation.
