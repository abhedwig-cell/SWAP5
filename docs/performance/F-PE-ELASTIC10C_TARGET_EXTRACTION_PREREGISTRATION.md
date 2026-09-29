# F-PE-ELASTIC10C — mechanical target extraction preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_TARGET_VALUES

Parents:
- F-PE-ELASTIC10 Phase A schema audit;
- F-PE-ELASTIC10B object pilot.

## Fixed object population

Use exactly the same three frozen pilot objects:

- BHR000000339285
- BHR000000339288
- BHR000000351603

No additional BHR-GT object may be opened before the extraction result is
recorded.

## Schema binding

For every settlement series used numerically:

1. read the `swe:elementType xlink:href` from the object;
2. fetch that DataRecord definition from the official BRO schema service;
3. record URL, byte size and SHA-256;
4. parse field order and units from the DataRecord;
5. parse token/block separators from the object's `swe:TextEncoding`.

No tuple position may be inferred from memory.

Expected relevant DataRecords, subject to machine confirmation:

- `HeightAtSpecificState.xml`;
- `StressAtSpecificSettlement.xml`.

## Load-controlled extraction

For each `SettlementCharacteristicsDetermination` with method
`samendrukkenBelastinggestuurd`:

- preserve determination id/procedure/method;
- preserve investigated-interval depth;
- preserve sample moistness and correction flags;
- preserve each step number, step type, wet/swell flags and vertical stress;
- decode the complete `heightChangeDuringSettlement` series.

For each `ontlastingstap` with:
- a valid immediately preceding step;
- finite previous/current vertical stress;
- at least two finite vertical-strain observations;

define:

`delta_sigma = sigma_end - sigma_start`

using current minus previous step vertical stress in Pa, and:

`delta_epsilon = epsilon_last - epsilon_first`

using decoded vertical strain as a fraction.

A candidate constrained unload compressibility is:

`mv_unload = delta_epsilon / delta_sigma`.

Both deltas must have the same sign for a positive mechanical compressibility.
Otherwise classify the branch as `SIGN_INCONSISTENT` and do not take an
absolute value.

Convert only positive valid branches to skeleton specific storage:

`Ss_skeleton_m_inv = gamma_w * mv_unload`

with frozen:
- `rho_w = 1000 kg m^-3`;
- `g = 9.80665 m s^-2`;
- `gamma_w = 9806.65 N m^-3`.

And:

`Ss_skeleton_cm_inv = Ss_skeleton_m_inv / 100`.

## Reload extraction

If an unload step is immediately followed by a `belastingstap` returning to a
higher stress, apply the same finite-difference definition to the reload step
using that step's decoded first/last strain and the stress change from the
preceding unload step.

Report unload and reload estimates separately.

Do not average them in this phase.

## Rate-controlled extraction

For each `samendrukkenSnelheidgestuurd` determination:

- decode `stressChangeDuringSettlement` strictly using the fetched DataRecord;
- preserve each step type;
- for every `ontlastingstap`, use the first and last finite pair of:
  - vertical effective stress;
  - vertical strain.

Define:

`mv_unload = delta_epsilon / delta_sigma_effective`

and convert to `Ss_skeleton` with the same constants and sign gate.

If the DataRecord lacks finite vertical effective stress or vertical strain at
both ends, classify the step as unavailable; do not substitute total stress.

## Water compressibility

Do not add the water-compressibility contribution in F-PE-ELASTIC10C.

The result is explicitly:

`skeleton specific storage`.

A later workunit may add water compressibility only with a source-bound porosity
definition.

## Output

For every candidate unload/reload branch record:

- BRO ID;
- investigated interval depth;
- determination method/procedure;
- step numbers and step types;
- start/end stress;
- start/end strain;
- stress and strain deltas;
- `mv`;
- `Ss_skeleton_m_inv`;
- `Ss_skeleton_cm_inv`;
- validity/classification;
- raw-object SHA;
- DataRecord SHA.

Also summarize:
- count of valid unload estimates;
- count of valid reload estimates;
- min/median/max only if at least three valid values exist.

## Claim boundary

This phase may answer whether Pim Dik's `1e-6 cm^-1` lies within observed
mechanical orders of magnitude for this tiny pilot.

It may not:
- recommend a production default;
- fit a soil pedotransfer relation;
- extrapolate the three-object distribution to the Netherlands;
- tune any target against SWAP runtime behavior.

## Next gate

Only after these target values are recorded may a larger BHR-GT corpus design
and independent material holdout be preregistered.
