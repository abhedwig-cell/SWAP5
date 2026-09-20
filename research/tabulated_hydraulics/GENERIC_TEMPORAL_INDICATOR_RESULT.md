# TAB-HYD provider-agnostic temporal-indicator result

Date: 2026-09-20

Status: **research result; production implementation held**

## Research question

Can the current Reference-Richards temporal indicator use the common
`constitutive_hydraulics_provider_t` evaluation ABI without changing the
admitted analytical-MvG result, and does the same mathematics remain
well-behaved for the generated raw-head400 provider?

This is the preregistered TAB-HYD-005 experiment in
`GENERIC_TEMPORAL_INDICATOR_PREREGISTRATION.md`.

## Authority

- canonical preimage: `integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`;
- canonical indicator: `src/solver/mod_reference_richards_temporal_indicator.f90`;
- common constitutive ABI: `src/solver/mod_soil_water_solver_contract.f90`;
- generated table representation: bounds-safe raw-head400 research provider;
- qualification workflow run: `35538572717`.

No canonical production source was changed.

## Research-only change

The candidate was created mechanically from the canonical indicator by
`research/tabulated_hydraulics/patch_generic_temporal_indicator.py`.

Only constitutive dispatch changed:

1. the existing analytical-provider step-duration consistency check was retained
   exactly for `b110_default_mvg_provider_t`;
2. the two constitutive evaluations were issued through the existing abstract
   provider pointer;
3. non-MvG providers were no longer rejected solely because of concrete type.

No indicator formula, operator construction, linear algebra, boundary envelope,
source/sink policy, normalization, tolerance, or route-selection formula was
changed.

## Phase A — analytical equivalence

All five preregistered profiles passed.

For each profile the canonical analytical indicator and the generic-dispatch
analytical indicator had:

- identical status;
- identical availability;
- identical route string;
- identical additional nonlinear/tridiagonal solve counters;
- scalar norms/head bound/minimum mass weight equal within the preregistered
  `1e-14 * max(1,abs(reference))` gate;
- current-right-derivative vector equal within the same scaled tolerance.

Result: **Phase A PASS**.

This establishes that provider-agnostic constitutive evaluation does not require
a change to the temporal-indicator mathematics for the admitted analytical MvG
route.

## Phase B — generated table characterization

The same generic indicator was then evaluated using the bounds-safe generated
raw-head400 provider. The canonical indicator continued to return
`constitutive-policy-deferred` for that provider, demonstrating the existing
owner-boundary restriction.

The generic research indicator was available in all five cases:

| profile | analytical head bound | table head bound | route |
| --- | ---: | ---: | --- |
| coarse_dry_free | 1.3784398416 | 1.3784312240 | reference-richards-raw-bound |
| loam_mid_free | 0.7996648119 | 0.7996646097 | reference-richards-defect-bound |
| clay_wet_free | 0.6474189031 | 0.6474184467 | reference-richards-defect-bound |
| coarse_dry_pulse | 8.9622935714 | 8.9623578082 | reference-richards-raw-bound |
| loam_capillary | 1.3120751570 | 1.3120751263 | reference-richards-defect-bound |

The table result was finite and positive where required, and the bound-selection
classification matched the analytical route for every profile.

Result: **Phase B PASS**.

This is characterization, not a production temporal-certificate admission.

## Related dynamic-fixture diagnosis

Run `35538460638` independently diagnosed the earlier failed non-equilibrium
serialized-runtime fixture.

For coarse, loam and clay, drying and wetting, and perturbations down to
`0.003125` (0.3125%), the analytical reference itself produced:

- attempts = 9;
- retries = 8;
- solver rejections = 0;
- temporal rejections = 9;
- mass rejections = 0;
- admission rejections = 0.

Therefore that fixture is blocked purely by its external full/half temporal gate.
It is not evidence against the table provider and must not be repaired by
loosening tolerances.

## Architecture conclusion

TAB-HYD-005 is narrowed from a mathematical/provider-compatibility blocker to a
**solver-contract capability blocker**.

The common provider ABI can already supply all constitutive values needed by the
indicator. What it cannot express generically is the existing invariant checked
for the analytical provider:

`provider bound step duration == request%step_duration`.

The production design must make that invariant explicit before the generic
indicator can be admitted.

Two defensible designs remain:

1. make timestep context an explicit input to constitutive evaluation so the
   provider is stateless with respect to dt; or
2. extend the constitutive contract with a minimal context-validation/capability
   operation through which the temporal-indicator owner can verify the bound
   timestep.

This decision belongs to the Reference-Richards / solver-contract owner. It
must not be hidden inside TAB-HYD-specific type dispatch.

## Disposition

- raw-head interpolation research: no further temporal-mathematics repair needed;
- generic temporal-indicator mathematics: **qualified in research**;
- production generic temporal certificate: **held pending explicit timestep-context contract**;
- analytical MvG remains the production reference;
- no canonical source or production admission changed.
