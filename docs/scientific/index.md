# Scientific documentation

This section is the version-controlled scientific documentation system for SWAP5. It is not a separate manual and it is not a claim that SWAP5 has Status A or Status AA.

F-DOC01 establishes four linked sources of truth:

1. the externally governed Status A/AA authority and requirement registry;
2. the SWAP5 theory-to-code traceability graph;
3. component-level documentation and readiness audits;
4. links to existing qualification evidence, especially F-TB01 and F-VQ/F-MQ/F-CI evidence, without duplicating their authority.

The intended traceability spine is T0 physical system through T14 release authority. Missing links remain explicit gaps. A legacy or reference implementation is never relabelled as SWAP5 production code.

## F-DOC01 authority

F-DOC01 was branched from `integration/f-ci-canonical` at `3c5f5bd3686e1632058b906be21abd73883e30ef` (tree `6baaf40271497db831698c5a01de355b5d296dbe`). Production physics and numerical semantics are out of scope.

The external quality framework is pinned in [F-DOC01_STATUS_A_AA_AUTHORITY.md](F-DOC01_STATUS_A_AA_AUTHORITY.md). The current authority state is deliberately fail-closed: WUR sources identify a `Revised checklist Status A/AA, 2024`, but F-DOC01 did not obtain a publicly inspectable controlled copy of its full normative text. Formal compliance remains blocked until that authority is reconciled.
