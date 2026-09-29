# F-PE-ELASTIC19 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@2df3c56e8b0a676cde3029cf59759c593ec5c760`

Merged PR:
`#811`

Admitted production file:
`src/adapter/mod_fmr_elastic_storage_horizon_descriptor_builder.f90`

Admitted production blob:
`e098362e84f8dab2f063f875546d80efc1bb7e5c`

## Admission summary

F-PE-ELASTIC19 admits source-horizon descriptor construction for the generated
ELAS chain:

`resolved source horizon + resolved Staringreeks retention parameters`
-> frozen `theta(-100 cm)`
-> frozen ELASTIC13 regime classification
-> admitted ELASTIC17 horizon descriptor.

The adapter performs no profile lookup, external I/O, file parsing, ELAS
materialization or runtime mutation.

## Clean qualification authority

Clean branch:
`work/f-pe-elastic19-clean-admission`

Qualified clean postimage:
`8b41e9b7cceaf75416e5f7169ca0aecdc657061c`

Qualification:
- workflow run `36562052776`;
- job `109385005170`;
- conclusion SUCCESS.

Passed:
- Staringreeks B01 theta(-100 cm) identity;
- MINERAL classification;
- ORGANIC_RICH_NONPEAT classification;
- PEAT precedence;
- UNKNOWN classification;
- source/retention fail-closed validation;
- source geometry/density bit identity;
- ELASTIC17/16 downstream composition;
- PEAT provenance and downstream generated-prior rejection;
- O0/O2 identity;
- source-scope gate.

## Blob identity

The admitted canonical production blob is exactly the clean qualification blob:

`e098362e84f8dab2f063f875546d80efc1bb7e5c`.

No production source changed between clean qualification and canonical
admission.

## Admitted physical semantics

The reference state remains:

`h_ref=-100 cm`.

Retention uses the frozen standard Staringreeks MvG relation:

`m = 1 - 1/n`

`theta_ref = wcr + (wcs-wcr)/(1 + (alpha*100)^n)^m`.

No fitting, clipping or alternative state selection occurs.

Regime classification remains exactly ELASTIC13:

1. peat type present -> PEAT;
2. otherwise OM unavailable -> UNKNOWN;
3. otherwise OM >15% -> ORGANIC_RICH_NONPEAT;
4. otherwise -> MINERAL.

## Preserved boundary

Still outside ELASTIC19:
- BOFEK/BRO profile retrieval;
- Staringreeks code-to-parameter lookup;
- location/profile selection;
- input-file syntax;
- automatic generated-prior request.

## Relationship to admitted chain

The admitted path is now:

mechanical evidence
-> ELASTIC11 predictor
-> ELASTIC12 transfer
-> ELASTIC13 mineral policy
-> ELASTIC14 prior materializer
-> ELASTIC15 explicit application binding
-> ELASTIC16 descriptor assembly
-> ELASTIC17 horizon-to-node mapping
-> ELASTIC18 SWAP grid normalization
-> ELASTIC19 horizon descriptor construction.

## Closure

F-PE-ELASTIC19 is canonically admitted and closed.
