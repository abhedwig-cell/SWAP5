# F-PE-ELASTIC12A — attempt 1 result

Date: 2026-09-29

Status: SCIENTIFIC_POSTIMAGE_PASS_RAW_RESPONSE_BYTE_DETERMINISM_FALSE_NEGATIVE

Run:
`36535964312`

Job:
`109299955772`

Head:
`acd8df112583bc07a441c2f62e95ea69fc5dbaf0`

Artifact:
`f-pe-elastic12a-rootzone-transfer`

Artifact id:
`11018212255`

Artifact digest:
`sha256:d2d70e13aff1ee1848bdd4ce6228a0652026b4ee59aeb609039a596580ac9971`

## What passed

Both independent executions emitted:

- `F_PE_ELASTIC12A_FROZEN_IDENTITIES=31`;
- `F_PE_ELASTIC12A_OBJECTS=9`;
- `F_PE_ELASTIC12A_CLEAN_INTERVALS=21`;
- `F_PE_ELASTIC12A_CLEAN_OBJECTS=7`;
- `F_PE_ELASTIC12A_HYDRO_IDENTITY=PASS`;
- `F_PE_ELASTIC12A_DRY_DENSITY_UNIT=PASS`;
- `F_PE_ELASTIC12A_TRANSFER_ROWS=525`;
- identical stress summaries;
- identical water-state summaries;
- `F_PE_ELASTIC12A=PASS`.

Thus every frozen hydrophysical identity was reconstructed twice from the
official live BHR-P service and all scientific transfer outputs were identical.

## Why the workflow was red

The workflow additionally required byte identity of the complete transfer JSON
and recursively diffed the two raw response directories.

The first reported JSON difference is at line 32, inside:

`object_manifest[0].sha256`.

That field is the SHA-256 of the complete live BHR-P dispatch response, not the
frozen hydrophysical DataArray identity.

The authoritative hydrophysical identity is separately and more narrowly bound
as SHA-256 of the exact
`WaterContentAndConductivityAtSpecificSoilWaterPotential` values string. All
31 of those frozen hashes matched in both executions.

Therefore the additional complete-response byte-equality requirement is
classified as:

`NONCANONICAL_DISPATCH_WRAPPER_BYTE_DETERMINISM_FALSE_NEGATIVE`.

It is not evidence of hydrophysical or transfer-result drift.

## Corrective action

Retain complete live response bytes and their SHA-256 values as provenance in
the uploaded raw evidence.

Do not include complete-response SHA values in the deterministic scientific
postimage.

Determinism for F-PE-ELASTIC12A must compare:

- all 31 frozen hydrophysical identity hashes;
- exact clean-population membership;
- exact density values/units;
- exact water-state selections;
- exact 525 transfer rows;
- exact aggregate summaries.

This correction does not alter:
- preregistered transfer equations;
- M5 coefficients;
- water-density constant;
- stress scenarios;
- water-state scenarios;
- source population;
- scientific acceptance semantics.

## Scientific status of attempt 1

The transfer calculation itself is retained as a valid positive intermediate
result.

The workflow conclusion is not qualified until the corrected determinism gate is
green.

No numerical result is discarded or retuned.
