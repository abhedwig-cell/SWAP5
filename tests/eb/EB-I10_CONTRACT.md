# EB-I10 Accepted Water-Thermal Provenance Binding Contract

## Authority

Restart authority: `integration/f-ci-canonical@2a0db2524fba6e258316ce82630c60ea1c9c673a`.

Pinned canonical dependencies:

- `src/transaction/mod_transaction_reference.f90@834487df4e7a38c7c8ffd83805d98933714c6977`
- `src/runtime/mod_canonical_contracts.f90@3cbb81b25626e6574ae83416f088dc52882f91fc`
- `src/runtime/mod_canonical_interval_runtime.f90@f41f725df4be883d277a8fd5afe5a6f1bc14ad1b`
- `src/kernel/mod_kernel_transactions.f90@c7c5b7d3357e4e6739c8f647d6232baca45563e6`
- `src/runtime/mod_fmr_accepted_commit_receipt.f90@6798b3296b426950bf028814585c3f5de9be950b`

## Purpose

EB-I10 provides a narrow runtime provenance primitive for a later energy composition. It answers two questions only:

1. did a water-transfer provenance token and a thermal-field provenance token originate from the same F-KT trial identity;
2. has that exact bound trial identity subsequently been accepted by the existing canonical commit authority.

It does not calculate water mass, temperature, enthalpy or energy.

## Non-forgeable source authority

Water and thermal trial-provenance tokens can only be captured from a ready `kernel_candidate_state_t`. The candidate owns opaque F-KT provenance. EB-I10 has no public scalar constructor for lineage, revision or interval identity.

The capture operation copies only:

- `lineage_id`;
- `origin_revision`;
- `t0`;
- `t1`.

No physical state, mass payload, temperature payload, solver scratch or energy value is copied.

## Trial binding rule

`bind_water_thermal_trial_provenance` succeeds only when both tokens are ready and all of the following match:

- lineage id exactly;
- origin revision exactly;
- interval start under the canonical F-KT numeric time-identity rule;
- interval end under the same rule.

The numeric time identity is deliberately the existing F-KT/F-MR18 rule:

`abs(a-b) <= 64 * epsilon(real64) * max(1,abs(a),abs(b))`.

This is a floating-point identity rule, not a scheduling tolerance and not a calendar assumption.

## Accepted authorization rule

A ready trial binding is not accepted provenance.

`authorize_accepted_water_thermal_provenance` additionally requires a ready canonical `fmr_accepted_commit_receipt_t` whose:

- lineage id matches the binding;
- origin revision matches the binding;
- origin interval matches the binding under the canonical time-identity rule;
- committed revision equals origin revision plus one.

The receipt is produced by the already-admitted F-MR18 path only after canonical F-KT commit succeeds. EB-I10 does not call commit, mutate committed state, create revisions or create an alternative receipt.

## Failure semantics

Failures are fail-closed. Output tokens are reset to their default non-ready state before validation.

Qualified status classes are:

- invalid water provenance;
- invalid thermal provenance;
- lineage mismatch;
- revision mismatch;
- interval mismatch;
- invalid binding;
- receipt not accepted;
- accepted receipt mismatch.

A binding without a ready receipt can never become accepted provenance.

## Data ownership

EB-I10 owns only short-lived provenance/result metadata. It owns no physical water state, thermal state or persistent column state.

The water-transfer amount remains owned by the authoritative water process/accounting path. The temperature field remains owned by the thermal component. Future energy calculation must consume those payloads through their own contracts after provenance has been established.

## Transaction boundary

EB-I10 reuses canonical F-KT candidate provenance and F-MR18 accepted commit receipts. It deliberately creates no second transaction protocol.

Rejected, stale or uncommitted trials cannot obtain an accepted EB-I10 provenance token because no matching ready accepted receipt exists.

## Runtime composition boundary

EB-I10 qualifies the identity-token lifecycle only. It does not yet prove that every production water-transfer callsite captures the water token at the same point that the authoritative transfer payload is materialized, nor that every production thermal-view callsite captures the thermal token at thermal-view materialization.

That production callsite binding must be qualified separately before accepted advective-energy accounting can rely on these tokens.

## Hard nonclaims

EB-I10 does not qualify:

- a water-transfer amount or route contract;
- a temperature-field payload contract;
- donor-node selection;
- external donor-water temperature;
- liquid-water sensible enthalpy calculation;
- Joule accounting or an energy ledger;
- snow, ice, vapor or latent phase-change energy;
- route-specific drainage, root, runoff, macropore or groundwater thermal physics;
- production callsite provenance publication;
- committed energy-ledger publication;
- full MultiSWAP throughput or memory scaling;
- a closed energy balance;
- independent qualification;
- canonical admission.

## Owner qualification evidence

Technical gate authority:

- workflow run `34742605421`;
- job `103684744065`;
- GNU Fortran O0 and O2 both pass;
- O0/O2 evidence output is identical;
- tests use real opaque F-KT candidates and a real canonical accepted commit receipt.
