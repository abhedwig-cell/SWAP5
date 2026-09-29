# F-PE-ELASTIC25 — explicit generated-prior application request result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic25-application-request`

Qualified postimage:
`13d4be9f717879b5c12af84d48276f93432622e0`

Workflow run:
`36569474497`

Job:
`109409571723`

Conclusion:
SUCCESS.

## Qualified seam

`ELASTIC_STORAGE_SOURCE = GENERATED_BOFEK_BRO_PRIOR`
-> typed `generated_prior_requested=.true.`
-> admitted ELASTIC15 generated-prior binding.

Absence remains default OFF.

No file parser, soil lookup, coordinate lookup, prior value, profile identity or
ELAS derivation belongs to this seam.

## Qualification

- A1 default-off request semantics: PASS;
- A2 exact explicit request token: PASS;
- A3 unsupported key fail closed: PASS;
- A4 unsupported value fail closed: PASS;
- A5 exact-token semantics: PASS;
- A6 ELASTIC15 default-off identity: PASS;
- A7 valid MINERAL request composes through ELASTIC15: PASS;
- A8 explicit/user ELAS ownership preserved: PASS;
- A9 O0/O2 identity: PASS;
- A10 exact production-source scope: PASS.

## Ownership boundary

ELASTIC25 does not apply generated values itself.

ELASTIC15 remains the owner of:
- eligibility validation;
- explicit/user conflict rejection;
- atomic write of generated values to `cofgen(24,:)`;
- `elasticity_active` activation;
- prepared-cache invalidation.

PEAT, ORGANIC_RICH_NONPEAT and UNKNOWN remain non-auto-assigned.

## Current canonical reconciliation

The canonical delta since the preregistered baseline contains only unrelated
NLGLOB14M docs/tests/workflow changes and does not intersect the ELASTIC25
dependency surface.

Current observed canonical:
`a0295af615d04ec9a1b7653c92bef829bd6159ce`.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE_READY_FOR_CURRENT_CANONICAL_EXTRACTION`.
