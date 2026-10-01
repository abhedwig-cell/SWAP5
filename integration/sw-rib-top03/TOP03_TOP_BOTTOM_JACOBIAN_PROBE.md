# Combined boundary-Jacobian causal probe

Research only. Bottom-only central-difference correction at both 1e-5 and 1e-6 reduces but does not eliminate nonlinear retries (stock 46/540 grids incomplete; bottom-only 31/540). Therefore a bottom-only fix is falsified as sufficient.

The external dynamic provider recomputes arithmetic-mean surface-face K(h1) during residual evaluation. The existing head-boundary Jacobian contains K_face/d but not -dK_face/dh1 * gradient. Extend the isolated build-time research copy with that top diagonal term, only for imposed external head, arithmetic mean, default MvG, no macro. Compute dK_face/dh1=0.5*dKnode/dh1. No residual or conductivity policy changes. Repeat the same factorial experiment with both finite-difference scales. Test whether boundary derivative consistency alone removes retry; do not infer production admission from this experiment.
