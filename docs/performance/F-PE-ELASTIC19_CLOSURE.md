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
ELAS chain.

It accepts already resolved source attributes and already resolved
Staringreeks retention parameters and returns the admitted ELASTIC17 horizon
descriptor.

The builder owns only:
- source validation;
- frozen Staringreeks retention evaluation at `h=-100 cm`;
- frozen ELASTIC13 regime classification;
- typed horizon construction.

## Clean qualification authority

Clean branch:
`work/f-pe-elastic19-clean-admission`.

Qualified clean postimage:
`8b41e9b7cceaf75416e5f7169ca0aecdc657061c`.

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
- invalid-input fail closed;
- source geometry/density bit identity;
- ELASTIC17/16 downstream composition;
- PEAT downstream rejection;
- O0/O2 identity;
- exact source scope.

## Blob identity

The admitted canonical production blob is exactly the clean qualification blob:

`e098362e84f8dab2f063f875546d80efc1bb7e5c`.

No production source changed between clean qualification and admission.

## Admitted physical state

Reference moisture state remains the already qualified:

`h_ref=-100 cm`.

For Staringreeks parameters:

`m = 1 - 1/n`

`theta_ref = wcr + (wcs-wcr)/(1+(alpha*100)^n)^m`.

No alternate state, fitting or clipping is introduced.

## Admitted regime policy

- explicit peat indicator -> PEAT;
- otherwise unavailable organic matter -> UNKNOWN;
- otherwise organic matter >15% -> ORGANIC_RICH_NONPEAT;
- otherwise -> MINERAL.

PEAT and high-organic regimes remain downstream non-auto-assigned.

## Current admitted chain

direct mechanical evidence
-> ELASTIC11 predictor
-> ELASTIC12 BOFEK/BRO transfer
-> ELASTIC13 mineral policy
-> ELASTIC14 prior materializer
-> ELASTIC15 explicit application binding
-> ELASTIC16 descriptor assembly
-> ELASTIC17 horizon-to-node mapping
-> ELASTIC18 raw SWAP grid normalization
-> ELASTIC19 source-horizon descriptor construction.

## Remaining boundary

Still external:
- BOFEK/BRO profile retrieval;
- Staringreeks code-to-parameter lookup;
- location/profile selection;
- file/data-catalog syntax;
- automatic generated-prior request.

These should remain preprocessing/application concerns rather than runtime
network dependencies.

## Closure

F-PE-ELASTIC19 is canonically admitted and closed.
