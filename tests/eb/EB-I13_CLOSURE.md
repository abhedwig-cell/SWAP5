# EB-I13 Accepted Bottom Water-Thermal Substep Carrier Implementation Closure

## Decision

`QUALIFIED_IMPLEMENTATION_BRANCH_CLOSED_PENDING_CANONICAL_ADMISSION`

EB-I13 implements and qualifies the narrow carrier contract frozen by EB-I12. It does not calculate advective energy, choose a donor-temperature quadrature, define external groundwater temperature, close the total energy balance, or admit this branch to current canonical.

The authoritative closure condition is a successful `EB-I13 bottom thermal carrier qualification` workflow on the exact branch HEAD containing this document. A green run on an older commit is supporting evidence only and does not close a newer HEAD.

## Scope implemented

The production delta is intentionally narrow:

- `src/runtime/mod_fmr_bottom_thermal_carrier.f90` provides a bounded accepted-route sample carrier and candidate-scoped snapshot;
- `src/runtime/mod_fmr_serialized_reference_backend.f90` binds that carrier to worker-local transaction attempt context and to the restricted soil-temperature route;
- no carrier state is added to `kernel_committed_state_t` or other persistent F-KT column state;
- no extra physical solve is performed to reconstruct rejected or discarded thermal history;
- public carrier materialization occurs only for a fully completed outer candidate.

## EB-I12 implementation gates

All ten EB-I12 implementation gates now have executable or structural qualification evidence.

1. **Full trial replaced by selected two-half route:** PASS. The carrier test proves that accepted two-half routes contain only the selected half-route samples.
2. **Rejected attempt leaves no sample residue:** PASS. The retry fixture appends before deliberate rejection and proves rejected-route samples disappear.
3. **Retry restores the exact checkpoint carrier state:** PASS. The retry qualification checks the exact accepted prefix and route intervals after rollback/retry.
4. **Outer failure after earlier accepted internal progress publishes no full carrier:** PASS. The canonical outer-route fixture accepts one internal transaction, then forces `CANONICAL_STATUS_SUBSTEP_LIMIT`; full requested-interval materialization fails. The production backend separately gates materialization on `result%completed .and. candidate%ready()`.
5. **Accepted multi-substep outer candidate preserves the exact ordered sequence:** PASS. The canonical outer-route fixture requires exactly two accepted internal transactions and four ordered selected-route half samples covering `[0,1]`.
6. **Exact zero transfer needs no donor temperature:** PASS. The primitive carrier test records a zero-transfer sample with donor class `NONE` and complete provenance.
7. **Outward transfer uses same-advance local bottom thermal endpoints:** PASS. The serialized backend qualification checks the committed bottom start temperature, finite end temperature and continuity between accepted samples.
8. **Inward transfer without explicit external thermal provenance is incomplete:** PASS. The primitive contract test requires donor class `EXTERNAL` and `donor_thermal_complete = .false.`; no local-temperature substitution is permitted.
9. **Carrier collection adds no production physical solve:** PASS. Carrier-enabled and carrier-disabled serialized runs have exact solver diagnostic parity, including HeadCalc calls, Jacobian builds, linear solves, retries and alternative-solver calls.
10. **Committed physical state, water accounting and candidate semantics remain unchanged:** PASS. Enabled/disabled qualification checks bit-level hydrologic ledger parity and candidate physical-state parity. Existing FPM08D7 compile, transaction-owner and restart-owner gates are rerun by the EB-I13 workflow.

## Additional qualification

The gate compiles and executes at both `-O0` and `-O2`, requires exact output identity, records SHA-256 output hashes, and can emit a tested-head plus production-blob evidence bundle. Static checks also fail if the carrier leaks into `mod_kernel_transactions`.

`tests/eb/EB-I13_ARCHITECTURE_AUDIT.json` assesses the implementation against all thirty SWAP architecture invariants. The carrier remains worker-local bounded scratch/result provenance, uses generic time, does not duplicate the water ledger, and introduces no MODFLOW, tile, deep-vadose, file-format or calendar assumptions.

## Scientific and architectural nonclaims

EB-I13 does **not** qualify:

- a Joule-valued bottom advective-energy term;
- local donor-temperature temporal interpolation or quadrature;
- external groundwater or deep-vadose donor temperature;
- temperature-dependent liquid-water properties;
- internal soil-face advective heat transport;
- drainage, root, irrigation, precipitation, evaporation, snowmelt or vapor energy terms;
- correction of the restricted soil-temperature storage law;
- a closed soil or land-column energy balance;
- canonical admission;
- parallel-backend or accelerator performance.

The carrier's signed water amount is provenance for an already authoritative accepted water transfer. It is never a second mass booking.

## Disposition

There is no remaining EB-I13 implementation blocker within the frozen EB-I12 carrier scope once the closure HEAD workflow is green. The next energy workunit may therefore consume this carrier as qualified input, but it must independently qualify every new energy law and must retain the hard nonclaims above until those gaps are explicitly closed.
