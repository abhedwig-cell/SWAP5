# VQ-1b B0 runner and balance evidence

## Integration record

```text
WORKSTREAM: VQ
SLICE: VQ-1b
ORIGINAL BRANCH BASELINE: 40aef01c5c89dc9e02bba50d31c884dcdd2fd2d5
MAIN RE-READ DURING HARDENING: f369e68a06e97780e7879a33937b41539a81c557
LATEST MAIN RE-READ: 5c549e950df98d0cf0c0ef22ac1b682ec2d3bef1
SCOPE: reproducible B0 execution bootstrap, official-case hardening, canonical legacy balance extraction and B2 mass-accounting verification contract
PRODUCTION CODE CHANGED: no
INTERFACES CHANGED: no
INVARIANTS: 7, 9, 10, 11, 12, 13, 17, 18, 19, 23, 24, 25, 26, 28, 29, 30
```

VQ-1b remains verification infrastructure. It does not change SWAP physics, numerical policy, state ownership or production interfaces.

The VQ branch predates substantial parallel changes on `main`. Current `main` has been re-read repeatedly during this slice. The branch must be integrated deliberately before merge; its older branch base is not treated as the current project baseline.

## B0 identity

The supplied archive used for this slice passed the VQ-1a identity gate:

```text
size:   8,959,314 bytes
sha256: 2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360
```

The exact source archive and packaged executables remain governed by the repository reference manifest.

## Native B0 executable status

The packaged Linux executable remains the preferred native B0 execution oracle, but it cannot run in the current VQ environment because Intel runtime library `libimf.so` is absent. No Windows compatibility runtime is available for the packaged Windows executable.

This is an environment dependency, not a model discrepancy. No numerical evidence is accepted from a failed native launch.

## Provisional exact-source GNU runner

`tools/vq/b0_source_runner.py` builds TTUTIL and SWAP from the exact source archives contained in B0 and applies only the standalone-Linux Intel `!DEC$` branch selections.

Tested compiler and provisional executable identity:

```text
GNU Fortran (Debian 14.2.0-19) 14.2.0
sha256: 5eca528a3635f82713abaa360701010868834397dcdff65d57c4385bb62784d5
```

The GNU build is **not** declared equivalent to the packaged Intel executable. VQ admits only specifically cross-checked outputs from it.

## GNU vector-CSV capability boundary

Hardening localized the earlier Hupselbrook `S_CONC` stop to the provisional GNU runner rather than to a confirmed B0 defect.

A diagnostic-only build showed that scalar CSV metadata initialize correctly while legacy vector metadata do not:

```text
vars_s%name(1)  = RAIN
vars_s%name(40) = BALDEV
vars_v%name(1)  = NUL-filled / not initialized
vars_v%name(26) = NUL-filled / not initialized
```

The exact B0 source defines `S_CONC` as vector variable 26 in `SWAP_csv_output`, but under the tested GNU build the `vars_v` metadata initialized by the legacy `DATA` statement are not populated. Additional diagnostic compile variants using `-fno-automatic`, `-fdec`, `-std=legacy` and combinations did not resolve this.

Therefore:

```text
S_CONC lookup failure on GNU source build: RUNNER/COMPILER PORTABILITY LIMITATION
confirmed B0 CSV defect:                 NOT ESTABLISHED
```

No B1 difference is registered from this finding. The GNU source runner must not be used as an oracle for vector CSV output unless this portability gap is separately solved and qualified.

Disabling CSV for balance regression is classified as a `runner_portability_output_workaround`, not as evidence of a B0 defect.

## Official-case hardening matrix

The machine-readable record is `tools/vq/cases/b0-official-case-matrix.json`.

### Hupselbrook

The unchanged official case requests vector CSV output and is rejected by the provisional GNU runner because of the vector-metadata limitation above.

For balance-only qualification, `SWCSV=1 -> 0` is applied explicitly. The full 2002-2004 run then completes normally and reproduces the package-published 2002 water balance exactly at report precision:

| Quantity | Published B0 | GNU balance run |
| --- | ---: | ---: |
| Rain + snow | 84.18 cm | 84.18 cm |
| Irrigation | 2.40 cm | 2.40 cm |
| Transpiration | 34.73 cm | 34.73 cm |
| Soil evaporation | 11.99 cm | 11.99 cm |
| Drainage level 1 | 32.76 cm | 32.76 cm |
| Storage change | 2.82 cm | 2.82 cm |

Two fresh runs are identical after removal of only the generated timestamp:

```text
result.bal SHA-256: a9cc9b18a404726dfbce22d8372df279b9d3bdf1bc76c8c38f33c8080430d0e7
result.blc SHA-256: 1bd2631d91cb21e72a5949f54524d0cb55ed0bb059a88fc4a4def8507693b77c
```

### Grass growth

The official `2.grassgrowth` case runs **unchanged** with the provisional GNU source build over 1980-01-01 through 1984-12-31.

Two fresh unchanged runs produce identical CSV after timestamp normalization:

```text
result_output.csv SHA-256:
0a7025b72abbb524760107ca1f0309d8e241a7aa2830bb983afe9245730dec7e
```

An output-only variant enabling `SWBAL=1` and `SWBLC=1` also repeats exactly:

```text
result.bal SHA-256: 7fae2e0c1652aa8db55c2a981bfd21c9917509a9e03345d252d01064da90d1cf
result.blc SHA-256: 58b43ddb970a4581a5501382dad58ef25992e8d094a873be7391f9c33974b422
```

All five annual `.BLC` records print zero balance deviation at legacy report precision. This is the strongest current cross-case evidence for the GNU runner because the official input is unchanged and the normal scalar CSV path completes.

### Macropore flow

The full official `3.macroporeflow` interval, 1998-01-01 through 1999-04-26, did not complete within the current bounded VQ execution window. The environment terminated the run before normal completion and no SWAP error was observed.

```text
full official macropore case: NOT YET QUALIFIED_BOUNDED_RUNTIME
model failure:                NOT ESTABLISHED
```

A TEND-only 31-day smoke variant changes only:

```text
TEND = 1999-04-26 -> 1998-01-31
```

It preserves the official macropore process path, completes normally and repeats exactly:

```text
result_output.csv SHA-256:
b09e200702e1c90540816bbf2ce9e11fb1f66b2b946fb7b8e750cf98afb092e6
```

A seven-day variant also completes normally. These are execution-path smoke tests, not substitutes for qualification of the full official case.

### Salinity stress

The official `4.salinitystress` example uses the bundled R workflow to construct three runs from `datamodel.xlsx`:

```text
run 1 -> irrigation_id 2 -> 04dS
run 2 -> irrigation_id 3 -> 08dS
run 3 -> irrigation_id 5 -> 16dS
```

`Rscript` is unavailable in the current VQ environment. For diagnostic hardening only, the run matrix and irrigation records were read from the exact bundled workbook and the table-format semantics reconstructed from the bundled `SWAPtools` source. The generated inputs parse successfully, but they have not been byte-cross-checked against an official R-generated run directory and remain **provisional preprocessing evidence**.

With vector CSV enabled, all three scenarios hit the same GNU `vars_v` metadata limitation. With explicit output-only changes:

```text
SWCSV = 1 -> 0
SWBAL = 0 -> 1
SWBLC = 0 -> 1
```

all three four-year scenarios complete normally and repeat exactly. Their normalized hashes are recorded in the official-case matrix. Every annual `.BLC` record prints zero balance deviation at legacy report precision.

These runs qualify a provisional salinity execution-path smoke only, not a formal native B0 oracle.

## Water-balance extraction and invariant-13 boundary

`tools/vq/balance.py` converts legacy `.BAL` and `.BLC` reports into canonical machine-readable values. `tools/vq/qualify_hupselbrook.py` checks the published Hupselbrook 2002 package oracle.

Legacy `.BAL` and `.BLC` values are printed at `0.01 cm` resolution. A printed `Balance Deviation 0.00` proves report-level consistency only and cannot expose the unrounded residual required by invariant 13.

```text
legacy report regression/accounting: PASS where recorded
hard SWAP5 mass-conservation gate:   NOT ELIGIBLE from BAL/BLC alone
```

## B2 unrounded mass-accounting contract

VQ-1b now also provides a proposed verification-only contract in:

```text
docs/verification/mass-accounting-contract.md
tools/vq/contracts/mass-accounting-record.schema.json
```

The contract requires unrounded start/end storage, signed interval-integrated external water terms, explicit component/interface identity, trial-versus-committed scope, accepted-trial identity where applicable, execution class and tolerance provenance.

VQ recomputes the hard residual independently:

```text
delta_storage = storage.end_total - storage.start_total
net_external  = sum(signed_amount for external boundary/source terms)
residual      = delta_storage - net_external
```

The contract is generic in `[t0,t1]`, supports transactional exactly-once accounting, coupling-interface reconciliation, optional components and system composition, and does not allow a relaxed/fallback/performance execution class to weaken mass conservation.

This is a verification interchange contract only. TX/HY/runtime own any future production result-interface implementation.

## B1 status transition during VQ-1b

At the start of this hardening pass B1 was not yet available. Parallel work subsequently advanced `main` to commit:

```text
5c549e950df98d0cf0c0ef22ac1b682ec2d3bef1
```

The integrated corrected-reference manifest now identifies:

```text
snapshot: B1.3
status: CORRECTED_REFERENCE
patches: SWAP-001, SWAP-005, SWAP-006
published_b1_snapshots: immutable
```

The separate `B1.3.yml` snapshot pins the B0 source identity and the exact accepted patch hashes. Therefore the **VQ-1c entry condition is now met**. VQ-1c must pin B1.3 and the exact integration commit/snapshot identity before executing B0/B1 comparisons.

This does not retroactively turn the GNU runner portability finding into a B1 difference.

## Current qualification status

```text
Exact B0 identity                                  PASS
Packaged native Linux B0 runner                    BLOCKED: missing libimf.so
Provisional exact-source GNU build                 PASS as build
GNU scalar-output full official case               PASS: grass growth
GNU vector-CSV output                              UNQUALIFIED: vars_v portability limitation
Hupselbrook balance-only workaround                PASS + published balance cross-check
Grass-growth repeatability                         PASS
Macropore full official run                        NOT YET QUALIFIED: bounded runtime
Macropore 31-day execution-path smoke              PASS + repeatability
Salinity official R preprocessing                  BLOCKED in environment
Salinity reconstructed balance-only process smoke  PROVISIONAL PASS + repeatability
Legacy report mass accounting                      PASS at 0.01 cm report resolution where tested
Hard machine-precision mass gate                   CONTRACT DEFINED, B2 IMPLEMENTATION NOT YET AVAILABLE
B1 corrected reference                             AVAILABLE: B1.3
B0/B1 edge comparison                              NOT YET EXECUTED
B2 comparison                                      NOT AVAILABLE
```

## Integration boundary

VQ-1b adds only verification tooling, manifests, schemas and evidence. Diagnostic local source instrumentation used to identify the GNU vector-metadata limitation is not a production patch and is not admitted into B0 or B1.

A production discrepancy discovered by VQ must be handed to the owning workstream. VQ does not repair it inside the oracle.

## Next safe step

1. integrate/rebase the VQ branch deliberately against current `main` before acceptance because parallel work has advanced substantially;
2. hand the unrounded mass-accounting contract to TX/HY/runtime for explicit interface mapping without changing production code in VQ;
3. retain the GNU runner as capability-limited until a native Intel environment or separately qualified portability build is available;
4. start **VQ-1c** by pinning B1.3 and building the first B0 -> B1 edge comparison with the expected-difference ledger.

The full macropore case can be revisited in a benchmark environment without weakening bounded-cost rules.
