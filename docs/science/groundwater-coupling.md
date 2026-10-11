# Groundwater coupling and the lower hydrological boundary

This page documents the bounded lower-boundary and groundwater-coupling formulation admitted for the frozen SWAP5 Status-A review baseline. It explains the quantities that cross the SWAP-groundwater interface, their signs and units, the restricted predictor-corrector sequence, convergence ownership, mass accounting and accepted-state publication.

It is not a general groundwater-model theory chapter and it does not admit a broad MODFLOW backend. The capability-level admission boundary remains [Groundwater Coupling v1](../capabilities/groundwater-coupling-v1.md).

## Scientific boundary

A SWAP soil column has a lower hydrological boundary. In the admitted direct-groundwater composition, SWAP and the groundwater component exchange two kinds of interface information:

- a hydraulic head used to prescribe the SWAP lower-boundary state for a trial; and
- the water exchange integrated over the accepted coupling window.

The coupling layer translates these quantities explicitly. It does not allow pressure head, hydraulic head, native SWAP flux and public coupling flux to be treated as interchangeable raw values.

The admitted runtime route is the restricted `pc1` composition: one predictor and one corrector from the same accepted SWAP and groundwater origin. This bounded composition was independently qualified end to end by F-VQ97 and admitted through F-GC27/F-CI87. F-GC28 later closed the complete Groundwater Coupling v1 denominator without changing production or reference source.

## Head: pressure head is not hydraulic head

The SWAP lower-boundary forcing uses pressure head, while the public groundwater coupling interface uses hydraulic head. A common vertical datum is therefore mandatory.

For lower-boundary elevation `z_bottom` in metres and SWAP pressure head `psi_bottom` in centimetres, the frozen coupling contract performs

```text
H_interface_m = z_bottom_m + psi_bottom_cm * 0.01
```

and the inverse translation

```text
psi_bottom_cm = (H_interface_m - z_bottom_m) * 100
```

The datum contract is valid only when the datum is explicitly available, has a positive identity and has a finite lower-boundary elevation.

This is a hard semantic boundary: a pressure head in centimetres must never be silently relabelled as a hydraulic head in metres.

## Flux sign and unit translation

Three related lower-boundary quantities use deliberately different local conventions.

| Quantity | Unit | Positive direction |
| --- | --- | --- |
| native SWAP `qbot` | cm/day | into the SWAP soil profile |
| coupling `q_swap` | m/s | outward from SWAP through the bottom interface |
| coupling `q_groundwater` | m/s | outward from groundwater through the same interface |

The exact frozen conversion from native SWAP flux to the public coupling convention is

```text
q_swap_m_per_s = -qbot_cm_per_day * 0.01 / 86400
```

with inverse

```text
qbot_cm_per_day = -q_swap_m_per_s * 86400 * 100
```

The paired groundwater flux is exact action/reaction:

```text
q_groundwater_m_per_s = -q_swap_m_per_s
```

and therefore

```text
flux_residual_m_per_s = q_swap_m_per_s + q_groundwater_m_per_s
```

The admitted predictor-corrector runtime requires the accepted interface flux residual to be exactly zero in its frozen arithmetic contract.

## Whole-window exchange versus instantaneous flux

The transaction result used by the groundwater orchestrator carries a whole-window lower-boundary amount as `bottom_outward_exchange_native` in centimetres. This amount is positive outward from the SWAP column.

For a coupling window of `duration_day = t1 - t0`, the frozen runtime first reconstructs the mean native bottom flux

```text
qbot_mean_cm_per_day = -bottom_outward_exchange_cm / duration_day
```

and then applies the sign/unit translation above. Combining the two steps gives the reviewer-facing relation

```text
q_swap_m_per_s =
    bottom_outward_exchange_cm * 0.01
    / (duration_day * 86400)
```

for that exact accepted window.

This distinction matters. A whole-window exchange amount and a terminal or instantaneous boundary flux are not the same quantity. Groundwater coupling uses the qualified whole-window exchange for its interface mass transfer.

## Restricted predictor-corrector sequence

The frozen `restricted-pc1` route begins from one accepted coupling origin containing accepted time, SWAP lineage/revision, groundwater service lineage/revision and accepted groundwater head.

The sequence is:

```text
capture SWAP checkpoint and groundwater checkpoint from the same accepted origin
        |
        v
materialize SWAP lower-boundary forcing from accepted groundwater head
        |
        v
predictor SWAP trial over [t0,t1]
        |
        v
convert predictor whole-window exchange to paired interface fluxes
        |
        v
predictor groundwater trial
        |
        v
discard predictor groundwater candidate and roll back predictor SWAP candidate
        |
        v
materialize SWAP forcing from predictor groundwater head
        |
        v
corrector SWAP trial from the original SWAP checkpoint over the same [t0,t1]
        |
        v
convert corrector whole-window exchange to paired interface fluxes
        |
        v
corrector groundwater trial from the original groundwater checkpoint
        |
        v
evaluate exact flux pairing and governed head convergence
        |
        v
stage and prepare coupled publication
        |
        v
publish accepted SWAP, groundwater and interface-ledger state
```

The predictor is therefore informative but never authoritative. Both predictor candidates are discarded before the corrector is evaluated. The corrector SWAP trial also starts from the original accepted SWAP checkpoint, not from the predictor candidate.

This is one predictor plus one corrector. F-DOC24 does not reinterpret it as a general unlimited fixed-point iteration.

## Corrector interface state

For the corrector, the SWAP-side prescribed interface head is the groundwater head returned by the predictor groundwater trial:

```text
h_swap = predictor_h_groundwater
```

The corrector groundwater trial then returns

```text
h_groundwater = corrector_h_groundwater
```

The head residual is

```text
head_residual_m = h_swap_m - h_groundwater_m
```

The corrector fluxes are the paired values derived from the corrector SWAP whole-window exchange.

## Head convergence has an explicit owner

Groundwater head convergence is not governed by an undocumented numerical constant. The frozen policy requires an explicit, available and provenance-qualified externally governed tolerance.

The accepted rule is

```text
abs(head_residual_m) <= head_tolerance_m
```

where `head_tolerance_m` must be finite and strictly positive and its policy/provenance identifiers must be valid.

This policy owns only interface-head convergence. It explicitly does not own:

- application accuracy `H_app`;
- the Richards temporal error budget;
- nonlinear solver tolerances;
- predictor perturbations; or
- a mass-balance tolerance.

F-GC22 owns the application/temporal accuracy binding incorporated into the F-GC28 closure. No universal numeric groundwater-head tolerance is introduced by this documentation.

If the interface is valid but the head criterion is not met, the admitted route discards the corrector candidates and fails closed with a request for a smaller coupling window. The surrounding execution policy owns what happens next.

## Coupled interface mass accounting

For each accepted coupling window, the corrector whole-window SWAP outward exchange is staged in a dedicated interface mass ledger together with the coupling lineage and time window.

The ledger has three distinct states:

```text
trial exchange -> prepared publication -> committed exchange
```

A staged trial is not committed history. Preparing the trial precomputes the new committed total and creates a publication credential. Aborting that prepared publication leaves the previously committed exchange unchanged.

After commit, the ledger snapshot reconstructs the groundwater side by exact action/reaction:

```text
committed_groundwater_outward_exchange_m =
    -committed_swap_outward_exchange_m

conservation_residual_m =
    committed_swap_outward_exchange_m
  + committed_groundwater_outward_exchange_m
```

The frozen predictor-corrector runtime treats a nonzero committed ledger residual as a hard invariant violation.

## Component balance versus combined-system balance

The same physical transfer has different accounting roles depending on the chosen domain.

For the SWAP column alone, positive `q_swap` is an external outflow through the lower boundary. For the groundwater component alone, the equal and opposite exchange is an external transfer through its interface. For the combined SWAP-plus-groundwater system, the pair is internal and cancels exactly.

Therefore the groundwater exchange must not be counted once as a SWAP loss and again as an independent whole-system loss. The coupling ledger exists precisely to keep the action/reaction pair and accepted publication history explicit.

## Accepted-state publication

The accepted corrector does not become authoritative immediately after both trial calculations finish.

Before publication, the frozen runtime:

1. stages the interface exchange in the ledger;
2. prepares the groundwater candidate;
3. prepares the ledger publication;
4. constructs the next accepted coupling origin;
5. performs a publication preflight covering the SWAP candidate, prepared groundwater state, prepared ledger state and next-origin provenance.

Only after that preflight does it commit the SWAP candidate. The prepared groundwater candidate and prepared ledger are then published, and the accepted coupling origin advances to `t1`.

All recoverable rejection paths occur before irreversible publication. The frozen implementation treats failure of the prepared groundwater publication after successful SWAP commit as a programming/ownership invariant violation rather than a recoverable coupling outcome.

This is the concrete meaning of the capability rule:

**computed is not the same as published.**

## Restart boundary

The interface ledger restart record contains committed continuation only. Active trial exchange, prepared publication credentials and preparation generations are process-local and are deliberately absent.

Export of ledger restart state fails closed while a trial or prepared transaction is active. Restore requires an empty target ledger and reconstructs only committed exchange identity, total and diagnostics.

This matches the admitted F-GC24 accepted-boundary restart/split-run/replay contract. It is not a claim that arbitrary in-flight external transactions can be serialized and resumed.

## MultiSWAP boundary

F-GC25, incorporated into the F-GC27/F-GC28 closure, qualifies the bounded direct-groundwater MultiSWAP composition, including deterministic aggregation, transaction isolation and coupling-window diagnostics.

That does not admit concurrent real-physics groundwater coupling or establish a parallel speedup. The Status-A claim remains bounded to the qualified composition.

## External groundwater gateway

The admitted external gateway is a structural seam through which a conforming groundwater service can participate in the restricted coupling lifecycle. The service contract exposes capture, trial, commit and discard operations, with a stronger preparable subtype for atomic publication.

The gateway does not make the external model part of the SWAP scientific core merely by implementing the interface. A concrete backend still requires its own scientific validity, units, datum, temporal semantics and conformance evidence.

In particular, Groundwater Coupling v1 does not amount to a broad MODFLOW admission.

## What this page does not establish

This page does not claim:

- a broad or unrestricted MODFLOW backend;
- new groundwater constitutive physics or a regional groundwater equation;
- arbitrary coupling schedules, asynchronous exchange or interpolation policies;
- an unlimited predictor-corrector iteration;
- a universal groundwater head tolerance;
- replacement of Richards solver or timestep tolerances by the groundwater head policy;
- a nonzero mass tolerance at the accepted coupling interface;
- concurrent real-physics MultiSWAP coupling;
- serialization of active/prepared external transactions;
- that predictor candidates are accepted state;
- that a lower-boundary exchange is a net loss from the combined SWAP-groundwater system;
- EB, Ross/RossFast or new lower-boundary modes outside the admitted Groundwater Coupling v1 denominator.

## Qualification and authority map

The primary frozen production implementation is scientific baseline `50346642bd565f79134ea17d5462e544b354998c`.

The capability chain used by this page is:

- F-GC27 / F-VQ97 / F-CI87 for restricted direct-groundwater end-to-end qualification and canonical admission;
- F-GC28 / F-VQ98 / F-CI88 for closure of the complete Groundwater Coupling v1 denominator;
- F-GC24 for accepted-boundary restart/replay;
- F-GC20/F-GC25 for the bounded MultiSWAP composition;
- F-GC26 for the structural external gateway boundary;
- F-GC22 for governed application/temporal accuracy binding without a universal numeric tolerance;
- [Status-A traceability](../status-a/TRACEABILITY.md) for the current preservation authority.

The controlling F-DOC24 claim matrix is `integration/f-doc/F-DOC24_AUTHORITY_MATRIX.md`.

See also [Hydrological boundary conditions](hydrological-boundary-conditions.md), [Water balance, signs and units](water-balance-and-conventions.md), [Groundwater Coupling v1](../capabilities/groundwater-coupling-v1.md), [Transactional time stepping and acceptance](../numerics/transactional-time-stepping.md) and [Mass-accounting contract](../verification/mass-accounting-contract.md).
