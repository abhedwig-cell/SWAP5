# EB-I11 Production Water-Thermal Provenance Readiness

## Decision

Current canonical is **not yet ready for production bottom advective-energy accounting**, despite having the necessary transaction identity, accepted bottom-water exchange and terminal thermal state separately.

The blocking issue is not lack of a final bottom temperature. The blocking issue is loss of the temperature history associated with each accepted internal bottom-water transfer when an outer `[t0,t1]` interval is completed through more than one accepted transaction/substep.

No production source is changed by EB-I11.

## Current-canonical execution sequence

The relevant restricted thermal path is in `mod_fmr_serialized_reference_backend`.

Within `fmr_serialized_advance`:

1. the Richards solver advances the hydraulic trial;
2. a start hydraulic view and end hydraulic view are available;
3. restricted soil temperature is advanced over that same model trial interval;
4. the soil-temperature trial state is committed into the still-local physical trial state;
5. the hydraulic candidate state is copied into that same local physical trial state;
6. bottom exchange is written to the `trial_outcome_t` as `-bottom_flux * step_duration`;
7. only after the model returns does F-KT materialize the opaque `kernel_candidate_state_t` and assign lineage, origin revision and `[t0,t1]` provenance.

This ordering is transactionally sound. A failed thermal trial prevents `solver_ok` publication and therefore does not produce an accepted transaction.

## Candidate snapshot seam

A ready `kernel_candidate_state_t` supports `snapshot()`. The snapshot is a clone of the complete candidate physical state and does not expose mutation of private candidate provenance.

For the restricted soil-temperature layout that candidate physical state contains an optional `soil_temperature_state_t`. The existing `build_soil_temperature_field_view()` operation can materialize a typed temperature view from it.

Therefore a future runtime composition can obtain terminal trial temperature from the candidate without adding temperature to the hydraulic process view and without opening HeadCalc internals.

## Accepted bottom-water seam

Current canonical already treats bottom exchange as an accepted transaction quantity.

At the model-trial level, `trial_outcome_t` receives a bottom outward exchange for the model interval. The transaction layer publishes the accepted value only for the selected accepted route. `run_canonical_interval()` then accumulates bottom exchange only from `TX_STATUS_ACCEPTED` transactions.

The aggregate is exposed through `canonical_result_t` and then `kernel_result_t` only if the full requested outer interval completes. The accepted water accounting also preserves `accepted_transaction_count`.

This is a strong mass/provenance foundation and should be reused rather than replaced.

## Why terminal temperature times aggregate mass is wrong

Suppose an outer interval is accepted through substeps `k = 1..N` and the accepted bottom water transfers are `m_k` with donor-water specific enthalpies `h_k`.

The physically required accepted advective-energy contribution is

`E_adv,bottom = sum_k m_k * h_k`

with sign/orientation handled by the qualified water-transfer convention and with donor selection based on transfer direction.

Current canonical can provide

`M_bottom = sum_k m_k`

and the terminal candidate can provide one final bottom-node temperature `T_end`.

In general,

`sum_k m_k * h(T_k) != (sum_k m_k) * h(T_end)`.

Equality occurs only in restricted cases, for example when all relevant donor temperatures are identical, or when `N = 1` and the chosen donor-temperature evaluation is the qualified one for that transfer.

Therefore the shortcut

`aggregate bottom exchange * terminal bottom-node enthalpy`

is forbidden as a general production path.

## Consequence for transaction design

The thermal contribution must be accumulated before the canonical runtime discards accepted-substep thermal history.

The safe sequence is:

1. each physical trial computes hydraulic and thermal candidate states as today;
2. for each candidate accepted by the transaction selector, materialize the bottom-water transfer and its donor thermal value from that same accepted trial identity;
3. accumulate the advective-energy contribution into outer-interval trial/result metadata;
4. rejected full/half/retry trials contribute nothing to the aggregate;
5. the completed outer F-KT candidate receives opaque lineage/revision/interval identity as today;
6. no energy contribution becomes committed/public until the existing outer accepted-commit receipt authorizes that exact candidate.

This preserves both levels of transaction semantics: internal accepted substeps and outer committed candidate publication.

## Direction-dependent donor rule

The bottom boundary is bidirectional.

For downward/outward water from SWAP, the donor is local SWAP water and the thermal value must come from the appropriate bottom soil-water thermal state for that accepted transfer.

For upward/inward water into SWAP, the donor is external groundwater/deep-vadose water. A local SWAP bottom temperature must not be substituted. That path requires an explicit external donor-water temperature contract.

Consequently EB-I11 does not collapse EB-I08 and EB-I09 into one rule.

## Dependency decision

EB-I04, EB-I08, EB-I09 and EB-I10 are currently owner-side capabilities rather than current-canonical authorities. EB-I11 therefore does not copy their formulas or production code into current canonical.

Doing so would create competing implementations and undermine one-kernel/shared-physics governance.

The next production capability should be composed only after the required dependencies are independently qualified/admitted or deliberately recomposed together under a separate integration workunit.

## Recommended next production capability

The next implementation target is an **accepted bottom advective-energy quadrature carrier** with these properties:

- input at accepted-substep granularity, before accepted thermal history is lost;
- donor-correct for both directions;
- no mass rebooking;
- no extra Richards solve;
- no persistent per-column history beyond what is required to continue physical state;
- trial-local accumulation with exact rollback/discard semantics;
- outer-candidate provenance attached through the existing F-KT identity;
- final publication only after the existing accepted commit receipt;
- explicit completeness flag and failure diagnostics;
- generic `[t0,t1]`, no day boundary.

## Hard nonclaims

EB-I11 does not qualify:

- production advective-energy calculation;
- an enthalpy law;
- external groundwater temperature;
- bottom donor-node physics;
- vapor latent-energy transport;
- snow/ice phase energy;
- full energy closure;
- MultiSWAP throughput of the future energy path;
- independent qualification;
- canonical admission.
