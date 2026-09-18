# ROM-0 final Reference-authority closeout

## Decision

**NO_GO_REFERENCE_AUTHORITY** for the preregistered B01+B14 pure-hydraulics ROM domain.

This closes ROM-0. It does not authorize ROM-1A.

## Why this is the correct close decision

ROM-0 was allowed five outcomes: proceed, expand the Reference floor, expand the accepted trajectory domain, block on an observation seam, or close Reference authority as no-go.

The workstream already used the accepted-domain expansion route. R1 repaired the physically inconsistent seed construction. TA1 through TA5 then separated temporal-indicator semantics, application-budget circularity, fixed-resolution Reference-floor sampling, restart/replay and prescribed-head sampling without changing Richards physics or hiding failed attempts.

R3 was the bounded test of the remaining lower-boundary reachability gate. Its outcome is not an interface defect:

- the prescribed-head sample route itself is qualified;
- B14 completes both rise and fall trajectories and shows the expected directional storage and bottom-exchange separation;
- B01 accepts long prefixes of both trajectories, then independently reaches `legacy-reference-retry` under the frozen 0.0008-day resolution and frozen Reference controls.

The R3 preregistration explicitly requires both directions for both materials and forbids post-result amplitude, timestep, iteration/backtracking, retry-policy and material tuning.

Therefore another “repair” inside the same experiment would violate the preregistration rather than complete it.

## Gate adjudication

**Q0.1 Ownership:** pass within the research sample scope. Candidate/commit authority remains F-KT-owned.

**Q0.2 Reproducibility:** pass for the retained 0.0008-day candidate. TA4 proves exact Restart-v1 continuation with a fresh backend and no worker/solver scratch persistence.

**Q0.3 Conservation:** pass for retained accepted samples. Failed solver samples are not promoted.

**Q0.4 Bidirectional reachability:** fail for the declared two-material domain. B14 passes; B01 does not complete either full-horizon prescribed-head direction.

**Q0.5 Reference floor:** incomplete. The temporal 0.0016-versus-0.0008 component is measured, but the required vertical-resolution component is not authorized after the R3 prerequisite fails.

**Q0.6 Non-mutation:** pass for the governing claim. No Richards physics or solver controls were changed. TA5 adds only the research Reference-floor sample admission for an already admitted prescribed-head Reference mode and carries no application admission.

Because Q0.4 fails and Q0.5 cannot close under the frozen sequence, `PROCEED_TO_ROM1A` is not available.

## What the negative result does and does not mean

It does **not** show that state compression is impossible in every SWAP domain.

It shows that the declared ROM programme cannot first establish the required reproducible full-order measuring instrument across its own contrasting B01+B14 domain under the frozen Reference numerical authority.

B14-only exploration is scientifically conceivable, but selecting it now would narrow the material envelope after seeing the B01 failures. That requires a new research proposition with an explicit reason for the narrower application envelope.

Likewise, adopting a different numerical Reference policy may be scientifically legitimate if independently qualified, but it is not a repair of this closed ROM-0 experiment.

## Preserved negative evidence

The failed 0.0004-day TA3 level and the B01 R3 failures remain first-class evidence. They must not be erased by later successful runs under different controls.

No ROM state, POD basis, memory variable, closure model or reduced production solver is authorized by this closeout.
