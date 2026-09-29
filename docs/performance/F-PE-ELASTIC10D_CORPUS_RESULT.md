# F-PE-ELASTIC10D — BHR-GT calibration-corpus characterization result

Date: 2026-09-29

Status: CALIBRATION_CORPUS_CHARACTERIZED_HOLDOUT_CLOSED

Workflow run:
`36540905498`

Job:
`109315796639`

Artifact:
- id: `11021065518`;
- name: `f-pe-elastic10-bhrgt-schema`;
- digest: `sha256:0c0a6c44367966e291cf15177989d2abe8f25f6192259f0e6029bd4aabd3a903`.

## Population and split gates

The frozen Phase-B search reproduced exactly:

- unique BRO IDs: 692;
- ID-list SHA-256:
  `606a4785a5bea70e443a8729bfd132b9ddebe1ea799e78585ed3ba2f54f54667`.

The deterministic split reproduced exactly:

- holdout count: 18;
- holdout-list SHA-256:
  `bfbb1fdefaef57ea3e6a0d2e077fa8efee5b17f101a92da04f0f75603b94e5df`;
- calibration count: 36;
- calibration-list SHA-256:
  `7b42fee42b2b05e2f788e13317b90d574b1039cf240e57fb3f2c35fe994dd45e`.

Marker:

`F_PE_ELASTIC10D_HOLDOUT_FETCHED=0`.

The 18 holdout objects remain unopened.

## Corpus yield

From the 36 fetched calibration objects:

- 82 settlement determinations were parsed;
- 173 unload/reload candidate branches were encountered;
- 169 branches passed the preregistered finite/sign gates;
- 77 valid unload targets;
- 92 valid reload targets;
- 35 of 36 objects yielded at least one valid target;
- 33 objects yielded more than one valid target.

This is a substantially larger mechanical evidence base than the three-object pilot.

## Unload specific-storage targets

Unload is retained as the primary small-strain/recompression target family.

Skeleton specific storage:

- n = 77;
- minimum = `4.7061e-7 cm^-1`;
- median = `7.1720e-6 cm^-1`;
- maximum = `7.3740e-5 cm^-1`.

Thus `1e-6 cm^-1` remains inside the measured calibration range but below the
calibration median.

## Reload targets

Immediate reload branches remain a separate target family.

Skeleton specific storage:

- n = 92;
- minimum = `6.6654e-8 cm^-1`;
- median = `2.0067e-5 cm^-1`;
- maximum = `1.3639e-3 cm^-1`.

The much wider reload upper tail confirms that unload and reload must not be
collapsed into one target without a separate mechanical interpretation.

## Test-method characterization

Across valid unload/reload targets together:

### Load-controlled compression

`samendrukkenBelastinggestuurd`:

- n = 126;
- minimum = `7.5096e-7 cm^-1`;
- median = `1.4028e-5 cm^-1`;
- maximum = `1.3639e-3 cm^-1`.

### Rate-controlled compression

`samendrukkenSnelheidgestuurd`:

- n = 43;
- minimum = `6.6654e-8 cm^-1`;
- median = `9.7508e-6 cm^-1`;
- maximum = `1.0473e-4 cm^-1`.

Method remains an explicit provenance variable for later modelling.

## Depth and stress envelope

For the 169 valid targets:

Target midpoint depth:

- minimum = 0.49 m;
- median = 4.015 m;
- maximum = 11.315 m.

Absolute branch stress change:

- minimum = 5.0 kPa;
- median = 77.0 kPa;
- maximum = 588.51 kPa.

These ranges reinforce that specific storage is being observed over a broad
effective-stress/depth envelope rather than at one reference stress.

## Source-bound descriptor coverage

For the 169 valid targets:

- volumetricMassDensity: 169 / 169;
- waterContent: 169 / 169;
- volumetricMassDensitySolids: 75 / 169;
- geotechnicalSoilName: 23 / 169;
- organicMatterContent: 4 / 169;
- organicMatterClass: 0 / 169 in the Phase-D inventory;
- sandMedianClass: 0 / 169 in the Phase-D inventory;
- specialMaterial: 0 / 169 in the Phase-D inventory.

At object level:

- volumetricMassDensity: 35 objects;
- waterContent: 35 objects;
- volumetricMassDensitySolids: 17 objects;
- geotechnicalSoilName: 6 objects;
- organicMatterContent: 1 object.

## Interpretation

The calibration corpus strongly confirms that a direct Dutch mechanical target
route exists and that `1e-6 cm^-1` is physically plausible but not a universal
central value.

However, Phase D does **not** justify a predictor model yet.

The current BHR-GT catalogue exposes additional source-bound specimen fields,
including `dryVolumetricMassDensity`, that were not part of the preregistered
Phase-D descriptor inventory.

Those fields must be audited in a separate preregistered phase rather than added
post hoc to Phase D.

## Decision

Classification:

`MECHANICAL_CALIBRATION_CORPUS_ESTABLISHED_HOLDOUT_PRESERVED_MODEL_SELECTION_NOT_YET_AUTHORIZED`.

The next authorized step is a source-bound descriptor extension audit on the
already fetched calibration artifact only.
