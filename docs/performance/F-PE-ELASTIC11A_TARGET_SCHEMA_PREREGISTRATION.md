# F-PE-ELASTIC11A — BHR-GT mechanical SWE schema binding

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_TARGET_CALCULATION

Parent:
F-PE-ELASTIC10D_RESULT.md

## Purpose

Bind the exact column order, physical meaning and units of the two BHR-GT SWE
records used by the frozen 16-object mechanical target sample before calculating
any compressibility or specific storage.

No m_v, S_s or ELAS value is calculated in this workunit.

## Frozen schema authority

Retrieve and hash exactly:

- `http://schema.broservices.nl/xsd/bhrgtcommon/2.0/HeightAtSpecificState.xml`;
- `http://schema.broservices.nl/xsd/bhrgtcommon/2.0/StressAtSpecificSettlement.xml`.

HTTPS fallback is allowed only if the HTTP endpoint redirects/fails and the
retrieved content is the same official schema product.

Persist:
- final URL;
- HTTP status/content type;
- byte size;
- SHA-256;
- full raw schema;
- ordered DataRecord field list;
- field type;
- uom/codeSpace/reference frame attributes.

## Frozen object authority for successor

The target sample remains exactly the 16 BRO-IDs frozen by ELASTIC10D.
No additional object may enter target extraction.

## Required semantic bindings

### HeightAtSpecificState

Before R2 calculation, establish from the schema:
- ordered columns;
- which column is elapsed/time coordinate;
- which column is vertical strain/deformation;
- the strain unit and sign convention if the schema specifies it.

### StressAtSpecificSettlement

Before R3 calculation, establish:
- ordered columns;
- time coordinate;
- vertical strain;
- pore-pressure quantity if present;
- vertical effective/grain stress;
- optional horizontal stress;
- all units.

## Success condition

Both schemas are retrieved from official BRO authority and every column required
for R2/R3 conversion has an unambiguous semantic + unit binding.

If either record remains ambiguous, stop and record the gap. Do not infer column
meaning from numerical magnitudes.

## Prohibited

- computing mechanical slopes;
- converting to S_s/ELAS;
- selecting a subset based on apparent values;
- changing the 16-object sample;
- using solver performance.
