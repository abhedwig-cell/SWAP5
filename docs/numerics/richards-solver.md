# Richards discretisation and nonlinear solve

## Discrete reference problem

The qualified historical reference formulation uses a one-dimensional vertically compartmented grid and an implicit backward finite-difference treatment of the soil-water balance.

For each compartment, storage change over a timestep is represented by the actual change in volumetric water content, while Darcy fluxes connect adjacent compartments. Boundary and distributed source/sink terms enter the same discrete conservation residual.

The frozen reference `SWKIMPL=0` lineage retains its qualified conductivity treatment. This page does not introduce a new discretisation or promote other historical SWAP numerical switches.

## Nonlinear residual

The discrete system can be written schematically as

```text
F(h) = 0
```

where `h` is the vector of compartment pressure heads and `F` combines storage, vertical flux and admitted source/sink terms over the attempted interval.

The reference nonlinear route uses Newton-type iteration. The solver constructs/uses the Jacobian of the residual system and solves the resulting banded/tridiagonal linear update problem. The qualified route includes safeguards around the attempted Newton update rather than treating every full update as automatically acceptable.

## Convergence is not commit

A crucial SWAP5 distinction is that convergence of `F(h)=0` produces a **candidate** numerical state. It does not itself make that state persistent.

The transaction layer subsequently owns the attempt lifecycle:

```text
committed checkpoint
        |
        v
candidate solve
        |
        v
assessment
   /          \
accept        reject
  |             |
commit        rollback/retry
```

This prevents solver internals from silently owning global state-commit policy.

## Mass criteria

Mass/conservation criteria are hard scientific/numerical guards where the owning capability requires them. A candidate cannot become scientifically acceptable merely because the nonlinear iteration converged if the applicable mass gate fails.

See [Mass-accounting contract](../verification/mass-accounting-contract.md) for the repository-level accounting discipline.

## Failure and retry

A solver attempt can report failure or a candidate can fail a later assessment. In either case, the surrounding transaction controller can request a bounded retry according to its admitted policy.

The essential preservation invariant is that retry starts from accepted authority, not from a partially mutated rejected state.

## What to inspect in code review

Reviewers should follow the capability-specific implementation/evidence chain and check:

- sign and unit consistency in residual and boundary terms;
- Jacobian consistency with the residual actually solved;
- storage derivative/constitutive consistency;
- convergence criteria and nonfinite handling;
- behaviour near ponding/boundary transitions;
- separation between solver scratch, candidate state and committed state;
- exact preservation evidence at O0/O2 where required.

The current authority map is [Status-A traceability](../status-a/TRACEABILITY.md). Historical F-DOC18 is useful scientific/numerical lineage, but current implementation authority is the admitted Status-A capability chain.
