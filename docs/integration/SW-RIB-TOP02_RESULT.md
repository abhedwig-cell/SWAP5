# SW-RIB-TOP02 — executable qualification result

Date: 2026-10-01

Status: QUALIFIED_PRODUCTION_CANDIDATE

Qualified head:
`aba015d22440fc994e652bf3d7ef2ccde7c58176`

Canonical PR base observed by qualification:
`integration/f-ci-canonical@2a0b23a2c4e547f6de2613884207d10b2fce462e`

Draft PR: #953

## Dedicated executable evidence

Workflow:
`SW-RIB-TOP02 external-head qualification`

Run:
`36879950150`

Job:
`110428879694`

Compiler:
GNU Fortran on ubuntu-24.04.

Result:

- O0: `SW_RIB_TOP02_EXTERNAL_HEAD=PASS`;
- O2: `SW_RIB_TOP02_EXTERNAL_HEAD=PASS`;
- aggregate: `SW_RIB_TOP02_O0_O2=PASS`.

## Qualified scope

The fixture proves for the bounded candidate:

- external view absent preserves the historical provider result fields checked
  by the fixture;
- equality at flooding sill remains inactive;
- strict exceedance activates the external-head route;
- imposed surface head equals the supplied external head exactly;
- candidate ponding equals the imposed external head;
- active flooding does not simultaneously publish runoff;
- the selected infiltration fixture produces negative solver top flux, matching
  the admitted production sign authority;
- O0/O2 behavior agrees.

## Prior failures

Runs before the qualified run failed only in qualification plumbing:

- missing compileclosure `--stub`;
- nonconstant Fortran `error stop` test message;
- missing O2 compileclosure `--stub`.

The production provider reached compilation in these attempts; none constitutes
a physical or production-code falsification.

## Broader PR evidence

The initial PR carrier also passed multiple frozen/historical authority jobs.
Unrelated failures were traced to historical exact-postimage guards or moving
canonical dependency drift outside TOP02 scope and are not used as positive
TOP02 evidence.

## Decision

`TOP02_EXTERNAL_HEAD_PROVIDER = QUALIFIED_PRODUCTION_CANDIDATE`.

This does not authorize canonical admission by itself. TOP03 transaction/mass
publication remains required before the external inundation capability is
complete.
