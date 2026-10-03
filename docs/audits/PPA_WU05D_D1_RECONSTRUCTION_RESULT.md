# PPA-WU05-D1 source-materialization reconstruction result

Date: 2026-10-04  
Canonical base: `integration/f-ci-canonical@fae6d8d3d1687bfb220851f43603ab63d4989a29`  
Status: `EXACT_IDENTITY_CONFIRMED_BYTES_NOT_MATERIALIZED_D2_HELD`

## Reconcile

This is a continuation of existing work unit PPA-WU05-D, historically owned by branch `audit/ppa-wu05d-compensation-authority` and PR #363. No new competing work unit is created.

The current canonical head is `fae6d8d3d1687bfb220851f43603ab63d4989a29`. Since PR #363, bounded Bartholomeus oxygen has been canonically admitted. That admission preserves the existing drought/Feddes base sink and explicitly keeps compensation open.

## Exact identity

Canonical B0 and B1.11 authority both pin `SWAP/rootextraction.f90` to:

`8b7b2846618a8f82f3ed676c2c489d2d34be8c44b0a0d952f7f22ff09af78cd5`

with raw size 22013 bytes. No admitted B1 patch changes this member, so B1.11 rootextraction is byte-identical to B0 for this file.

The canonical B0 source archive remains identified by SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`. The repository verifier records 63/63 member verification.

## Materialization routes investigated

D1 did not stop at the historical PR #363 blocker. The following routes were checked:

1. canonical `reference/swap-4.3.1` manifests, snapshots and reconstruction tooling;
2. historical B0 integrity commits and the B1.11 deterministic reconstruction path;
3. the public `SWAP-model/SWAP` source history;
4. Project/Library search for the original distribution, exact member hash and source-bearing archives;
5. historical source-materialization/evidence archives in the user's SWAP 4.3.1 audit Library.

The public `SWAP-model/SWAP` repository contains the same compensation implementation family and exposes the full Jarvis/Walsum block, but its retrieved rootextraction member is not the pinned 22013-byte B1.11 member and is therefore corroboration only.

Library inventory exposes source-bearing historical archives, including `M3_I1R_SOURCE_MATERIALIZATION.zip` and `M3_I1S_TRANSACTION_SOURCE_COMPLETION.zip`. Raw-byte materialization was attempted and rejected by the file surface as unauthorized. Consequently their contents cannot be hashed against the pinned member in this execution context.

## Corroborated compensation algebra

The later source family strongly corroborates this shape, but the equations below are NOT promoted to B1.11 oracle status until the exact 22013-byte member is materialized.

After nodewise oxygen, drought, salinity and frost reductions:

- `qpotrot(node)` receives the pre-stress potential node sink;
- `qrot(node)` is multiplied by `alpwet * alpdry * alpsol * alpfrs`;
- `qrosum` is the resulting root-zone sum;
- total stress loss is apportioned diagnostically across wet/dry/salt/frost totals.

Compensation then computes `alptot = qrosum/ptra` and `qred = ptra-qrosum`. It is guarded by nontrivial compensation capacity, positive reduction and `alptot >= 0.05`.

The corroborating Jarvis/Walsum family reconstructs aggregate stress factors using exponent shares of total reduction:

`alpdry = alptot**(qreddrysum/qred)`, analogously for wetness, salinity and frost.

For selected-stressor mode, only the selected factor is divided by `alphacrit` and capped at one; the compensated total factor is then the product of the four compensated factors. For all-stressor mode the total factor itself is divided by `alphacrit` and capped at one.

Candidate node sinks are rescaled once by `alptotcom/alptot`; `qrosum` and stress-attribution totals are recomputed afterward. This is consistent with one water-mass owner and a pure candidate transformation.

The Walsum selector additionally corroborates a trial-local geometry update:

`alphacrit = min((dcritrtz + rdm - rd_noddrz)/rdm, 1)`

where `rd_noddrz = abs(zbotcp(noddrz))` in the same source family.

## State census

No persistent compensation continuation variable is visible in the corroborating block. Its temporaries are current-call algebra and it mutates current root-uptake result/diagnostic fields. However, because the exact B1.11 member bytes are still unavailable, PPA-WU05-D1 does NOT upgrade this to an exact historical claim.

Current classification:

- physical state owned by compensation: none demonstrated;
- transaction state: candidate `qrot`, `qrosum` and stress-result scratch before outer acceptance;
- diagnostics/results: stress-attribution totals and node diagnostics;
- recomputable scratch: aggregate alpha factors and compensation scaling;
- persistent/restart state: `NOT_PROVEN_EXACTLY; CORROBORATED_NONE`.

## Retry and mass ownership

The existing SWAP5 nodewise root-water sink remains the only accepted water-mass owner. Compensation must transform a fresh pre-compensation candidate before that single receipt.

Rejected compensated candidates are disposable. A retry must rebuild the uncompensated candidate from committed state and apply compensation once. It may not rescale a rejected already-compensated vector.

## Multi-stressor and MICRO boundary

The source family corroborates multiplicative composition of wetness/oxygen, drought, salinity and frost before compensation and explicit selected-stressor controls. This knowledge is persisted but is not sufficient to admit unavailable salinity or frost production routes.

The compensation block occurs after the drought selector, including the microscopic/Jong-van-Lier path in the corroborating family. D5 remains separate because exact B1.11 applicability and MICRO state ownership are not closed here.

## D1 verdict

D1 is materially advanced but not closed:

`EXACT_MEMBER_IDENTITY_AND_FORMULA_FAMILY_RECONSTRUCTED__EXACT_BYTES_STILL_UNAVAILABLE`

D2 and D3 remain held. Implementing Jarvis or Walsum now would violate the preregistered fail-closed rule because exact B1.11 equations/order/state have not been byte-authorized.
