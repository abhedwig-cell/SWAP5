# Bounded changing-storage correction result

Checked O0/O2,192 prescribed water-balanced single steps on24 uniform cells:
Freundlich exponent0.5/1/2, Kf0/0.2, two flux-gradient signs, dt0.01/0.2day,
Gaussian, sharp square, constant and zero concentrations. Water varies in space
and changes locally with the supplied face divergence. Real6 production
providers plus1 research provider. No copied or mocked production process.

All96 nonconstant cases have a nonzero conservative correction. All96 constant/
zero cases retain the exact solution within8.78e-15 concentration. Independent
stable algebraic roots reproduce the triangular low-order solve within1.37e-14
and corrected total cell mass within4.48e-15mg/cm2. Maximum mass residual is
1.46e-15mg/cm2; maximum equilibrium residual1.75e-15mg/cm2. Optimization drift
is2.09e-17. All2880 unsupported/malformed-state rejections preserve every state
field exactly;384 OFF delegations, including unsupported dispersion, match the
actual production call. Boundaries retain low-order fluxes and receipts exactly.

The first native192-case round succeeded but its Brent-based independent oracle
failed on near-zero sharp tails. Both original source/native streams and a
separate exact-source reproduction of that assessment failure are retained.
The final oracle uses stable exact quadratic roots, not relaxed thresholds.
Qualified compile/execution cost4.502s on this host, not a speedup claim.

The source-bound812-member capsule and eight negative evidence controls are
described in `EVIDENCE_INDEX.json`. The current original owner passes17 controls;
the frozen linear prototype passes its six controls. Existing production source,
defaults, physical balances, accepted state, restart and native caller are not
modified. The previous uniform-advection accuracy evidence is not relabelled
as nonlinear changing-water accuracy. Actual accepted-water trace replay,
time-series convergence, active sources/crop/dispersion/decay, restart and native
activation remain open. This is bounded research, not full MC-SOL01 closure.
