# Vertical soil-water flow

## Scientific basis

The admitted reference soil-water capability is based on conservation of water mass combined with Darcy–Buckingham flow in a variably saturated porous medium.

In the scientific convention documented by the SWAP lineage, vertical coordinate `z` is positive upward and water flux `q` is positive upward:

```text
q = -K(h) d(h + z)/dz
```

where:

- `h` is pressure head;
- `K(h)` is the unsaturated hydraulic conductivity;
- `h + z` is hydraulic head.

Combining the flux law with local continuity gives the one-dimensional Richards equation. A restricted notation for the local balance is:

```text
dtheta/dt = d/dz [ K(h) (dh/dz + 1) ] + sources - sinks
```

with constitutive relations such as `theta(h)`, `K(h)` and differential water capacity `C(h)=dtheta/dh` supplied by the admitted hydraulic formulation.

The equation above expresses the scientific family. It does **not** admit every constitutive model, source/sink option or legacy SWAP switch described in historical manuals.

The exact frozen default-provider branch logic, including its near-saturation/air-entry transitions, timestep-dependent capacity floor and the strict separation between the ordinary value-provider and the F-SI37 smooth directional-derivative capability, is documented in [Soil-hydraulic constitutive relations](soil-hydraulic-constitutive-relations.md).

## Conceptual state and exchanges

The soil profile is discretised vertically into compartments. Pressure head is the principal hydraulic-potential state for the reference Richards route; volumetric water content follows from the admitted constitutive relation.

Adjacent compartments exchange vertical Darcy flux. The profile interacts with:

- an admitted top boundary;
- an admitted bottom boundary;
- process-owned distributed sources/sinks such as qualified drainage or root extraction;
- surrounding transaction/state ownership that decides whether a calculated candidate becomes accepted model state.

The soil-water solver does not own the scientific meaning of every coupled process. Each process contributes through its qualified interface and accounting contract.

## Restricted reference formulation

Historical F-DOC18 qualified the RB1 reference formulation only within its frozen `SWSOPHY=0`, `SWKIMPL=0` profile and explicitly excluded broadening to other Richards implementations or inactive physics. The Status-A baseline later preserved/admitted the bounded reference soil-water core through its own capability-specific qualification chain.

For current code/evidence authority, reviewers must therefore follow [Status-A traceability](../status-a/TRACEABILITY.md) rather than treating historical F-DOC18 source hashes as current production locks.

## Mass balance

Storage change, boundary fluxes and admitted source/sink terms form one water-balance system. A process cannot create a second authoritative accounting path merely because the same physical transfer is also reported diagnostically.

SWAP5's transaction architecture adds an important ownership rule: only accounting associated with an **accepted** candidate becomes authoritative. A rejected trial may contain physically meaningful tentative fluxes, but they are not committed water transfers.

## What has changed in SWAP5 — and what has not

The central architectural change is not a claim of a new Richards equation. SWAP5 separates:

- process/solver calculation;
- candidate state;
- assessment;
- retry/rollback;
- committed state.

This makes state mutation and retry semantics explicit while preserving the bounded scientific reference contract. See [Current Status-A architecture](../status-a/CURRENT_ARCHITECTURE.md).

## Review questions

A scientific/numerical reviewer should be able to trace:

1. the sign/unit convention used by every boundary and source/sink;
2. the storage and flux terms participating in mass conservation;
3. the exact admitted constitutive/boundary profile for the case under review;
4. the discretised residual/Jacobian construction;
5. the qualification evidence protecting the reference route;
6. the separation between tentative solver output and accepted/committed state.

Continue with [Soil-hydraulic constitutive relations](soil-hydraulic-constitutive-relations.md) and [Richards discretisation and nonlinear solve](../numerics/richards-solver.md).
