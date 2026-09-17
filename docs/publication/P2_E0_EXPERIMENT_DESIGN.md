# P2 E0 experiment design

## Purpose

PUB-P2E01 turns the admitted RossFast E0 envelope into a controlled paired-solver experiment without yet broadening solver physics.

The immediate objective is not to prove equivalence. It is to establish a reproducible Reference-versus-RossFast comparison protocol, verify that both routes expose scientifically comparable state observations, and freeze the rules before broad E0 sampling.

## Hard experimental principle

Every scientific case is a pair:

```text
same declared physical parameters
same committed initial physical state
same forcing and boundary contract
same requested interval
same surrounding application lifecycle
        |
        +--> REFERENCE_RICHARDS
        |
        +--> ROSSFAST_D3R
```

The solver identity is the treatment variable. A case is excluded from paired inference if another scientific input differs between routes.

## Stage 0: extraction pilot

The first pilot deliberately reproduces the already admitted F-ROSS12 B01 production route.

### Fixed pilot condition

- material: `B01`
- active nodes: 16
- cell thickness: 10 cm
- initial pressure head: uniform `-101 cm`
- initial water content: derived from the same admitted hydraulic relation used to construct the typed state
- top boundary: prescribed flux
- top flux: `0.01 * K(h0)` using the B01 conductivity at the declared initial head
- bottom boundary: prescribed flux under the currently admitted bottom mode
- bottom flux: `-0.004 * K(h0)`
- root extraction: inactive
- distributed sources/sinks: zero
- drainage response: inactive
- macropores: inactive
- snow/frost/soil temperature: inactive
- hysteresis and tabulated hydraulics: inactive
- requested horizon: the admitted `ROSSFAST_D3R_OUTER_HORIZON_DAY`
- transaction lifecycle: current canonical production transaction

This pilot is chosen because the RossFast route is already qualified there. It does not introduce a new physical claim.

### Pilot routes

Run exactly two model selections:

1. explicit `REFERENCE_RICHARDS` through the current common production host;
2. explicit `ROSSFAST_D3R` through the same host and solver seam.

No automatic fallback is allowed in either paired comparison. A route that cannot execute the declared case is recorded as an exclusion or failure, not silently replaced.

## Existing observation path

The current kernel already provides an observation-safe route to endpoint physical state. `kernel_committed_state_t` owns its physical continuation state privately but exposes `snapshot()`, which returns a clone of the committed physical state. The concrete serialized physical state contains pressure-head and water-content arrays.

Therefore PUB-P2E01 should first use committed-state snapshots after the accepted transaction rather than add a new production observation ABI merely for publication.

The existing `fmr_serialized_physical_observation_t` remains useful for solver route, terminal flux and temporal diagnostics, but it does not by itself expose the full accepted endpoint profile.

## E0 identifiability boundary

The current RossFast E0 envelope admits prescribed-flux boundaries only. This has an important scientific consequence.

When top and bottom water fluxes are prescribed identically to both routes, agreement of those imposed boundary fluxes is not independent evidence that the two solvers predict the same flux response. Within E0, boundary transfer is primarily an experimental input and a conservation/accounting check.

Accordingly:

- endpoint pressure head, water content and profile storage are discriminating solver responses in E0;
- independent mass closure remains a hard validity requirement for each route;
- prescribed top/bottom transfer consistency is useful for checking that both runs received and accounted for the same experiment;
- zero or near-zero difference in imposed boundary transfer must **not** be presented as evidence of flux-prediction equivalence.

A strong Paper 2 claim about solver interchangeability for predicted boundary fluxes will require a later independently qualified expansion in which at least one scientifically relevant boundary flux is an outcome rather than fully prescribed input, for example an admitted head-controlled, groundwater-interacting or dynamic surface boundary.

That later expansion is outside E0 and must not be smuggled into PUB-P2E01.

## Pilot observations

Before the pilot can yield scientific comparison evidence, both routes must expose a common representation sufficient to compare:

- pressure head for every active node at the accepted endpoint;
- water content for every active node at the accepted endpoint;
- profile storage at start and accepted endpoint;
- independent water-balance residual for each route;
- applied interval-integrated prescribed top and bottom transfers in the common public sign convention;
- accepted interval duration;
- commit status and final physical revision;
- route identity and failure/retry diagnostics.

The first four items are scientific response/validity quantities. Prescribed boundary transfer is experimental-control evidence in E0, not a discriminating solver-output metric.

If a scientifically required quantity cannot be obtained on the same basis from both routes, PUB-P2E01 stops at `OBSERVATION_CONTRACT_GAP`. A missing quantity must not be reconstructed from an inequivalent diagnostic solely to make the comparison complete.

## Metric definitions

Metric definitions are frozen before broad E0 execution.

### Head

For paired endpoint node heads `h_R(i)` and `h_A(i)`:

```text
D_h_inf = max_i |h_A(i) - h_R(i)|
D_h_rms = sqrt(mean_i((h_A(i) - h_R(i))^2))
```

Report both. A single aggregate can hide depth-localized divergence.

### Water content

```text
D_theta_inf = max_i |theta_A(i) - theta_R(i)|
D_theta_rms = sqrt(mean_i((theta_A(i) - theta_R(i))^2))
```

### Storage

```text
D_storage_abs = |S_A - S_R|
```

A relative storage measure may be added only with a declared denominator that remains meaningful in dry cases.

### Prescribed boundary-transfer control

For E0 only, record the applied integrated top and bottom transfers for both routes and verify identical experimental control after sign normalization.

Do not interpret

```text
D_qtop = 0
D_qbot = 0
```

as independent solver-equivalence evidence when those quantities were prescribed by construction.

### Mass

Each route is tested independently against the hard mass requirement. Pairwise similarity of mass residuals is not sufficient.

Record:

```text
mass_reference
mass_alternative
mass_reference_pass
mass_alternative_pass
```

A case cannot be scientifically admissible when either route violates its own conservation requirement.

## Scientific tolerances

PUB-P2E01 does **not** invent numerical admissibility tolerances merely to complete the manifest.

Current status:

```text
head admissibility tolerance: TO_BE_PREDECLARED
water-content admissibility tolerance: TO_BE_PREDECLARED
storage admissibility tolerance: TO_BE_PREDECLARED
predicted-flux admissibility tolerance: NOT_APPLICABLE_WITHIN_PRESCRIBED-FLUX E0
mass acceptance: existing independent hard route requirement, exact authority to be pinned
```

Before Stage 1 broad sampling, each scientific state/storage tolerance needs a documented basis. Acceptable bases include:

- an existing qualified SWAP numerical tolerance with the same physical meaning;
- a discretization-derived bound;
- a scientifically justified application-resolution threshold;
- a sensitivity analysis showing that the chosen threshold is below a consequential model-response scale.

Observed RossFast discrepancies may not be used to choose a tolerance after the fact.

## Stage 0 verdict semantics

The pilot can return only one of:

- `PAIRED_EXTRACTION_READY`: both routes executed the same physical case and all required common state/conservation observations were obtained;
- `OBSERVATION_CONTRACT_GAP`: one or more scientifically required observations cannot yet be compared on the same basis;
- `ROUTE_EXECUTION_GAP`: one solver cannot execute the exact paired pilot under its declared current contract;
- `IMPLEMENTATION_DEFECT_CANDIDATE`: evidence indicates a likely implementation or adapter error requiring separate adjudication.

The pilot must **not** return `SCIENTIFICALLY_EQUIVALENT`, because scientific admissibility tolerances are intentionally not yet set and E0 does not test predicted boundary-flux equivalence.

## Stage 1 E0 design principle

After Stage 0 extraction is qualified and scientific state/storage tolerances are predeclared, expand within the existing E0 envelope only.

To compare hydraulic states fairly across materials, prefer a material-normalized initial-state descriptor rather than reusing the same pressure head blindly for every soil. Candidate descriptor:

```text
initial effective saturation Se0
```

with pressure head calculated from the exact admitted hydraulic parameter authority for each material.

The actual `Se0` levels must be frozen only after the six material parameter authorities have been pinned and the inversion has been checked against the Reference constitutive implementation.

Forcing should likewise be normalized where scientifically defensible, for example against material-specific conductivity or storage scales, while retaining absolute physical flux values in the evidence record.

## Stage 1 factors that may vary without broadening E0 physics

- material among B01, B12, O01, O05, O14, O18;
- qualified uniform initial hydraulic state;
- prescribed top-flux magnitude and sequence;
- prescribed bottom-flux magnitude within the admitted boundary contract;
- interval/forcing sequence within the admitted temporal model.

## Factors explicitly frozen in E0

- 16 active nodes;
- 10 cm cell thickness;
- homogeneous admitted material per column;
- no root sink;
- no distributed source/sink;
- no groundwater head boundary;
- no energy or soil-temperature coupling;
- no heterogeneous profile;
- no mixed MultiSWAP execution;
- no silent fallback between solvers.

Any change to these factors belongs to a later independently qualified expansion, not to E0.

## Sampling strategy

Do not use an exhaustive full factorial by default.

Preferred sequence:

1. stratified or space-filling sample over normalized initial state and prescribed forcing for all six materials;
2. identify regions where **state or storage** discrepancy approaches the predeclared scientific threshold;
3. refine sampling around those transition regions;
4. retain clearly admissible, borderline and excluded cases in the publication dataset.

This focuses compute on the scientific boundary instead of maximizing case count.

## Performance measurement boundary

Stage 0 and early Stage 1 may record coarse runtime diagnostics for debugging, but they do not support a publication speed claim.

A performance result enters Paper 2 only under the repository's controlled performance-measurement discipline, including host qualification, repeated paired measurements and uncertainty. Shared-host single timings are not evidence of meaningful speedup.

## Negative results

Every excluded or divergent pair is retained. Classification must distinguish:

- unsupported contract;
- implementation or adapter defect candidate;
- conservation failure;
- temporal acceptance failure;
- scientifically material state/storage discrepancy;
- comparison-observation gap.

This distinction is required before interpreting an exclusion as a limitation of the numerical method.

## Next permitted action

Implement the smallest observation-only paired runner for the exact Stage 0 B01 case by reusing the current production host and committed-state `snapshot()` API. It may add publication tooling or tests, but must not modify Reference science, RossFast science, transaction semantics or qualification tolerances.

Only after the paired extraction contract passes may PUB-P2E01 freeze the broad E0 experiment manifest.
