# TAB-HYD-005 — Reference temporal indicator is concretely bound to the analytical MvG provider

Date: 2026-09-20

Status: **research finding; mathematical genericization qualified, production contract still held**

## Authority

Reconciled against:

- `integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`;
- `src/solver/mod_reference_richards_temporal_indicator.f90`;
- `src/solver/mod_soil_water_solver_contract.f90`;
- `src/runtime/mod_fmr_serialized_reference_backend.f90`.

The finding concerns the current typed Reference-Richards temporal-indicator capability. It is not a defect in the tabulated interpolation algorithm.

## Finding

The common constitutive contract is provider-polymorphic:

`constitutive_hydraulics_provider_t%evaluate(pressure_head, water_content, conductivity, capacity, dconductivity_dhead)`

but the Reference-Richards temporal indicator is not.

The indicator contains a concrete type dispatch:

```fortran
select type (constitutive => request%evaluation%constitutive)
type is (b110_default_mvg_provider_t)
   ...
   call constitutive%evaluate(...)
   call constitutive%evaluate(...)
class default
   indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
   indicator_result%route = 'constitutive-policy-deferred'
   return
end select
```

Therefore any otherwise valid constitutive provider behind the common ABI — including the research raw-head table provider — is deliberately denied a Reference-Richards temporal certificate.

This is an owner-boundary restriction, not merely an implementation inconvenience.

## Why this matters for TAB-HYD

The generated raw-head typed table provider has already shown:

- approximately 19.4% lower provider evaluation cost over the 30-row Staring set;
- approximately 24-30% lower direct Reference-Richards runtime in the current 32-node research profiles;
- approximately 25-31% lower serialized Reference runtime in the provider-consistent equilibrium fixture;
- zero equilibrium head difference in that serialized fixture and no mass/retry regression.

A production-capable dynamic transaction route, however, may require the Reference-Richards temporal indicator. The present indicator refuses the table provider by concrete type before the mathematical indicator is evaluated.

Consequently TAB-HYD cannot solve this by:

- changing interpolation knots;
- changing lookup;
- loosening transaction tolerances;
- silently falling back to analytical constitutive values inside the indicator;
- special-casing the research table class in production without qualification.

## Separate fixture result

A research attempt to create a simple non-equilibrium serialized-runtime test perturbed the equilibrium top flux while keeping the existing external-full/half transaction policy.

The analytical reference itself rejected every preregistered perturbation magnitude from 40% down to 1.25% for the tested coarse, loam and clay wetting/drying combinations. Those runs therefore do not constitute a table failure and are not used to relax the transaction tolerance.

This fixture limitation is separate from the concrete-provider restriction above.

## Smallest safe research experiment

Before any production architecture change, a provider-agnostic temporal-indicator experiment must be staged in two phases.

### Phase A — analytical equivalence gate

Create a research-only version of the current temporal-indicator algorithm that obtains constitutive values through the abstract provider ABI.

For `b110_default_mvg_provider_t`, retain the existing step-duration consistency check and require the genericized implementation to reproduce the current implementation for the admitted analytical fixtures:

- same availability/status;
- same route classification;
- same head-inf bound to numerical roundoff;
- same raw/defect/bounded norms where exposed;
- same accepted/rejected transaction decision when integrated.

Any analytical discrepancy blocks Phase B.

### Phase B — table-provider characterization

Only after Phase A passes may the same algorithm be evaluated with the research table provider.

This phase is characterization only. It cannot itself admit a production temporal certificate because the generic constitutive ABI currently has no explicit method exposing or validating the provider's bound step duration.

## Architecture implication

A production-grade provider-agnostic temporal indicator likely needs one of two explicit contracts:

1. temporal evaluation receives all timestep-dependent constitutive context through the request and providers are stateless with respect to dt; or
2. the constitutive provider exposes a small validation/capability method allowing the temporal-indicator owner to verify that its bound evaluation context matches `request%step_duration`.

The present concrete member access

`constitutive%step_duration`

is evidence that the current common provider ABI is insufficient to express this validation generically.

That contract decision belongs to the Reference-Richards / solver-contract owner, not to TAB-HYD interpolation code.

## Disposition

TAB-HYD typed K0 acceleration is scientifically promising, but **production implementation remains held** at this boundary.

The next admissible step is analytical-equivalence research on a provider-agnostic temporal-indicator formulation. No canonical source or production admission is changed by this finding.


## Research experiment result

The preregistered provider-agnostic temporal-indicator experiment has now been executed successfully.

Controlling workflow:

- `TAB-HYD generic temporal-indicator characterization`;
- run `35538572717`;
- canonical preimage `integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`.

### Phase A — analytical equivalence

All five frozen profiles passed the preregistered analytical-equivalence gate:

- coarse_dry_free;
- loam_mid_free;
- clay_wet_free;
- coarse_dry_pulse;
- loam_capillary.

The research implementation changes only the constitutive dispatch. For the canonical analytical provider it preserves the concrete `step_duration` check and then executes the unchanged indicator mathematics through the common provider `evaluate` interface.

For every profile the gate reported:

`TABHYD_TEMPORAL_PHASE_A=PASS`

The harness requires identical status, availability, route, solve counters and roundoff-scaled equality for all exposed indicator values and the current-right-derivative vector. Therefore the concrete type dispatch is not mathematically necessary for the analytical result.

### Phase B — table-provider characterization

The same unchanged indicator mathematics was then evaluated with the bounds-safe raw-head table provider. All five profiles reported:

`TABHYD_TEMPORAL_PHASE_B=PASS`

and the table indicator was available rather than `constitutive-policy-deferred`.

Representative analytical/table head-inf bounds were:

| profile | analytical | raw-head table |
| --- | ---: | ---: |
| coarse_dry_free | 1.3784398416 | 1.3784312240 |
| loam_mid_free | 0.7996648119 | 0.7996646097 |
| clay_wet_free | 0.6474189031 | 0.6474184467 |
| coarse_dry_pulse | 8.9622935714 | 8.9623578082 |
| loam_capillary | 1.3120751570 | 1.3120751263 |

Route classifications were also well-behaved: the table provider selected the same raw-bound/defect-bound family expected from the unchanged indicator formula.

These values are characterization evidence, not a production temporal-certificate admission.

## Updated blocker disposition

TAB-HYD-005 is now split into two parts:

1. **Mathematical/provider-dispatch question: CLOSED for research.**
   - The current temporal-indicator formula can operate through the abstract constitutive provider ABI.
   - Analytical equivalence was demonstrated prospectively before table characterization.
   - No tolerance or indicator formula was changed.

2. **Production context-validation contract: OPEN.**
   - Canonical currently verifies `constitutive%step_duration == request%step_duration` by concrete access to `b110_default_mvg_provider_t`.
   - The common `constitutive_hydraulics_provider_t` interface has no generic capability/context-validation operation.
   - The research Phase B deliberately cannot prove this property generically.

The next production-facing architecture work therefore must not special-case `tabhyd_raw_provider_t` inside the temporal indicator. It should define a minimal provider-generic validation contract, or move all timestep-dependent constitutive context into explicit request state so providers are stateless with respect to dt.

## Synthetic dynamic-runtime diagnostic

Run `35538460638` also confirms why the earlier simple dynamic serialized-runtime sweep cannot act as an admission denominator.

At perturbations down through `0.003125`, for coarse, loam and clay and for both wetting and drying:

- attempts = 9;
- retries = 8;
- solver rejections = 0;
- temporal rejections = 9;
- mass rejections = 0;
- admission rejections = 0.

Thus the analytical Reference solver converges, but the synthetic transaction is rejected exclusively by its temporal criterion. This is a fixture/execution-class limitation, not evidence against the table provider, and no temporal tolerance is relaxed in response.
