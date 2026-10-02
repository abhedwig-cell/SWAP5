# TOP03 stationary-layer numerical-policy reconciliation

Date: 2026-10-02. Observational follow-up preregistered before execution.

The final-head face audit at source 1276dbc2e8a6c165842cac048d51d07ee993e599
fails the unchanged 1e-10 cm integrated local and interface-ledger hard gates.
All 144 explicit-layer dynamic cases fail at least one such audit. The run
still completes all 192 cases/build, with exact O0/O2 identity and inherited
trajectories unchanged. Keep this failure; do not relax the audit threshold.

Source review of HeadCalc's initial constitutive evaluation and SWKIMPL=0
iteration confirms that interior K/Kmean is frozen at solve entry, while the
dynamic surface face and free-drainage bottom can use candidate heads. Only
SWKIMPL=1 refreshes interior K during candidate iterations, and that mode is
not admitted by this fixture. The original declared policy is deliberately
held fixed. Adding zero-capacity rows therefore gives a lagged discrete layer,
not a fully nonlinear stationary closure evaluated at all candidate pressures.
This is a model/policy mismatch in the proposed research oracle, not proof of
a production solver defect or failure of its source-bound water balance.

Retain the failed final-head audit and add a separately named FROZEN_AUDIT.
Reconstruct interior harmonic K from immutable solve-origin heads, top flux
from the dynamic provider at candidate pressure, and layer water storage from
candidate versus origin water content. Apply the same 1e-10 cm local integrated
and cumulative interface-ledger hard gates. This checks the implemented scheme;
it cannot make the final-head stationary audit pass or admit a stationary
contact law. Require all other raw lines to reproduce both preceding phases
exactly at O0/O2. Execute the same 192-case matrix with diagnostic-only edits.
Report the pre-audit budget classifications as provisional observations, and
block stationary-closure physical verdicts if the current-K prerequisite fails.

Canonical moved from 800f6a9b to 0c18a9ff during this research. The inspected
delta adds LOW03-A implicit Cauchy application/binding and mode3 bottom temporal
stiffness, unrelated oxygen optimization and LOW08-P0 preregistration. The
compiled temporal-indicator dependency and serialized application ownership
have changed upstream. This dedicated-branch test remains bound to its exact
research source; no current-canonical runtime/transaction qualification is
inherited. Production interfaces and canonical branch remain untouched.
