# F-PE-ELASTIC10A — official BHR-GT settlement semantics pre-audit

Date: 2026-09-29

Status: OFFICIAL_CATALOGUE_SUPPORTS_RECOVERABLE_RECOMPRESSION_TARGET

Parent:
F-PE-ELASTIC10 BHR-GT target acquisition preregistration.

This is a documentation pre-audit from the official BHR-GT catalogue. The
machine-readable OpenAPI/XML binding remains owned by the F-PE-ELASTIC10 CI
schema audit.

## Official catalogue findings

The current BHR-GT settlement-properties model explicitly represents stepwise
compression mechanics.

For `Bepaling zettingseigenschappen` / settlement-properties determination:

### Step type

`Bepalingsstap%staptype` distinguishes at least:

- loading (`belasten`);
- unloading (`ontlasten`);

and for rate-controlled compression also relaxation.

The catalogue explicitly states that in load-controlled compression a specimen
is normally loaded and is unloaded in one of the steps.

This is critical: the data model contains stress-path direction, so an
unloading/recompression branch does not have to be guessed from point order.

### Vertical stress

For load-controlled compression:

`Bepalingsstap%verticale spanning`

is the vertical specimen stress after the determination step.

Unit:
`kPa`.

### Vertical strain

The settlement time series contains:

`Zettingstoestand%verticale rek`

defined as:

`(initial specimen height - current height) / initial specimen height`.

Unit:
percent.

The catalogue notes that apparatus-deformation correction may be applied and
that this provenance is separately recorded.

### Rate-controlled / CRS path

For rate-controlled settlement the stress history contains:

- elapsed time;
- vertical strain;
- pore-pressure difference;
- vertical effective/grain stress;
- optional horizontal effective/grain stress.

The vertical grain stress is explicitly defined as total vertical stress minus
pore-water overpressure.

This makes the CRS route especially valuable for effective-stress-based
mechanical characterization.

## Implication for ELAS identification

The BHR-GT data model contains enough first-principles information to construct a
small-strain/recompression mechanical target **if actual registered objects
populate these fields with sufficient resolution**.

For load-controlled tests, a candidate local unload/reload tangent can be
obtained from:

- change in vertical strain;
- change in vertical stress;
- explicit step type.

For CRS tests, a candidate tangent can be based directly on:

- vertical strain;
- vertical grain/effective stress.

A constrained tangent compressibility can then be expressed as approximately:

`mv = d epsilon_v / d sigma'_v`

for a sufficiently small, reversible interval.

The skeleton-specific-storage contribution is then:

`Ss_skeleton = gamma_w * mv`.

This route avoids substituting virgin compression index `Cc` for elastic
storage.

## Important cautions

The availability of the fields in the catalogue is not yet evidence that public
objects contain usable unload/reload sequences.

Before deriving targets, the acquisition workunit must still verify:

1. actual BHR-GT objects contain settlement determinations;
2. the SWE time/stress/strain series are recoverable;
3. step type is present and unambiguous;
4. stress and strain corrections/provenance are preserved;
5. the unloading branch has enough points or endpoints to estimate a slope;
6. the relevant stress increment is small enough to interpret as tangent or
   recompression behavior;
7. specimen quality/disturbance and moisture state are known.

## Consequence

F-PE-ELASTIC10 is upgraded from:

`MECHANICAL_TARGET_POSSIBLY_AVAILABLE`

to:

`MECHANICAL_TARGET_SEMANTICALLY_AVAILABLE_OBJECT_COVERAGE_UNVERIFIED`.

If the pilot finds populated unload/reload data, BHR-GT becomes the preferred
Dutch target source for a physically based ELAS study.
