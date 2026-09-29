# F-PE-ELASTIC10C — mechanical target extraction result

Date: 2026-09-29

Status: PILOT_MECHANICAL_TARGETS_EXTRACTED_NO_PTF

Workflow run:
`36539688169`

Job:
`109311876538`

Conclusion:
PASS.

## Frozen object scope

Only the preregistered three BHR-GT objects were used:

- BHR000000339285
- BHR000000339288
- BHR000000351603

No additional object was opened for target extraction.

## Machine-bound DataRecord authority

### HeightAtSpecificState

Official schema URL:

`https://schema.broservices.nl/xsd/bhrgtcommon/2.0/HeightAtSpecificState.xml`

SHA-256:

`eaf6fa175a8530d4b3fa7d26960c2796a892c080ab73d5cf6bf72a7befbbc0ec`

Field order and units:

1. elapsedTime [s]
2. verticalStrain [%]

### StressAtSpecificSettlement

Official schema URL:

`https://schema.broservices.nl/xsd/bhrgtcommon/2.0/StressAtSpecificSettlement.xml`

SHA-256:

`7d2d9a3cef1e91513621cc7d3f3064f461100dadbd0f21bbe3559d98e4b5d895`

Field order and units:

1. elapsedTime [s]
2. verticalStrain [%]
3. excessPoreWaterPressure [kPa]
4. verticalEffectiveStress [kPa]
5. horizontalEffectiveStress [kPa]

Tuple positions were therefore not inferred.

## Valid mechanical branches

The preregistered sign/finite gates produced:

- valid unload branches: 8;
- valid reload branches: 8;
- invalid/sign-inconsistent branches: 0.

The reported quantity is skeleton specific storage only:

`Ss_skeleton = gamma_w * mv`.

No water-compressibility term is added in this phase.

## Unload target range

Across the eight valid unload branches:

- minimum: `3.0082e-7 cm^-1`;
- median: `6.2431e-6 cm^-1`;
- maximum: `2.8935e-5 cm^-1`.

Examples:

- BHR000000339285, 0.39-0.41 m:
  `3.0082e-7 cm^-1`;
- BHR000000339285, 3.74-3.76 m:
  `1.1195e-6 cm^-1`;
- BHR000000339288, 2.39-2.41 m:
  `3.1578e-6 cm^-1`;
- BHR000000351603, 4.07-4.10 m:
  `2.8935e-5 cm^-1`.

## Reload target range

Across the eight valid immediate reload branches:

- minimum: `9.0245e-7 cm^-1`;
- median: `1.9895e-5 cm^-1`;
- maximum: `8.9413e-5 cm^-1`.

Unload and reload targets remain separate. They are not averaged.

## Combined descriptive range

Across all 16 valid pilot targets:

- minimum: `3.0082e-7 cm^-1`;
- median: `1.0737e-5 cm^-1`;
- maximum: `8.9413e-5 cm^-1`.

This combined statistic is descriptive only and is not a material parameter estimate.

## Relation to 1e-6 cm^-1

Pim Dik's nominated `1e-6 cm^-1` lies inside the observed pilot range.

It is close to the lower/stiffer end:

- one unload estimate is below it;
- one unload estimate is about `1.12e-6 cm^-1`;
- the smallest reload estimate is about `0.90e-6 cm^-1`;
- most pilot branches are materially larger.

Therefore the pilot supports:

`1e-6 cm^-1 IS PHYSICALLY PLAUSIBLE FOR SOME STIFF/LOW-COMPRESSIBILITY BRANCHES`

but does not support:

`1e-6 cm^-1 IS A UNIVERSAL DUTCH SOIL DEFAULT`.

## Provenance reconciliation

The raw XML SHA-256 of each public object changed between the pilot retrieval and
target-extraction retrieval.

Byte comparison shows the change is solely the public-service
`dispatchTime` envelope field.

The actual `BHR_GT_O` registration-object subtree is byte-semantically stable
after XML parsing/serialization.

Stable registration-object subtree SHA-256 values across both runs:

- BHR000000339285:
  `31ed8c2f2e36b9289732ac62e7922dbe6e098f8bcba394256d1fb27f576ff240`;
- BHR000000339288:
  `66808a42087e69b67249eef3b6cf1fffb9431fe4dc6025c32d396cfb49e8814e`;
- BHR000000351603:
  `092f1a9f35883281a0b3347d1038b341aceffb2cc4e36d2154402267adaa4a76`.

Future corpus evidence must distinguish:
- raw service-response hash;
- semantic registration-object hash.

## Scientific limits

These three objects are geotechnical investigations, not a representative
sample of Dutch agricultural/BOFEK soils.

The pilot does not establish:
- a national distribution;
- a Staringreeks mapping;
- a soil pedotransfer function;
- a default ELAS;
- stress-independent material behaviour.

It establishes that direct Dutch mechanical ELAS targets are recoverable and
that their magnitude spans the order containing `1e-6 cm^-1`.
