# TOP03 temporal controller research preregistration

Research only. No production policy, candidate, receipt or admission claim.
Canonical 828df126e0c0d70f5cbfae51614bfc3b53e832a4 contains only lower-boundary source/design documents since 44c6df; no production numerical delta. AGENTS unchanged.

Compare uniform 2048/4096-step references with full-versus-two-half controllers over 0.25 day. Consistent shallow four-node and 100 cm forty-node geometries; dry (-123 cm) and initially wet (-10 cm); bottom modes 2, 5 and 7 kept physically distinct. External head 0.02 cm, sill 0.01 cm, previous pond 0.02 cm. All constitutive and solver settings unchanged from boundary diagnosis.

Policy 1 measures depth-weighted absolute water-content difference plus pond storage difference. Policy 2 additionally measures cumulative signed top transfer and bottom transfer differences, using the maximum of these three centimetre measures. Absolute research budgets 0.01, 0.0025 and 0.000625 cm are distributed as budget times trial duration / complete window. These are experimental budgets, not production defaults or certified global error bounds. Accept the two-half trajectory only after all solves and mass checks pass; restore the origin on every rejection. Retry by halving; grow by two only below one quarter of the allowance. Full-step floor 2e-6 day, 50000 trial limit. Report exhaustion; never accept a failed nonlinear solve. Positive accepted qtop remains fail-closed.

Hypothesis: final water state alone does not resolve throughput error under prescribed-head lower boundaries. Adding transfer to the estimator may improve control but can still fail on nonlinear convergence or saturation. Falsify rather than relax budgets. Report reference differences and cost; fine grids are comparisons, not ground truth. Require O0/O2 identity excluding CPU time, soil residual <=1e-10 cm, surface closure <=1e-12 cm, aggregate ledger <=1e-10 cm. No Actions needed for isolated research.
