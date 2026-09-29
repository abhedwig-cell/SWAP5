# F-PE-ELASTIC10E — BHR-GT mechanical target extraction preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_ANY_MECHANICAL_TARGET_CALCULATION

Parent authority:
- F-PE-ELASTIC10D fixed-grid result;
- qualified BHR-GT schema authority;
- USGS consolidation-to-specific-storage identity in F-PE-ELASTIC06B.

## Purpose

Extract reproducible mechanical target quantities from the already frozen 16-object
BHR-GT sample before any pedotransfer modelling or SWAP calibration.

This workunit may calculate object/determination-level mechanical targets.
It may not fit an ELAS predictor, select a production default, or use SWAP
runtime/performance as a target.

## Frozen object population

Use exactly the 16 F-PE-ELASTIC10D objects and no replacements:

- BHR000000462600
- BHR000000462646
- BHR000000456021
- BHR000000456023
- BHR000000356939
- BHR000000356940
- BHR000000453770
- BHR000000453775
- BHR000000380280
- BHR000000380281
- BHR000000466468
- BHR000000466469
- BHR000000353613
- BHR000000353614
- BHR000000470062
- BHR000000470064

The raw object bytes from F-PE-ELASTIC10D artifact 11016296681 remain the
preferred evidence authority. Re-fetch is allowed only as a byte-identity check
or when the artifact is unavailable; any changed object must be recorded rather
than silently substituted.

## Source-bound target types

Two independent target routes are frozen.

### R2 — load-controlled unload/reload target

Eligible only for a single SettlementCharacteristicsDetermination that already
satisfies the frozen R2 classifier.

For each determination:

1. decode every usable determinationStep in source order;
2. bind its finite scalar verticalStress in kPa;
3. decode the step-local heightChangeDuringSettlement SWE DataArray only when
   its DataRecord is HeightAtSpecificState.xml;
4. use the terminal finite vertical-strain observation of each usable step as
   the endpoint strain for that stress state;
5. identify every explicit ontlastingstap/unload step;
6. pair an unload endpoint only with the immediately preceding usable endpoint
   in the same determination;
7. compute the secant constrained compressibility over that actual unload
   increment:

   mv = abs(delta epsilon_v / delta sigma_v)

   with strain converted percent -> dimensionless and stress kPa -> Pa.

No non-adjacent points, loading-envelope regression, or virgin-compression
slope may replace this frozen unload-pair definition.

If delta stress is zero, either endpoint is non-finite, or the step-local SWE
record cannot be decoded unambiguously, that unload pair is INVALID and no
target is emitted for it.

### R3 — rate-controlled effective-stress tangent target

Eligible only for one SettlementCharacteristicsDetermination that already
satisfies the frozen R3 classifier.

Decode stressChangeDuringSettlement only when bound to
StressAtSpecificSettlement.xml.

Before numerical differentiation, bind the DataRecord field order and units from
the source-bound SWE schema. Required physical columns are:

- vertical strain;
- vertical effective/grain stress.

Optional elapsed time and pore-pressure columns are preserved but are not target
variables.

For each determination-step series:

1. preserve row order;
2. remove only rows that are non-finite in either required target column;
3. convert strain percent -> dimensionless when the bound schema unit is percent;
4. convert effective stress kPa -> Pa when the bound schema unit is kPa;
5. split calculations by determination step; never differentiate across a step
   boundary;
6. identify explicit ontlastingstap/unload steps from source-bound stepType;
7. for an unload step with at least 3 valid distinct-stress rows, estimate a
   robust secant target over the full observed unload step:

   mv = abs((epsilon_last - epsilon_first) /
            (sigma_eff_last - sigma_eff_first)).

The full-step secant is frozen deliberately; no pointwise smoothing bandwidth,
local regression degree, or cherry-picked sub-window is introduced in this
first extraction.

If an R3 determination has no explicit unload step, no elastic/recompression
target is emitted from that determination even though it remains mechanically
informative. Loading/relaxation series are retained as descriptive evidence only.

## Sign convention

Compression-positive or compression-negative source conventions are not assumed.

Target magnitude uses absolute delta strain divided by absolute delta stress.
The signed source deltas are also retained in evidence for audit.

## Conversion to specific storage

For every valid R2 or R3 mechanical target:

- skeletal one-dimensional specific storage:

  Ssk_m_inv = gamma_w * mv

- use fixed reference water unit weight:

  gamma_w = 9806.65 N/m3

- report also:

  Ssk_cm_inv = Ssk_m_inv / 100.

This is the skeleton contribution only.

## Water compressibility

Do not silently fold water compressibility into the mechanical target.

Report a separate optional water contribution using:

- rho_w = 1000 kg/m3;
- g = 9.80665 m/s2;
- beta_w = 4.4e-10 Pa^-1;
- porosity n only when independently source-bound or explicitly derived under a
  preregistered particle-density rule.

Until such porosity is available, the primary target is Ssk, not total Ss.

## Void-ratio / Cr route

No Cr or Cc fit is needed for the first target extraction because the stress-
strain data permit direct mv calculation.

If a later workunit derives Cr from e-log(sigma') it must be preregistered
separately. Virgin compression index Cc is prohibited as an ELAS substitute.

## Metadata preserved per target

For every emitted target record preserve:

- BRO-ID;
- owning ELASTIC10D cell;
- settlement determination index;
- determination method/procedure;
- sample/depth interval where source-bound;
- step index and step type;
- stress endpoints;
- strain endpoints;
- signed deltas;
- mv;
- Ssk in m^-1 and cm^-1;
- density, solids density, water content, moisture, sample quality and organic
  matter when source-bound;
- exact source object SHA-256;
- exact SWE record reference;
- validity/rejection reason.

No missing descriptor is imputed.

## Duplicate and repeated determinations

Every valid determination target is retained independently.

Do not average within an object in this workunit.
Do not average repeated intervals or duplicate-looking determinations.
Potential duplicates are flagged only after comparing source identity and depth.

## QA gates

T1 — byte/source identity:
the 16 frozen object identities and artifact provenance are reproduced.

T2 — SWE schema binding:
field order and units are bound before values are interpreted.

T3 — parser determinism:
two independent parses of each raw object produce identical target records.

T4 — physical sanity only, not selection:
- mv must be finite and > 0;
- Ssk must be finite and > 0.
No empirical upper/lower plausibility cutoff may discard a target in this first
extraction. Extreme values are retained and flagged.

T5 — route traceability:
every emitted target is labelled R2 or R3 and points to the exact source step
and SWE block.

## Frozen outputs

Produce:

1. one row per valid mechanical target;
2. one row per rejected candidate pair/step with reason;
3. counts by object and route;
4. descriptive unfiltered distributions of mv and Ssk;
5. coverage matrix for mechanical and pedological metadata.

No regression coefficients, soil-class mapping, BOFEK lookup or production ELAS
default are output here.

## Holdout boundary for later predictor modelling

Before any later descriptor -> ELAS/Ssk model is fitted, a separate workunit must
freeze object-level calibration/holdout groups.

F-PE-ELASTIC10E itself uses all 16 objects only to establish the target-extraction
method and target corpus. It does not estimate a predictive model.

## Success condition

Success requires at least one valid R2 or R3 mechanical target with complete
source traceability and unit-bound conversion to Ssk.

A zero-target result after strict decoding is a valid negative and must be
recorded without relaxing extraction rules.
