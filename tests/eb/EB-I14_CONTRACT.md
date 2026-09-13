# EB-I14 Bottom Liquid-Water Sensible-Energy Quadrature Contract Freeze

## Status and authority

Restart authority:

`work/eb-i13-bottom-thermal-carrier-implementation@c3458c3df0428de0f2500e211391122c64c2de33`

EB-I13 qualification authority:

- workflow: `EB-I13 bottom thermal carrier qualification`
- run: `34789053984`
- conclusion: `success`
- tested head: `c3458c3df0428de0f2500e211391122c64c2de33`

Decision:

`DESIGN_FROZEN_NO_PRODUCTION_IMPLEMENTATION`

EB-I14 freezes the narrow discrete law that a later production workunit may use to convert an already-qualified EB-I13 accepted bottom water-thermal sample sequence into candidate-scoped liquid-water sensible energy. EB-I14 changes no production source and does not publish or commit energy.

## Why another contract is required after EB-I13

EB-I13 solved the information-lifetime problem. It preserves, for every selected accepted model advance, the signed bottom liquid-water transfer and the local bottom-temperature endpoints when SWAP is the donor. It also preserves incompleteness for inward water whose donor lies outside SWAP.

That still does not uniquely define an energy integral. In continuous time the sensible advective contribution is proportional to

`integral q_b(t) * h_w(T_donor(t)) dt`.

Knowing only an interval-integrated water amount and two temperature endpoints is not enough to reconstruct that continuous integral without an additional numerical convention.

The convention must therefore be tied to the discrete water transfer that SWAP actually accepts, rather than chosen only because a higher-order temperature average looks attractive.

## Current discrete bottom-water authority

On the qualified EB-I13 reference path, one successful physical model advance reports

`Q_b = - q_b,end * Delta_t`,

where:

- `Q_b` is the accepted signed bottom liquid-water amount in the existing SWAP convention;
- positive `Q_b` is outward from SWAP;
- `q_b,end` is `solve_result%bottom_flux` with the sign converted to the outward-positive convention;
- `Delta_t = t1 - t0`.

The same terminal flux is exposed as `terminal_bottom_outward_flux_native`.

Therefore the current discrete water transfer is a terminal-flux rectangle, not a trapezoidal time integral of bottom flux.

## Frozen local-outflow temporal quadrature

For a thermally complete EB-I13 sample with `Q_b > 0`, SWAP is the water donor. EB-I14 freezes the advected donor temperature for that sample as

`T_adv = T_bottom,end`.

The later energy evaluator shall therefore use the terminal local donor temperature from the same successful model advance that produced the terminal bottom flux used in `Q_b`.

This is a discrete-consistency decision. It corresponds to the right-endpoint product

`Delta_t * q_out,end * h_w(T_bottom,end)`

under the current accepted water-transfer discretization.

EB-I14 explicitly rejects these alternatives as the default current-reference rule:

- aggregate outer-interval water multiplied by the final outer bottom temperature;
- arithmetic mean of `T_bottom,start` and `T_bottom,end` multiplied by the current terminal-flux water amount;
- midpoint temperature reconstructed after the fact;
- any re-run of Richards or soil temperature to recover discarded history.

The arithmetic endpoint mean could be a legitimate component of a different jointly qualified flux-temperature quadrature, but combining it with the current terminal-flux rectangle would create a hybrid time discretization. Such a method requires its own water-flux sampling contract and is not silently introduced here.

## Liquid-water sensible-energy law

For one accepted sample, define immutable energy configuration:

- `rho_w` [kg/m3], finite and strictly positive;
- `c_p_w` [J/kg/K], finite and strictly positive;
- `T_ref` [degC], finite.

Let

`K_w = 0.01 * rho_w * c_p_w`.

For `Q_b` in cm and a qualified donor temperature `T_adv` in degC, the outward-positive sensible-energy transfer is

`E_b = K_w * Q_b * (T_adv - T_ref)` [J/m2].

The factor `0.01` converts water depth in cm to m3/m2. The sign of the energy term inherits the already-authoritative sign of `Q_b`; the energy evaluator never reorients water mass.

This law is the same constant-property algebra independently qualified on the EB-I04 owner branch, but EB-I14 does not create a production dependency on that unadmitted branch. A later implementation must requalify the exact production composition against its current base.

## Exact-zero semantics

For `Q_b == 0` exactly:

- no donor temperature is required;
- sample energy is exactly zero;
- unused or unavailable temperature payload must not create energy incompleteness.

There is no small-transfer tolerance. Every finite nonzero water transfer requires donor thermal provenance.

## Inward water and external donor temperature

For `Q_b < 0`, the donor lies outside SWAP. Local bottom-soil temperature is not a valid substitute.

A complete energy evaluation for such a sample requires an explicit finite external liquid-water donor temperature that is bound to the same accepted sample interval and transfer lineage. The physical source may be groundwater, a deep-vadose transfer component or another external component; that mapping belongs to runtime/coupler composition, not to the SWAP kernel.

Current EB-I13 intentionally records inward samples as externally sourced and thermally incomplete because current canonical supplies no such external donor temperature at this seam.

Consequently the first I14-compatible production evaluator must fail closed for a total bottom-energy result when it encounters a nonzero inward sample without explicit external provenance. It may expose a diagnostic local-outflow subtotal, but that subtotal must never be labelled or published as the complete bottom advective-energy transfer.

A future external-temperature binding may make the same algebra complete for `Q_b < 0`; because `Q_b` is negative, water warmer than `T_ref` then contributes negative outward-positive energy, meaning sensible energy enters SWAP.

## Candidate aggregation

For an EB-I13 candidate containing accepted samples `i = 1..N`, a complete bottom sensible-energy result is

`E_bottom = sum_i E_b,i`.

The sum is over the selected accepted-route sample sequence exactly as retained by EB-I13. Samples from rejected full, half or retry routes are absent by construction.

A complete result requires every finite nonzero sample to have complete donor thermal provenance under the direction-specific rules above. One incomplete nonzero sample makes the total energy result incomplete.

The evaluator must not replace the sample sum by

`sum_i(Q_i) * h(T_final)`.

That shortcut loses accepted-substep thermal history and was the original EB-I11 blocker.

## Reference-temperature semantics

`T_ref` is an explicit energy gauge, not a calibration parameter.

For a fixed accepted sample sequence, changing the reference by `Delta T_ref` changes the reported bottom term by the exact identity

`Delta E_bottom = -K_w * Delta T_ref * sum_i(Q_i)`.

A complete control-volume energy balance must use one coherent reference convention in storage and every mass-carried energy term. EB-I14 does not permit choosing `T_ref` to reduce a residual.

## Accuracy classification

The frozen local-outflow rule is a first-order current-reference temporal accounting rule because it follows the terminal-flux rectangle already used for bottom water transfer.

EB-I14 does not claim that this equals the exact continuous-time advective-energy integral. Temporal qualification must therefore include refinement tests. When accepted model advances are refined, the sample-wise energy sum is expected to approach a stable reference if the coupled hydraulic and thermal solutions themselves converge.

A future higher-order energy transport formulation remains allowed behind the same process-level interfaces, but it must jointly qualify the water-flux and donor-temperature quadrature. It may not silently mix a higher-order temperature average with the current terminal-flux water amount and call that higher-order energy transport.

## Hydrologic acceptance versus energy completeness

In the current restricted-thermal architecture, bottom advective energy is not yet part of the governing soil-temperature solve. EB-I14 therefore freezes a nonintrusive qualification rule:

- missing energy provenance does not retroactively invalidate an otherwise mass-conserving accepted hydrologic transaction;
- the optional energy result is marked incomplete and is not eligible for complete-energy publication;
- no water amount is changed, repaired or rebooked to make energy accounting complete.

If a future fully coupled thermal equation requires external advective boundary energy during the physical solve, required donor-temperature availability must be validated before that trial is admitted. That is a later model-evolution step, not an EB-I14 side effect.

## Transaction and publication boundary

EB-I14 freezes calculation semantics only.

A later implementation shall:

- consume only a completed EB-I13 candidate snapshot or an equivalently atomic accepted-route sample sequence;
- produce candidate/result data, never physical continuation state;
- perform no extra Richards or soil-temperature solve;
- publish no accepted energy record before the existing outer candidate commit succeeds;
- discard candidate energy on failed commit or rollback;
- preserve exact hydrologic mass accounting and committed physical state.

Accepted energy-ledger publication remains a separate integration step unless the implementation workunit independently proves the commit/rollback lifecycle.

## MultiSWAP and memory boundary

Energy evaluation shall scale with use:

- no permanent per-column sample history;
- no energy array in columns that do not request the capability;
- immutable `rho_w`, `c_p_w` and `T_ref` may be shared by parameter/template identity;
- evaluation cost is O(number of accepted carrier samples);
- no reconstruction solve is allowed;
- sparse candidate/result publication remains a runtime responsibility.

## Relationship to prior EB work

EB-I14 uses these prior results as scientific and architectural evidence, not as implicit production dependencies:

- EB-I04: constant-property liquid-water sensible enthalpy algebra and reference-gauge identities;
- EB-I06: direction-based donor semantics and exact-zero behavior;
- EB-I08: fail-closed external liquid-water temperature provenance;
- EB-I09: explicit local donor ownership and no donor inference;
- EB-I10R2: atomic accepted transaction binding shape;
- EB-I11: proof that aggregate water times terminal outer temperature is insufficient;
- EB-I12: accepted-route carrier and deferred quadrature decision;
- EB-I13: qualified production carrier implementation.

## Hard nonclaims

EB-I14 does not qualify:

- production Joule calculation;
- external groundwater or deep-vadose temperature physics;
- accepted energy commit/publication;
- a complete energy ledger;
- correction of the restricted soil-temperature governing equation;
- internal soil-face advective heat transport;
- drainage, root, irrigation, precipitation, runoff, ponding, snowmelt, evaporation, vapor, snow or ice energy;
- temperature-dependent liquid-water properties;
- higher-order temporal advective-energy accuracy;
- a closed soil or land-column energy balance;
- canonical admission;
- parallel-backend or accelerator qualification.

## Next implementation gate

A subsequent production workunit may implement the frozen rule only if it proves at least:

1. exact sample-wise outward-positive Joule algebra for local outflow;
2. exact-zero transfer needs no donor temperature and yields zero energy;
3. every nonzero local outflow uses that sample's terminal local donor temperature, never the outer terminal temperature for earlier samples;
4. inward transfer without explicit external donor temperature makes the total energy result incomplete and is never replaced by local temperature or zero enthalpy;
5. mixed accepted sample sequences aggregate only when every nonzero sample is complete;
6. rejected route samples cannot enter energy evaluation;
7. reference-temperature shift identity is exact within floating-point qualification tolerance;
8. sample-wise aggregation differs from the forbidden aggregate-water-times-final-temperature shortcut in an adversarial varying-temperature case;
9. carrier-enabled energy evaluation introduces zero additional physical solves;
10. hydrologic candidate state, mass ledger, transaction status and restart state are unchanged;
11. cost is bounded by accepted carrier sample count;
12. `-O0` and `-O2` results are qualification-equivalent;
13. implementation remains outside F-KT persistent kernel state and passes the full 30-invariant architecture audit.
