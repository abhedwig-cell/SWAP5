# ROM-0R R3D4 fail-closed total-only fallback authority

R3D4 is a research qualification of a conditional Reference policy, not a reinterpretation of R3 and not a production fallback.

The authority chain is deliberately narrow. R3D1 established that both B01 failures are total-balance-only. R3D2 established, using a formula fixed independently in PUB-P2E18D3/P2E21, that their integrated residuals are within a prospective floating-point representation scale. R3D3 showed why applying the wider total criterion from the start is unacceptable here: it changes already valid Newton stopping points and fails bit-level overlap neutrality.

R3D4 therefore keeps the original R3 criterion as the first and authoritative attempt for every interval. If it succeeds, its candidate is committed unchanged and no fallback is allowed.

Only after an original attempt fails may a research-only fallback be considered. Before the failed solve, the representation bound must already have been computed from the accepted base state:

`B_rep = 0.5 * sum((spacing(theta_s) + spacing(theta_base_i)) * dz_i)`.

The failed interval is then independently reproduced through the direct Reference solver. Fallback is allowed only if:
- the failure is exactly RETRY_TOTAL_ONLY;
- local balance and head convergence are already satisfied;
- the integrated signed total residual magnitude is no larger than the pre-solve representation bound;
- the FMR and direct failure diagnostics agree;
- the failed first attempt has not changed committed lineage, revision, time or physical state.

The same interval may then be attempted once with only:

`CritDevBalTot = max(1e-12, B_rep/dt)`.

There is no timestep subdivision, no amplitude change, no empirical factor and no relaxation of the hard transaction mass gate. A fresh backend is used for the fallback attempt so failed solver scratch cannot become continuation state.

This construction preserves every original accepted overlap endpoint by design. It may still fail qualification if any trigger is not total-only, if the bound is exceeded, if fallback fails, if B14 ever needs fallback, if the full trajectories do not complete, or if directional reachability is lost.

A pass would qualify only this frozen ROM research Reference policy. F-PE04's production FALLBACK status remains DEFINED_NOT_ADMITTED.
