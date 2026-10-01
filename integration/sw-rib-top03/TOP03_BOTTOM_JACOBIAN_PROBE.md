# Free-drainage Jacobian causal probe

Status: PREREGISTERED_RESEARCH_ONLY
Baseline diagnostic source: 70cefc280426b65cc0d436ffc7c339732dd860c1

Stock factorial runs show free-drainage nonlinear retries in both shallow and deep cases, while fixed bottom flux/head complete every grid. The exact saturated steady control completes everywhere. This localizes an interaction with the free-drainage boundary but does not yet prove the cause.

Source: free drainage residual includes -qbot=K(h_N), while the SwKimpl=0 bottom Jacobian omits dK/dh_N. A lagged/Picard conductivity policy may be intentional; missing this term is not automatically an admitted defect. Test a causal perturbation, without changing any residual, physical parameter, tolerance, iteration limit or time-acceptance rule.

Generate an isolated HeadCalc copy at build time that adds only the bottom-residual conductivity derivative, estimated by central differences with relative/absolute steps 1e-5 and 1e-6 cm. Restrict to explicit default MvG provider, SwKimpl=0 and no macropores. Record original source SHA256. Production source is not edited. Compare the same 3 geometries x 3 lower boundaries x 3 initial states x 2 horizons x 10 grids under O0/O2. The fixed flux/head branches and exact saturated steady control must remain unchanged. Compare complete refinement sequences and mass gates. Completing after this perturbation supports a bottom-Jacobian convergence explanation; disagreement between epsilon sizes or new failures prevents selecting it as production repair.
