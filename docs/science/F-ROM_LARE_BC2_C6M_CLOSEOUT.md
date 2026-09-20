# F-ROM-LARE BC2-C6M closeout

## Decision

C6M closes as **Reference-route numerical-policy blocked**, before any Layer-ROM surface response.

The first attempt used free drainage (bottom mode 7). The frozen Reference-floor sampling API does not admit that mode, so all 64 jobs were rejected before a surface Richards solve.

The preregistration was then reconciled, before an admitted response, to bottom mode 5 with the lower pressure head held at the initial equilibrium value. That route is admitted and does produce surface-driven trajectories. However authority run `35531907787` still failed 64/64 slices because C6M retained a strict-first numerical policy and did not preregister a mode-5 retry route.

A non-authoritative B01/R1024_T16/O0/S01 diagnostic accepted 260 transaction steps and then reached `legacy-reference-retry` at transaction 261 after 16 nonlinear/backtracking attempts. C6M correctly failed closed.

## Interpretation

This does not reject the surface-driven purpose question, bottom mode 5, or Layer-ROM. It means the C6M Reference numerical policy was not sufficiently bound for this high-resolution surface workload.

The pre-existing D13/C4Z prescribed-head retry policy is deliberately not retrofitted after seeing C6M response. S01-S04 are therefore not reused for a confirmatory Reference retry.

No Layer-ROM candidate was executed, so candidate surface fidelity remains unexposed.

## Next work unit

C6M2 moves to a Reference route already inside the qualified DYN0A numerical boundary: a **fixed bottom flux equal to the initial gravity-equilibrium flux**, with only the top flux varying.

That experiment can test whether the existing reduced state placement is sufficient for surface-driven upper-zone/profile redistribution.

It cannot establish drainage or recharge fidelity because bottom exchange is prescribed. Drainage/recharge remains a separate evidence gap.

C6M2 must use fresh histories and qualify the high-resolution Reference before any reduced response.
