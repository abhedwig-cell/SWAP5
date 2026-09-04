# SWAP technical documentation

This site is the technical documentation home for SWAP and for the modular architecture that is being developed from the SWAP 4.3.1 baseline.

!!! warning "Implementation status"
    The target architecture described here is a design contract. It must not be read as a claim that all parts are already implemented in SWAP 4.3.1. Pages that discuss the current legacy code state this explicitly.

## Documentation layers

The documentation deliberately separates five subjects:

1. **Physics** describes model behaviour independently of a specific solver or file format.
2. **Architecture** describes component boundaries, ownership, state and runtime contracts.
3. **Numerics** describes solver algorithms and numerical policy independently of physical options.
4. **Verification** describes how correctness, mass conservation, accuracy and performance are qualified.
5. **Legacy** describes SWAP 4.3.1, its file-oriented interfaces and migration constraints.

The first documentation foundation focuses on architecture and verification. User guides, physics documentation, API reference and generated Fortran reference can be added incrementally as the new kernel interfaces stabilize.

## Target system at a glance

The target architecture has one computational kernel. Standalone SWAP, MultiSWAP and coupled applications use the same physics kernel. Runtime and coupling layers organize batches, retries, coupling windows and component composition. File formats and legacy parsing remain outside the kernel in adapters.

The normative rules for this design are the [core architecture invariants](architecture/invariants.md).

Accepted design choices are recorded as [Architecture Decision Records](decisions/index.md). This keeps the reason for important decisions visible next to the code instead of forcing future developers to reconstruct intent from implementation details.

## Documentation status

This documentation is intentionally version controlled with the source. Every important change to solver structure, state ownership, runtime, MultiSWAP, coupling or module boundaries should update the relevant documentation and be checked against the architecture invariants.

Documentation changes are validated automatically before publication. Pull requests run the source checks and a strict MkDocs build; successful documentation on `main` can then be published through the [GitHub Pages publication pipeline](development/publication.md).
