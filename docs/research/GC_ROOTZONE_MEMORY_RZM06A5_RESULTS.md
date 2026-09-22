# GC-RZM06A5 redistribution-timing result

Date: 2026-09-22  
Preregistration: `503b943b72de6f5d3c5d447781cd4605b8334eb4`  
Implementation: `237d33d804915352901428cf94b0ea8340048071`  
Qualified workflow: `35732461595`, job `106761199051`  
Production changes: none

## Decision

RZM06A5 is qualified as:

`QUALIFIED_TIMING_MEMORY_NO_MATCH__H2_NOT_PROBED`.

All 16 frozen EARLY/LATE trajectory pairs completed transactionally. None met both unchanged H2 endpoint criteria, so E_c remained hidden.

## Main result

With no common final relaxation, moving the same top pulse from the beginning to the end of the history creates a deterministic retained state difference:

- `|ΔW_profile| ≈ 2.71e-6 ... 2.80e-6`;
- `|ΔM1| ≈ 1.39e-6 ... 1.43e-6`.

The signal is essentially saturated by `N=20`: increasing the pulse count to 50 or 100 does not materially enlarge it.

The largest observed `|ΔM1|` is about `1.42816e-6`, roughly 70 times below the frozen H2 requirement `1e-4`.

With 50 common zero-forcing intervals after both histories, both aggregate differences collapse to approximately `1e-14`. Thus the same relaxation that comfortably satisfies the profile-water matching criterion also erases the observable timing-memory signal for this construction.

## Scientific interpretation

The experiment demonstrates finite redistribution memory in the committed real-HeadCalc carrier, but not the H2 state pair required by the preregistration.

More forcing duration does not amplify the retained signal indefinitely. The current four-node fixture approaches a forcing-conditioned state quickly enough that the early/late separation plateaus.

This is useful negative evidence: simply increasing the number of already-admitted pulses is not a justified route toward the H2 threshold.

## Carrier scope

The serialized-reference route executes the real HeadCalc solver with an explicit B110 constitutive-hydraulics provider. On this qualified route, the simple fallback `watcon`, `hconduc` and `moiscap` stubs are bypassed for the normal `swkimpl=0` solve.

However, the carrier still uses the focused four-node FSI fixture geometry:

- `z = [-0.25, -0.75, -1.50, -2.50]`;
- `dz = [0.50, 0.50, 1.00, 1.00]`.

The aggregate diagnostic names retain historical `_cm` suffixes even though the root-zone diagnostic code explicitly treats this geometry as metre-scale. That semantic mismatch must be resolved before using the current M1 threshold as a strong physical falsification criterion.

## Next work unit

RZM06A6 will expose the committed node-level pressure-head and water-content profile through a research-only read-only diagnostic ABI. It will replay fixed A5 histories and determine whether:

1. the aggregate observables reconstruct exactly from the node profile;
2. M1 is hiding compensating vertical changes;
3. the observed memory is genuinely tiny at node level;
4. the four-node fixture has reached its useful scientific ceiling for H2.

RZM06A6 is diagnostic. It will not lower H2 thresholds or make a production-admission claim.
