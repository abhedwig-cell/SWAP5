# TAB-HYD current research status

Date: 2026-09-23

Status: **K0 RESEARCH CLOSED / SCALE40 AND DYNAMIC PASS / PRODUCTION F0 PASS / F APPLICATION GATE OPEN**

This file is the current navigation authority for the TAB-HYD research branch. Older long-form status and experiment records remain evidence for their recorded phase but do not override this summary. This is research-side reconciliation, not a change to production qualification authority.

## Canonical and ownership

Canonical observed at latest live reconciliation:

`integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`

Research branch:

`research/tabulated-hydraulics-characterization`

Production implementation is separately owned on:

`work/f-tab02-generated-k0-provider`

Latest observed production head:

`52a455d45fabc6499ad54b89b7e930b02b66ff51`

The production qualification record retains its own canonical/source authority. Observing a newer canonical head is not requalification or admission. Do not implement production changes from this research branch.

## K0 research conclusion

The generated typed K0 acceleration hypothesis is supported within the tested envelope.

Qualified research representation:

- generated from the admitted default MvG parameter authority;
- 400 rows;
- raw pressure head as interpolation coordinate;
- log(K) ordinate;
- TSPACK preprocessing;
- explicit wet theta/C continuation;
- explicit Ksat plateau;
- bounds-safe lookup;
- immutable preprocessing outside the solve hot loop.

Research evidence establishes bounded constitutive fidelity, five-profile K0 transfer fidelity, typed-provider acceleration, Reference-Richards compatibility, transaction/mass compatibility in bounded fixtures, temporal-certificate compatibility, timestep-context capability and bounded F-SI39/KSATEXM research handoff.

Controlling closeout:

`RESEARCH_CLOSEOUT_20260923.md`

## Typed acceleration evidence

The legacy scalar-wrapper parity result was not the appropriate architecture-level performance measure for the new typed provider.

Four-node Reference-Richards integration run `35879637410` passed all five bounded cases, with equal nonlinear/linear-solve counts, mass differences around machine precision and repeated-solve runtime reductions of approximately 28–39% in its small constitutive-heavy fixture.

### Supplemental 40-node scale gate

Preregistration: `TYPED_REFERENCE_RICHARDS_SCALE40_PREREGISTRATION.md`.

Result: `TYPED_REFERENCE_RICHARDS_SCALE40_RESULT.md`.

Controlling run `35883123788` and independent execution-equivalent repeat `35883189377` both passed all five hydraulic scenarios. Controlling-run maximum head differences were `3.24e-7` to `1.38e-5 cm`, mass-residual differences were of order `1e-15 cm`, and nonlinear iteration counts matched route by route. Runtime reductions were approximately 30–33%; the independent repeat reproduced scientific values and the reduction sign, with approximately 34–39% reductions.

Classification: **SCALE_PASS / K0 RESEARCH SCALE QUESTION CLOSED**.

### Supplemental dynamic trajectory gate

Preregistration: `TYPED_REFERENCE_RICHARDS_DYNAMIC_PREREGISTRATION.md`.

Result: `TYPED_REFERENCE_RICHARDS_DYNAMIC_RESULT.md`.

Successful run `35900988596` tested four materials (B4, B9, B12, O13), four nodes and a predeclared 16-step non-equilibrium trajectory. Eight balanced timing rounds reported approximately 30–31% runtime reductions. Maximum head difference across materials was approximately `7.01e-6 cm`; total nonlinear and linear-solve counts matched route by route.

The executed logs were checked in the application-gate reconciliation below. Equal work counts are not proof of identical internal numerical paths. This research-only provider is not the separate F-TAB02 production implementation.

**All research timing percentages remain fixture-specific characterization, not portable whole-SWAP or production speed claims.**

## Production handoff live state

Historical/live handoff narrative:

`LIVE_HANDOFF_STATUS_20260923.md`

Latest bounded source/evidence reconciliation:

`APPLICATION_GATE_RECONCILIATION_20260923.md`

Machine-readable local integrity checks:

`APPLICATION_GATE_RECONCILIATION_CHECKS_20260923.json`

At observed production head `52a455d45fabc6499ad54b89b7e930b02b66ff51`:

- A–E and G are qualified, including the earlier same-postimage A→E→G preservation;
- F0 standalone provider-selection/lifetime is PASS under owner run `35884404981`;
- F exact M1-C3 whole-Hupsel is `READY_TO_EXECUTE`, not PASS;
- analytical default and explicit standalone opt-in remain the qualified selection contract;
- no canonical production admission follows from these records while F remains unqualified.

The historical external blocker about unavailable exact SWAP 4.3.1 archive bytes is obsolete: production records report the exact authorized archive materialized and verified.

Production performance has independently reproduced the acceleration sign. The two E qualification executions report bounded serialized-runtime reductions of approximately 4.72–9.18%, not whole-Hupsel application timing.

### Latest verification boundary

Inspected run `35901906716` completed its A/B/C/D/E/G jobs successfully. The corresponding workflow does not execute the full F application gate. The successful source-snapshot workflow `35902072731` packages source only. Neither run demonstrates generated-provider whole-Hupsel equivalence.

The downloaded source snapshot matched its GitHub archive digest and all 264 non-manifest payload hashes. Its sole manifest mismatch is a self-entry for `SHA256SUMS.txt`, caused by including the output manifest in its own input file list. A packaging-only exclusion was tested on a separate local copy: 264/264 checks passed with every payload file unchanged. No production workflow or source was edited.

This is a packaging defect, not a constitutive-representation failure. Exact external-asset verification and a fresh generated-versus-analytical whole-Hupsel execution remain production-owned requirements.

## K1 disposition

K1 is separate and does not block K0.

Controlling diagnostic: `K1_ROUTE_CENSUS_RESULT.md`, run `35879745205`.

- coarse_dry_free and coarse_dry_pulse: analytical/raw/raw+capacity all complete;
- loam_mid_free, clay_wet_free and loam_capillary: all three routes exceed 120 s.

Classification: **K1_REFERENCE_ENVELOPE_RUNTIME_BLOCKED / NOT_TABLE_FALSIFIED / OUTSIDE K0 HANDOFF**.

Do not infer broad K1 fidelity or production readiness.

## Generic legacy tables

Historical `SWSOPHY=1` machinery is not the current production target.

Research established that historical interpolation can be accurate, the old scalar lookup route has avoidable overhead, table-endpoint derivative semantics contain a real historical defect, and one public BOFEK/Staring table is incompatible with the current monotonicity contract. Current typed production does not admit generic user-supplied tables.

Generic external tabulated hydraulics remains a separate future capability.

## Next safe action

No further K0 representation tuning is justified by the current evidence.

The next controlling application step is the **production-owned exact M1-C3 whole-Hupsel F gate**, retaining its existing asset, completion, accepted-interval, retry, route, mass and output-comparison contract. Historical M1 closeout records are not a substitute for executing the generated candidate. See the application-gate reconciliation for the precise remaining conditions and the tested packaging-only correction.

Research remains closed unless production exposes a concrete new scientific discrepancy or dependency within TAB-HYD research ownership. A packaging issue alone does not justify reopening interpolation, changing tolerances or duplicating production implementation.
