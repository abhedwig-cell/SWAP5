# ROM-0R R3D2 representation-floor diagnostic

R3D1 established that both B01 prescribed-head failures are total-balance-only retries. R3D2 asks a narrower question: is the integrated total residual already below the independently established prospective floating-point representation bound from PUB-P2E21 when that bound is evaluated from the accepted predecessor state before the failed solve?

The imported formula is:

`0.5 * sum((spacing(theta_s) + spacing(theta_base_i)) * dz_i)`.

No observed failed residual enters that formula and no empirical factor is permitted.

R3D2 does not apply this bound as a convergence tolerance. The failed interval is still run with the original R3 controls. Therefore a positive result is explanatory evidence only. Any use of a representation-bounded total-balance policy on ROM-0 trajectories requires a separate preregistered qualification with endpoint-neutrality and hard-mass preservation gates.
