# ROM-0T1Q1 strict-first successor Reference authority

T1Q1 is a new Reference-authority workunit. It does not turn the original T1 no-go into a pass.

The successor policy is fully specified by evidence that predates T1:

- P2E19 froze a dimensionally integrated balance allowance of **1.6e-15 cm per substep** for both compartment and total convergence and observed 72/72 neutral overlapping endpoints.
- P2E20 used that same allowance in a candidate-blind Reference construction.
- P2E21 retained the 1.6e-15 cm compartment allowance and replaced only the total allowance by a prospective representation-derived bound when larger:
  `max(1.6e-15, 0.5*sum((spacing(theta_s)+spacing(theta_base))*dz))`.

T1Q1 uses those formulas unchanged.

The algorithm is strict-first. Every refined interval first receives the exact original T1 controls. A strict pass is committed directly. A fallback can occur only after a retry leaves the committed state unchanged, and only if direct workspace diagnostics prove that the failed balance defects are inside the already frozen integrated allowances and there is no head/mixed/other convergence failure.

This construction has two important consequences.

First, all 87 refined steps accepted by original T1 before its three failures have a direct baseline counterpart and must remain **bit-identical**, including profiles, mass, boundary exchange and solver work.

Second, no observed T1 residual selects a tolerance. The T1 residual only determines whether an already frozen policy is eligible to handle that particular failed interval.

If the successor trajectories qualify, the original observation-interval floor is then measured at the 32 common times against the untouched 0.0016-day strict baselines. The differences are measurement-only; no threshold is inferred from them.

A pass creates research Reference authority for ROM-0 closure only. It is not a production tolerance admission.
