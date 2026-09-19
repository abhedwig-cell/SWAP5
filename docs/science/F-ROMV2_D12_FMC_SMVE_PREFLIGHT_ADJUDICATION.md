# F-ROMV2 D12 — FMC/SMVE equation-authority preflight adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D12  
**Decision:** **D12_FMC_SMVE_EQUATION_PREFLIGHT_PASS**

## Question

D12 asks whether the finite-water-content / Soil Moisture Velocity Equation
(FMC/SMVE) family is sufficiently reconciled at equation and invariant level to
justify a later SWAP5 hydraulic development comparator.

D12 deliberately stops before any SWAP trajectory comparison.

That ordering is essential. The equations, signs, discretization and numerical
preflight are fixed from primary-source authority rather than selected because
they happen to fit an exposed SWAP history.

## Primary scientific authority

The frozen authority consists of:

- Ogden et al. (2015), *A new general 1-D vadose zone flow solution method*,
  Water Resources Research 51, 4282–4300,
  DOI **10.1002/2015WR017126**;
- Ogden et al. (2015), moving-water-table column validation,
  DOI **10.1002/2014WR016454**;
- Ogden et al. (2017), *The Soil Moisture Velocity Equation*,
  DOI **10.1002/2017MS000931**;
- Morel-Seytoux et al. (1996), effective capillary-drive equivalence,
  DOI **10.1029/96WR00069**.

The University of Wyoming public FMC/SMVE material is retained only as a
secondary oracle. It was **not** executed and no external source code was copied
into SWAP5 for D12.

## Frozen equation identity

The FMC state is expressed in finite increments of volumetric water content.

For an infiltration front, the primary 2015 formulation gives the incremental
front velocity

[
\frac{dz_j}{dt} =
\frac{K(\theta_d)-K(\theta_i)}
     {\theta_d-\theta_i}
\left[
1+\frac{G_{\mathrm{eff}}+h_p}{z_j}
\right].
]

For a groundwater-connected front,

[
\frac{dH_j}{dt} =
\frac{K(\theta_j)-K(\theta_i)}
     {\theta_j-\theta_i}
\left[
\frac{|\psi(\theta_j)|}{H_j}-1
\right].
]

The latter supplies an exact preflight identity:

[
H_j=|\psi(\theta_j)| \Rightarrow \frac{dH_j}{dt}=0.
]

The equations are not the full mass-conservation authority by themselves.
FMC conservation also depends on the published finite-volume bookkeeping:
water added to or removed from each moisture-content increment is represented
by the corresponding finite front displacement, and capillary relaxation
reorders fronts without changing represented water volume.

D12 therefore treats the **equations plus finite-volume ledger** as the
scientific object.

## Discretization authority

D12 freezes **200 moisture-content bins** before any SWAP comparator.

This is not chosen from a SWAP convergence study. It is the upper end of the
approximately 150–200-bin range reported in the primary 2015 method for
representing the full infiltration moisture range accurately.

The constitutive value for each bin is evaluated at the right edge, matching the
corrected published method.

For the explicit infiltration-front preflight the maximum substep is frozen at
**10 seconds**, again from the primary numerical guidance rather than from a
SWAP result.

Neither bin count nor substep may be retuned against D13 SWAP discrepancies.

## Immutable execution

Workflow run **35450870852**, job **105917670077**, executed head

`bdd20c92121a0d7eb1dffdfef22264283bda8670`.

Artifact:

- ID: **10586825733**
- digest:
  `sha256:5571783a8ffb9f2ccca24a2467fd6668a541187ae6c37eef5b4e0c690e00333e`
- preflight-result SHA-256:
  `9ead50aea06e5f9c2f41ff93ecc1358bf9f00408d7ca2c2ee1850c84bd48d8fa`
- stdout SHA-256:
  `ba606f06daebeae9b4bca8fd614e81733b6f1d8dc6f3a9ef25d95ed822493265`.

No SWAP trajectory evidence was consumed.

No external implementation was executed.

## P1 — one-bin Green-Ampt identity

The single-bin FMC infiltration equation reduces exactly to the corresponding
Green-Ampt front equation.

Frozen numerical control:

- FMC front velocity:
  **11.710248358549814**
- Green-Ampt front velocity:
  **11.710248358549814**
- absolute difference:
  **0**

**PASS**

This confirms the expected limiting identity of the published formulation.

## P2 — groundwater hydrostatic equilibrium

For 169 finite B01 moisture states wetter than the frozen initial comparison
state, the groundwater-front depth was set to

[
H_j=|\psi(\theta_j)|.
]

The maximum absolute groundwater-front velocity is

**0.0 cm d⁻¹**.

**PASS**

This verifies the sign convention and equilibrium branch of the published
groundwater-front equation independently of any SWAP lower-boundary result.

## P3 — finite-volume capillary relaxation

A deterministic non-monotone front vector was reordered using the
sorting-style capillary-relaxation invariant.

Represented water before:

**0.2368558875 cm**

Represented water after:

**0.2368558875 cm**

Difference:

**0.0 cm**

The output ordering is monotone.

**PASS**

This is the key distinction between an explicit physical reduction and a
post-hoc mass correction: the relaxation changes profile geometry without
creating or removing water.

## P4 — B01 constitutive identity and effective capillary drive

Across the frozen 200-bin open B01 moisture interval:

- capillary suction decreases strictly with increasing water content;
- hydraulic conductivity increases strictly with increasing water content.

The effective capillary drive was evaluated directly from the actual B01
relative-conductivity curve rather than by importing a standard fitted
Brooks-Corey/Van-Genuchten approximation with different parameter assumptions.

The resulting value is

[
H_{cM} \approx \mathbf{14.085215420920257\ cm}.
]

Changing the infinite-domain transform cutoff from (1-10^{-8}) to
(1-10^{-10}) changes the result by only about

**2.52e-16 relative**.

**PASS**

This value is now fixed B01 FMC research authority. It may not be altered to
improve a later SWAP comparison.

## P5 — published power-law analytical timescale

The Ross-Parlange/SMVE power-law control was evaluated for

- (A=2) cm h⁻¹;
- (K_1=1) cm h⁻¹;
- (D_1=100) cm² h⁻¹;
- (n=3,ldots,9).

The published ponding/surface-saturation timescale is reproduced and decreases
monotonically with (n).

The leading-front identity (z_{max}=At) has zero numerical discrepancy in
the frozen test.

**PASS**

## Scientific meaning

D12 establishes five things:

1. the main FMC infiltration and groundwater-front equations are internally
   consistent under their published sign conventions;
2. the hydrostatic groundwater branch behaves correctly;
3. capillary relaxation can be treated as a mass-preserving reordering
   operation;
4. B01 supplies a valid monotone constitutive manifold and finite effective
   capillary drive;
5. the initial 200-bin / 10-second numerical choices are independently frozen.

D12 does **not** yet establish that a complete FMC implementation reproduces the
full published event logic.

In particular, the following algorithmic mechanisms still require an integrated
preflight or comparator implementation:

- allocation of applied surface water among groundwater-connected bins and
  infiltration fronts;
- falling-slug creation and equation-19 advance;
- collisions and mergers among infiltration, falling-slug and groundwater
  fronts;
- capillary relaxation after those process updates;
- finite-volume lower-boundary exchange for a supported constant-head/water-
  table configuration;
- full time-step water ledger across all of those operations.

This distinction prevents an equation-level success from being overclaimed as
a model-level success.

## D13 authority

D13 is authorized as a **separately preregistered hydraulic development
comparator with an internal published-algorithm preflight gate**.

Its first SWAP envelope is bounded to:

- homogeneous B01;
- no root extraction;
- no ET;
- 200 frozen moisture-content bins;
- maximum infiltration substep 10 seconds;
- R16 and admitted R2 comparators;
- a lower-boundary/water-table configuration directly supported by the primary
  FMC/SMVE authority.

The preferred first lower-boundary case is a water table at the model bottom,
equivalent to zero pressure head there, because that is both physically relevant
and directly represented by the published groundwater-front framework.

Arbitrary nonzero SWAP prescribed bottom pressure head is **not** authorized by
D12.

Existing V01–V04 histories are exposed development evidence and cannot become
blind confirmation.

## Remaining scientific boundary

Even a successful D13 would not yet establish:

- ET or root-uptake fidelity;
- drought-memory fidelity;
- arbitrary SWAP lower-boundary coverage;
- cross-material transfer;
- application acceptance;
- production speedup;
- production ROM authority.

Published HYDRUS timing ratios remain external precedent only.

Any SWAP5 computational-value claim requires a same-runtime cost comparison
after hydrological candidacy is established.

Production ROM remains unauthorized.
