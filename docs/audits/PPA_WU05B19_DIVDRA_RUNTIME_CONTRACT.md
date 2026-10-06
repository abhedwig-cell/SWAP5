# PPA-WU05B19: signed frost/DIVDRA runtime contract

Status: preregistered runtime contract; implementation is locally qualified
according to the [qualification report](PPA_WU05B19_DIVDRA_RUNTIME_QUALIFICATION.md).
Canonical admission remains pending.
Baseline: `e5eab995ef04fc813dd644025fb0f32e4f5050a1`.
The B18 source-review recovery record is `PPA_WU05B19_SOURCE_REVIEW.json`.
The live delta from B18 admission adds only an unrelated MICRO component;
the B19 dependency surface remains unchanged.

## Physical interface and ownership

Add explicit default-OFF `frost_divdra_active`, immutable
`frost_divdra_parameters_t`, and signed scalar forcing
`frost_divdra_scalar_cm_per_day`. Positive means soil-to-drain outflow.
This scalar is distinct from an already materialized nodal matrix and from
drainage-response controls. An active selector requires absent nodal and
response forcing. An inactive selector requires a finite exactly zero scalar.
Ordinary serialized Reference, constant prescribed bottom mode 2 without legacy
dynamic bottom control carriers, restricted sensible
temperature and the existing frost-drainage head/temperature budgets are
required. Root, compensation, salt, snow, macropores, elasticity, direct or
tabulated retention, KSATEXM, surface-water coupling, trajectory and history
combinations remain excluded.

Expose the unchanged pure B18 parameter validator as an additive public
procedure. Distribution node count, thickness, compartment bottoms and
default-MvG saturated conductivity must exactly match the column owner.
The grid uses compartment centers and consistent inter-node distances.
There is no alternative conductivity or geometry authority.

Each advance uses its immutable original trial-start hydraulic view and
temperature to evaluate hydraulic factors, bracketed frost geometry and
the unchanged B18 signed partition/modifier. Its final nodes replace the
disposable single-level sink matrix. Its final bottom proposal enters the
existing bottom boundary. The existing source/sink provider and unrounded
accounting remain the only mass owners. Observation provenance records raw
scalar, start GWL, frost geometry and the final component result. The native
step receipt is computed from final nodes and duration, never raw scalar.
No extra persistent state, restart schema, solver arithmetic or numerical
controller is introduced.

Full and half endpoint assessment independently regenerates both complete
physical proposals from their own state and temperature. Invalid component
domains, geometry, low-air or blocking-branch disagreement reject. Existing
head and temperature budgets remain unchanged; no tolerance is loosened.
The B18 tiny nonzero scalar and inadmissible separate-infiltration domains
remain unavailable. Unbracketed frozen geometry remains excluded.

## Required qualification

- Fresh B18 complete 4,536-case corrected-reference and typed O0/O2 replay;
  additive validator exposure must not change scientific arithmetic.
- Runtime signed drainage/infiltration/zero scalars, normal and low air,
  separate infiltration OFF/ON, both bottom signs, blocked/unblocked geometry,
  immutable proposal regeneration, full/half refinement, independent fine
  continuation, hard mass at 1e-12 cm, rejection/replay and empty-registry restart.
- Invalid selectors, mixed owners, nonfinite and tiny scalars, grid/K ownership,
  excluded hybrids and inadmissible geometry reject before solver publication.
- Actual production-application bootstrap/run/result/shutdown and invalid
  configuration checks, with receipts following final accepted nodes.
- Fresh whole-module B1 through B15 affected runtime preservation at O0/O2,
  current root/salt/frost, scientific gates, F-APP09/VQ128 external exclusion,
  exact canonical source guard, documentation, strict build and source-bound
  evidence. Failed gates remain negative evidence and block admission.

Affected invariants: 3, 5, 7, 13, 22, 23, 25, 27, 29, 30.
Changes are limited to backend physical parameters/forcing/observation and
runtime binding, application preflight, additive validator exposure and
qualification harness/guard/evidence. B18 arithmetic, original reference,
positive-only DIVDRA wrappers, transaction and restart contracts remain fixed.
Aggregate frost migration is not closed by this bounded successor.
