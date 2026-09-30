# F-PE-ELASTIC61 — production mode-7 defect-indicator admission preregistration

Date: 2026-09-30

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Research authority:
- F-PE-ELASTIC53 qualified the zero-bottom-stiffness mode-7 operator under swkimpl=0;
- F-PE-ELASTIC55 qualified the frozen global conservative envelope across four profiles;
- F-PE-ELASTIC59 qualified a refined-oracle temporal budget candidate;
- F-PE-ELASTIC60 qualified transaction-core composition.

Canonical base:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`.

## Production change

Change only the boundary envelope in:

`src/solver/mod_reference_richards_temporal_indicator.f90`

from admitting bottom modes 2 and 5 to admitting 2, 5 and 7.

No mode-7 bottom stiffness is added.

The existing global indicator envelope already requires
`conductivity_implicit_mode == 0`, so this admission remains bounded to the
qualified `swkimpl=0` production linearization.

## Unchanged fail-closed boundaries

Remain unavailable:
- swkimpl != 0;
- unsupported conductivity-mean policy;
- non-fixed-flux top boundary;
- macropore envelope;
- unsupported provider types;
- all bottom modes other than 2, 5 and 7.

## Qualification

A1. Source scope is exactly the one boundary-envelope production change.

A2. Existing F-SI38 mode-2 independent Neumann oracle remains exact.

A3. Existing mode-5 production indicator seam remains exact.

A4. A new independent mode-7 free-drainage oracle matches raw, defect, bounded
and Binf quantities.

A5. Serialized Reference runtime with:
- bottom mode 7;
- swkimpl=0;
- active elastic storage;
- temporal-history committed state;
- TX_TEMPORAL_MODEL_CERTIFICATE;
- frozen native Binf budget `0.2853792396384496 cm`;
executes the production indicator and preserves hard mass/transaction semantics.

A6. Nearby unsupported bottom mode remains fail closed.

A7. O0/O2 identity.

A8. Default external-full-half Reference behavior remains unchanged when the
model certificate path is not requested.

## Admission boundary

A green result may become a production admission candidate for mode-7
indicator availability only.

It does not admit:
- a canonical numeric F-CI14 budget;
- default-on model-certificate policy;
- swkimpl=1 mode-7 indicator;
- controller policy changes.
