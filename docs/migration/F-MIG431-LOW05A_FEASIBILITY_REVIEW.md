# F-MIG431-LOW05-A reconcile and feasibility review

Date: 2026-10-01
Status: SHARED_AUTHORITY_PREREQUISITE_REQUIRED
Pinned canonical: `44c6df02a58edee79f88dde8ca8aadbec26337fc`
Production admission: NONE
Implementation branch: NOT_ISSUED

## Decision

SWBOTB=5 remains the preferred next physical migration seam. Its existing prescribed-lower-face-pressure-head physics can be reused. However, an ordinary application adapter is not presently independent of shared application ownership and trial timing. Register F-MIG431-LOW05-P0 before issuing LOW05-A for production implementation. This is a bounded shared-contract prerequisite, not a finding that the prescribed-head physics is defective.

LOW01-A remains canonically admitted and closed through PR #972. Modes 1, 3, 5 ordinary application and 8 remain open. Modes -2 and 9 are not promoted to ordinary application selectors.

## Exact scientific source recovered

The already uploaded SWAP_4.3.1.zip contains nested tools/SWAP/source/SWAP.ZIP. The outer upload SHA-256 is `76a79498423ee612a7861efb564b10c4360a4f648396eefcf8e9011919a66039`; it is not claimed to equal the historically pinned official distribution archive.

Eight complete relevant members were recovered. Seven match B1.11 directly. The extracted readswap member becomes byte-exact B1.11 after application of the canonical SWAP-013 seven-line PDI guard. The resulting readswap SHA-256 is `e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c`.

All eight complete hashes were compared with `docs/performance/evidence/F-PE19_B1_11_source_manifest.sha256`. Lossless gzip/base64 bytes, byte counts and hashes are persisted in `integration/audits/F-MIG431_LOWER_BOUNDARY_B111_SOURCE.json`. Recovery requires decoding each member and checking its SHA-256. This carrier materializes only the eight relevant members, not the complete 63-member reference distribution.

Recovered members: boundbottom.f90, functions.f90, headcalc.f90, fluxes.f90, soilwater.f90, swap.f90, timecontrol.f90, readswap.f90.

## Input, table and datum semantics

B1.11 readswap reads DATE5 through rdatim and HBOT5 through rdfdor with domain [-1.0e10, 1000] cm. Dates and head entries share the parser count; the adapter must reject missing/mismatched arrays.

The exact checkdate routine accepts a table when at least one date lies within the simulation period, with its 1e-6 day comparison margins, OR when the simulation period is enclosed by the first and last table dates. A blanket requirement that every simulation endpoint have a table entry would be stricter than this source. General raw calendar-string parsing remains outside the bounded typed adapter. The selected epoch/origin must explicitly map canonical elapsed days to legacy t1900.

AFGEN is piecewise linear. It clamps at the first endpoint and at the final populated endpoint. The legacy fixed-size arrays are zero-initialized; AFGEN recognizes the end of a partly populated table through a decreasing abscissa. The typed route should use the actual populated count, and reject empty, mismatched, non-finite, duplicate or non-increasing date arrays. Single-point endpoint clamping is mathematically supported, subject to checkdate coverage. These structural checks are typed fail-closed requirements, not claims that checkdate alone enforced ordering.

HBOT5 is pressure head at the lower face in cm. It is neither groundwater elevation relative to soil surface nor absolute hydraulic head, and it must not be imposed as h(NN)=HBOT5. The admitted Darcy gradient is (h(NN)-hbot)/distance+1. Native qbot is positive into the soil profile. Lower-face conductivity and the K/d Jacobian remain the existing scientific owner's responsibility.

The groundwater adapter instead receives hydraulic head in metres and applies pressure_head_cm = 100*(interface_head_m-bottom_face_elevation_m). Ordinary HBOT5 must not pass through that conversion or acquire a MODFLOW datum, registry or groundwater interface ledger.

## Exact trial and retry staging

B1.11 BoundBottom resolves hbot = AFGEN(hbotab, 2*mabbc, t1900+dt), and resolves lower-face retention/conductivity from that hbot before the physical solve.

Crucially, swap.f90 calls BoundBottom BEFORE do while(fldtreduce). Inside that loop a rejected Richards solve restores soil state and invokes TimeControl(5), which reduces dt. There is no BoundBottom re-entry inside the retry loop. Therefore HBOT5 is sampled at the original proposed step endpoint and held across the legacy reduced-dt retries.

This is not equivalent to evaluating DATE5 at each retry endpoint. The independent arithmetic illustration with dates [0,1] and heads [-100,100] gives hbot=100 cm for an original dt=1 day. A retry shortened to 0.25 day still uses 100 cm in the source loop; endpoint recomputation gives -50 cm. The 150 cm discrepancy falsifies a naive per-retry endpoint adapter. This is source/feasibility evidence, not a hydrologic production run.

Neither may the adapter evaluate once at the endpoint of an arbitrary outer canonical interval containing several accepted physical transactions. A shared contract must identify the original proposal, sibling full/two-half candidates, reduced-dt retries and the next accepted physical transaction.

The existing admitted SWBOTB2 temporal control evaluates its table per backend substep endpoint. That is evidence about that admitted route, not authority to silently copy its retry staging to LOW05-A. This review does not reopen or modify SWBOTB2.

## Current implementation feasibility

The serialized Reference backend already accepts typed bottom_mode=5 and copies forcing%bottom_head to the solver request. It has immutable application controls for SWBOTB2 and SWBOTB4, but no DATE5/HBOT5 control.

The production bootstrap currently infers groundwater_profile from bottom_mode==5 for every tile. tile_config_valid then requires a positive groundwater ledger and valid groundwater datum. Initialization allocates groundwater materializers, ledgers and a participant registry. Thus the ordinary mode-5 application cannot be admitted by simply providing bottom_head to this bootstrap: it would acquire the coupling owner.

Changing that selection requires an explicit application-level ownership contract. The older PROJECT-CONTROL record discusses a historical CSR candidate, but its existence is not admission authority for a current repair. The live bootstrap and fixed-interface materialization restrictions govern this review.

## Shared prerequisite F-MIG431-LOW05-P0

Central owner: F-MIG431 lower-boundary regie.
Scope: freeze ordinary-prescribed-head versus groundwater-owned application discrimination, and source-bound proposal/retry sampling, before LOW05-A production implementation.

Required decisions:
1. An explicit ordinary-HBOT5 application designation that does not infer groundwater ownership from solver mode 5. Preserve the admitted groundwater defaults and fail closed on ambiguous or combined ownership.
2. Identify where the original proposed endpoint and immutable resolved head live during full/two-half assessment and retries. Prefer existing attempt-context mechanisms; no hidden persistent state or transaction-core policy changes.
3. Define when a new accepted physical origin creates a new head sample. Accepted-boundary restart must reconstruct immutable table/origin configuration and sample consistently; it must not serialize rejected trial scratch.
4. Freeze table validity, time-origin mapping and invalid-control behavior. Retain source head domains and endpoint semantics.
5. If exact legacy retry staging is deliberately changed, route that as an explicit reference-policy decision with separate evidence. It must not be described as exact legacy preservation.

Held fixed: generic Richards request/result ABI, bottom-mode physical meaning, qbot sign, accepted mass owner, committed-state schema, retry/commit policy, MODFLOW datum and predictor/corrector semantics, existing groundwater topology/storage/drainage ownership, root uptake, macropores, oxygen and general SWP/BBC parsing.

No production implementation branch is issued until P0 resolves these contracts. No sibling/repair/admission branch is created by this review.

## Qualification and preservation required after P0

LOW05-A preregistration must require an independent exact-source AFGEN/table oracle; original-proposal versus reduced-dt retry discrimination; full/two-half sampling; accepted-boundary uninterrupted/restarted equality; failure/rejection immutability; A/B/A determinism; O0/O2 identity; arbitrary elapsed-time origin; positive/negative/zero accepted bottom exchange; and complete unrounded accepted mass closure.

The existing accepted Richards/watstor/flux publication path remains the only bottom-mass owner. The provider prescribes head, not qbot. Rejected exchange contributes no accepted ledger entry.

Preservation must cover admitted modes 2, 4, 6 and 7 plus the groundwater-owned mode-5 fixed-interface route. Production changes to shared bootstrap/backend require owner-specific focused preservation, not unrelated green CI.

Affected invariants: 2, 3, 4, 7, 8, 9, 12, 13, 22, 23, 25, 28, 29, 30.

## Evidence and next action

Source hash recovery, lossless carrier roundtrip, call-order assertions and interpolation/retry arithmetic illustration passed locally. No Fortran production build, production numerical qualification, documentation build or GitHub Actions qualification was run. No production source changed.

Result: `integration/audits/F-MIG431-LOW05A_FEASIBILITY_RESULT.json`.
Recovery/status: `integration/audits/F-MIG431-LOW05A_STATUS.json`.
Prerequisite: `integration/audits/F-MIG431-LOW05P0_PREREQUISITE.json`.

Next safe action is central LOW05-P0 contract resolution, then issuance of ONE official LOW05-A implementation branch and preregistration. The preferred subsequent physical order remains SWBOTB=1, then 3, then 8; this review supplies no evidence to change it.
