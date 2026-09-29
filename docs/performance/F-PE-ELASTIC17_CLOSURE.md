# F-PE-ELASTIC17 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@75beec445ac4948c1d90dceba6477664f1fef59e`

Merged PR:
`#800`

Admitted production file:
`src/adapter/mod_fmr_elastic_storage_horizon_node_mapper.f90`

Admitted production blob:
`11df2b55f6f15b6bdf9fb3a3d4effdd21308f056`

## Admission summary

F-PE-ELASTIC17 admits deterministic source-horizon to SWAP-node ELAS descriptor
mapping.

The admitted rule is complete-compartment containment.

For normalized node centre depth `d` and node thickness `t` in metres below
surface:

`node_top = d - t/2`

`node_bottom = d + t/2`.

A source horizon owns the node only when the whole node compartment lies
inside that horizon, within the fixed `1e-10 m` floating-point representation
tolerance.

The mapper copies the already resolved source descriptor exactly:
- dry bulk density;
- reference-state volumetric water content;
- explicit ELASTIC14 regime code;
- source horizon index.

It performs no fitted transformation and does not calculate ELAS itself.

## Clean qualification authority

Clean branch:
`work/f-pe-elastic17-clean-admission@37f80868970b277282ee52621df9055d4c6f4ede`

Result-document head:
`89cd8bdd843e2d64b55aa0a1451f81b23a6501ad`

Qualification:
- workflow run `36559979790`;
- job `109378232222`;
- conclusion SUCCESS.

Named gates:
- A1 single-horizon mapping: PASS;
- A2 exact horizon-boundary alignment: PASS;
- A3 straddling fail closed: PASS;
- A4 horizon geometry validation: PASS;
- A5 source-profile coverage fail closed: PASS;
- A6 invalid/non-finite input fail closed: PASS;
- A7 descriptor bit identity: PASS;
- A8 ELASTIC16 composition identity: PASS;
- A9 PEAT provenance preserved and downstream rejected: PASS;
- A10 O0/O2 identity: PASS;
- A11 source scope: PASS.

## Blob identity

The admitted canonical production blob is exactly the same as the clean
qualification blob:

`11df2b55f6f15b6bdf9fb3a3d4effdd21308f056`.

No production source changed between qualification and admission.

## Geometry semantics

The admitted source geometry uses metres below soil surface.

The mapper does not consume raw SWAP-native `z` or `dz`.

This separation is deliberate.

The repository and supplementary official SWAP provenance establish that the
historical grid:
- stores node coordinate `z` positive upward, therefore negative below
  surface;
- stores positive compartment thickness `dz`;
- constructs node centres inside sublayers;
- assigns `layer(node)=isoillay(i)` while constructing all compartments of
  that sublayer.

ELASTIC17 preserves that material ownership principle rather than introducing a
centre-point approximation across arbitrary source horizons.

## Boundary behavior

Qualified:

- several nodes may map to one source horizon;
- a node may end exactly at a horizon boundary;
- the adjacent node may start exactly at the same boundary;
- source descriptor values remain bit-identical.

Fail closed:

- a node compartment straddling a material boundary;
- horizon gap;
- horizon overlap;
- reversed/invalid horizon geometry;
- zero/negative horizon thickness;
- node outside source-profile coverage;
- invalid/non-finite source descriptor or node geometry.

No partial mapping survives a failed node.

## Peat/material provenance

ELASTIC17 does not reinterpret regime.

A PEAT horizon maps as PEAT.

The downstream admitted ELASTIC14/16 policy remains responsible for rejecting
generated automatic ELAS assignment for PEAT.

Thus geometric mapping does not weaken the earlier physical-policy boundary.

## Relationship to admitted ELAS chain

The admitted optional generated-prior chain is now:

`source-bound horizon descriptors`
-> ELASTIC17 deterministic node mapping
-> ELASTIC16 descriptor assembly
-> ELASTIC14 physical prior materialization
-> ELASTIC15 explicit generated-prior binding
-> `elasticity_active + cofgen(24,:)`
-> ELASTIC08 runtime materialization
-> ELASTIC05 constitutive semantics
-> ELASTIC09 production bootstrap.

Every transition remains explicit and fail closed.

## Still outside scope

Not admitted:
- raw SWAP `z/dz` to normalized geometry conversion;
- automatic BOFEK/BRO profile retrieval;
- profile selection from coordinates or soil code;
- pressure-head-to-theta reconstruction inside runtime;
- Staringreeks retention evaluation inside runtime;
- material mixing inside one SWAP compartment;
- automatic generated-prior request;
- file/parser syntax;
- mixed mineral/peat partial automatic assignment.

## Next work unit

The next narrow gap is geometry normalization:

`SWAP-native z/dz -> normalized node_depth_m/node_thickness_m`.

A successor must:
- preserve exact SWAP node-centre/control-volume geometry;
- perform only explicit cm-to-m and sign conversion;
- validate contiguous compartment geometry;
- produce ELASTIC17 input without changing material ownership;
- remain outside kernel/solver numerical policy.

## Closure

F-PE-ELASTIC17 is canonically admitted and closed.

There is no remaining production-software action in this work unit.
