# F-PE-ELASTIC14 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@dd363484e89ba50fa55b9552c2c68c08cb6c1924`

Merged PR:
`#784`

Superseded unmerged PR:
`#783`

Admitted production file:
`src/runtime/mod_fmr_elastic_storage_prior_policy.f90`

Admitted production blob:
`bbd90ed919a83d770494b4f17ea88db88648579b`

## Admission summary

F-PE-ELASTIC14 admits a bounded production-shaped helper that materializes the
already qualified ELASTIC13 mineral physical ELAS prior.

The helper accepts:
- resolved dry bulk density;
- resolved volumetric water content at the frozen reference state;
- an explicit soil-regime code.

For MINERAL only it returns:
- ELAS prior;
- frozen factor-2.123968031921196 uncertainty envelope;
- reference head -100 cm;
- predictor provenance/domain diagnostics.

It does not:
- set `elasticity_active`;
- write `cofgen(24,:)`;
- perform BOFEK/BRO lookup;
- evaluate the retention curve;
- activate elasticity;
- change any solver numerical policy.

## Clean qualification authority

Clean current-canonical extraction:

`work/f-pe-elastic14-clean-admission@02fc46ad51b804e1b1de9604d48c0e38963a8a72`

Qualification:
- workflow run `36554278578`;
- job `109359574070`;
- conclusion SUCCESS.

Named gates:
- A1 formula identity: PASS;
- A2 uncertainty envelope: PASS;
- A3 non-mineral no-auto-assignment: PASS;
- A4 invalid/out-of-domain fail closed: PASS;
- A5 PPA-WU01 default-off preservation: PASS;
- A6 generated-prior -> explicit row24 -> admitted ELASTIC09 application/direct-runtime identity: PASS;
- A7 O0/O2 identity: PASS;
- A8 production source scope: PASS.

The later clean-branch change before merge updated only
`F-PE-ELASTIC14_RESULT.md` to bind the result document to this immutable clean
qualification run.

## Blob identity

The admitted canonical production blob is exactly the same as the qualified
clean-branch production blob:

`bbd90ed919a83d770494b4f17ea88db88648579b`.

No production source changed between clean qualification and canonical
admission.

## Admitted physical-policy envelope

ELASTIC13 authority admitted alongside this helper establishes:

### MINERAL
Eligible generated static prior at:

`h_ref=-100 cm`

with frozen ELASTIC11 M1 relation and uncertainty factor
`2.123968031921196`.

### ORGANIC_RICH_NONPEAT
`RESEARCH_ONLY_NOT_AUTO_ASSIGNED`.

### PEAT
`RESEARCH_ONLY_NOT_AUTO_ASSIGNED`.

### UNKNOWN
`NO_AUTO_ASSIGNMENT`.

## Relationship to existing ELAS production chain

The admitted ownership remains:

physical/user parameter source
-> explicit application/config decision
-> `elasticity_active + cofgen(24,:)`
-> ELASTIC08 runtime materialization
-> ELASTIC05 constitutive behavior
-> ELASTIC09 production bootstrap.

ELASTIC14 only adds a qualified optional source of the physical scalar prior.

It does not alter ownership or activation semantics.

## Default and compatibility boundary

Still preserved:
- elasticity remains default OFF;
- explicit user-supplied ELAS remains valid and separate;
- no universal `1e-6 cm^-1` default is introduced;
- no automatic peat/high-organic assignment is introduced;
- unsupported ELAS combinations remain fail closed under the admitted
  ELASTIC08/09 envelope;
- Full Richards remains the production reference path.

## What remains outside ELASTIC14

Not admitted:
- automatic external BOFEK/BRO data loading inside SWAP runtime;
- parser/input-file syntax for requesting generated priors;
- automatic activation from BOFEK identity;
- automatic peat or high-organic ELAS;
- state-dependent ELAS constitutive behavior;
- solver-performance tuning of physical ELAS;
- replacing user-supplied values with generated priors.

Those require separately scoped work units.

## Closure

F-PE-ELASTIC14 is canonically admitted and closed.

There is no remaining production-software action in this work unit.
