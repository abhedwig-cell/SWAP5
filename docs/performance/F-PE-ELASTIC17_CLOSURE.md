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

F-PE-ELASTIC17 admits deterministic source-horizon to SWAP-node descriptor
mapping for the generated ELAS application chain.

The mapper owns geometry only.

Its qualified rule is complete-compartment containment:
a node may receive one source horizon descriptor only when the entire node
compartment lies within one source horizon within the fixed
`1e-10 m` representation tolerance.

## Clean qualification authority

Clean extraction:
`work/f-pe-elastic17-clean-admission@37f80868970b277282ee52621df9055d4c6f4ede`

Result-document head:
`89cd8bdd843e2d64b55aa0a1451f81b23a6501ad`

Qualification:
- workflow run `36559979790`;
- job `109378232222`;
- conclusion SUCCESS.

Named passes:
- single-horizon mapping;
- exact aligned-boundary mapping;
- straddling fail closed;
- horizon gap/overlap/invalid geometry fail closed;
- source-profile coverage fail closed;
- non-finite input fail closed;
- descriptor bit identity;
- admitted ELASTIC16 composition identity;
- PEAT provenance preservation and downstream rejection;
- O0/O2 identity;
- source-scope gate.

## Blob identity

The admitted canonical mapper blob is exactly the clean qualification blob:

`11df2b55f6f15b6bdf9fb3a3d4effdd21308f056`.

No production source changed between clean qualification and canonical
admission.

## Admitted geometry semantics

Inputs are normalized geometry in metres below soil surface.

For node centre depth `d` and thickness `t`:

`node_top = d - t/2`

`node_bottom = d + t/2`.

The mapper does not use a node-centre shortcut.

If a material boundary lies strictly inside a node compartment, the mapping
fails closed.

No:
- nearest-layer assignment;
- centre-only assignment;
- thickness-weighted mixing;
- density/theta averaging;
- ELAS averaging

is admitted.

## Descriptor ownership

On successful mapping, the source horizon's:
- dry bulk density;
- reference-state volumetric water content;
- regime code

are copied exactly to the node descriptor.

PEAT remains PEAT.

The downstream ELASTIC14/16 generated-prior policy remains responsible for
whether such a descriptor is eligible for generated ELAS.

## Preserved boundaries

Still outside ELASTIC17:
- raw SWAP `z/dz` sign/unit normalization;
- BOFEK/BRO data loading;
- profile selection;
- material averaging across a node;
- input-file syntax;
- automatic generated-prior request;
- mixed-material node approximation.

## Relationship to ELASTIC chain

Current admitted chain:

direct mechanical evidence
-> ELASTIC11 predictor
-> ELASTIC12 BOFEK/BRO transfer
-> ELASTIC13 mineral policy
-> ELASTIC14 prior materializer
-> ELASTIC15 explicit application binding
-> ELASTIC16 resolved-descriptor composition
-> ELASTIC17 strict horizon-to-node mapping.

The next remaining geometric seam is conversion from raw SWAP grid coordinates
to ELASTIC17 normalized node depth/thickness units.

## Closure

F-PE-ELASTIC17 is canonically admitted and closed.
