# PUB-ME G1 F-CI98 canonical reconciliation

Status: **RECONCILED_BEFORE_REPLICATION_EXECUTION**

Workunit: `PUB-ME-G1-D2-REPLICATION`

Original selection base:

`d517088cdc1cd82904b37648d6556dc79d57a641`

Current execution base:

`7b864853ca22baa73141b2dec9ed2f3915ef520d`

## Why a new execution branch was required

Canonical advanced through F-CI98 / F-GC31 and changed direct D2 build dependencies, including:

- `src/runtime/mod_fmr_serialized_reference_backend.f90`;
- accepted-step directional contract/publication/sensitivity surfaces;
- related drainage/qbot tangent composition.

Therefore the G1 replication was **not** executed on the stale pre-F-CI98 branch.

## F-CI98 semantic boundary

F-CI98 admits restricted active-drainage lagged tangent capability for MODFLOW6 predictor use.

Its admitted contract concerns:

- accepted-step directional/tangent scratch;
- restricted groundwater-level projection;
- active-drainage source/sink derivative composition;
- accepted-trajectory coverage provenance.

Its explicit exclusions retain:

- no new groundwater physics;
- no Groundwater Coupling v1 transaction or commit semantic changes;
- no fully implicit candidate-state drainage reevaluation;
- no runtime finite-difference fallback.

G1 uses:

- no drainage;
- no root uptake;
- no macropores;
- prescribed equal top/bottom flux;
- the same Reference Richards temporal certificate and transaction policy as D2.

The non-requested real accepted-step directional service remains replaced by the pre-existing D2 qualification stub in the G1 build closure.

## Scientific design preservation

The following remain byte/text-identical to the preregistered G1 design except for execution-base bookkeeping:

- q = `-1.0e-6 cm/day`;
- rejected dt = `0.01 day`;
- accepted dt = `0.0001 day`;
- head budget = `1.0e-6 cm`;
- historical negative-q F-SI38 Binf values;
- sign-aware rejected transfer = `abs(q)*dt`;
- D2 B1/B2 oracle definitions;
- allowed result classes.

No G1 scientific execution occurred before this reconciliation.

## Current branch

`work/pub-me-g1-d2-replication-fci98`

Current post-carry implementation head before this note:

`222f078aa6a958a950710e14d2fc69c8b93d122b`

## Next permitted action

Open a draft PR against current canonical and run the dedicated G1 replication gate.

If the exact frozen clean sequence fails under F-CI98, classify according to the preregistration; do not tune the fixture.
