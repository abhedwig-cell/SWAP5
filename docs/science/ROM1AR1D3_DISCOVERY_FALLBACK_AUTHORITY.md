# ROM-1A-R1-D3 discovery-only local-plus-total policy qualification

D08 step 34 exposed a new failure class. The existing total-only fallback correctly
failed closed. D1 classified the failure as one local compartment-balance flag with
zero head flags. D2 showed that the local residual, integrated over the frozen step,
uses only 51.6% of the independently frozen 1.6e-15 cm compartment allowance from the
earlier PUB-P2E19/P2E20/P2E21 Reference research.

D3 now qualifies a candidate policy; it does not tune one.

Every interval starts with the exact original Reference controls. Successful original
attempts are committed unchanged. After a failed original attempt, committed state
must remain bit-identical and the failed solve is classified directly.

Two fallback classes are permitted:

1. RETRY_TOTAL_ONLY — the already qualified D2/D4 semantics. Only the total criterion
   is representation-bounded; the local compartment criterion remains 1e-12 cm/day.
2. RETRY_LOCAL_BALANCE — zero head flags, every local residual bounded by the
   independently frozen 1.6e-15 cm integrated allowance, and total residual inside
   the pre-solve total representation bound. Only on the one fresh-backend same-step
   reattempt are the compartment and total criteria set from those pre-existing
   bounds.

Any head failure, mixed failure, bound exceedance, diagnostic mismatch or failed
reattempt is fail-closed.

Qualification uses D01-D08 only. H01-H04 and B14 remain unopened. A positive result
freezes the policy before the held-out library is generated.
