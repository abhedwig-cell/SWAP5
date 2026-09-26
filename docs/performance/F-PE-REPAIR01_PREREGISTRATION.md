# F-PE-REPAIR01 — inactive-root qbot ownership repair

Date: 2026-09-26

Status: `PREREGISTERED_REPAIR`

Parent:
`F-PE-REPRO01`

Root cause:
`mod_reference_richards_legacy_binding::materialize_prescribed_head_bottom_flux`

## Defect

The prescribed-head mode-5 bottom-flux materializer unconditionally computes:

`qrosum = sum(richards%provider_root_sink(1:n))`

even when `request%evaluation%root_sink` is not associated.

In the root-inactive route, `provider_root_sink` is worker scratch and has no authoritative value requirement.

REPRO01 established the causal chain:

- Valgrind traces undefined use to Reference workspace allocation;
- full poison reproduces status 6;
- PROVIDER scratch is the only failing family;
- `provider_root_sink` is the only failing singleton;
- test-only conditional qrosum restores 100/100 success under deliberate ROOT_SINK NaN poison.

## Minimal repair

Change only mode-5 qbot materialization ownership:

- if `request%evaluation%root_sink` is associated, retain
  `qrosum = sum(richards%provider_root_sink(1:n))`;
- otherwise set
  `qrosum = 0.0_real64`.

Do not zero the entire workspace.

Do not add a defensive reset unrelated to the identified ownership defect.

Do not alter root-active physics.

## Required qualification

1. deterministic ROOT_SINK poison regression;
2. exact first-corrector fixed-build repeatability;
3. live exact FGC44 SWAP + MODFLOW6 repeatability;
4. A1 preservation;
5. A2C coupled reproducibility;
6. application-shaped A2C mass and endpoint preservation;
7. root-active regression proving the provider contribution is still retained.

## Admission rule

Repair may advance only if:

- root-inactive poison no longer affects results;
- exact repeatability is restored;
- live exact coupled repeatability is restored;
- A1 and A2C existing contracts remain intact;
- root-active behavior remains unchanged.

No performance claim is made by the repair workunit itself.
