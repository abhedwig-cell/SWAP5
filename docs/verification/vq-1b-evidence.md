# VQ-1b B0 runner and balance evidence

## Integration record

```text
WORKSTREAM: VQ
SLICE: VQ-1b
ORIGINAL BRANCH BASELINE: 40aef01c5c89dc9e02bba50d31c884dcdd2fd2d5
CURRENT MAIN RE-READ AT HARDENING: f369e68a06e97780e7879a33937b41539a81c557
SCOPE: reproducible B0 execution bootstrap, official-case hardening and canonical legacy water-balance extraction
PRODUCTION CODE CHANGED: no
INTERFACES CHANGED: no
INVARIANTS: 13, 24, 25, 29, 30
```

VQ-1b remains verification infrastructure. It does not change SWAP physics, numerical policy, state ownership or production interfaces.

The VQ branch predates substantial parallel changes on `main`. The current integration baseline was re-read before this hardening step. The branch must be rebased or otherwise integrated deliberately before merge; the older branch base is not being silently treated as the current project baseline.

## B0 identity

The supplied archive used for this slice passed the VQ-1a identity gate:

```text
size:   8,959,314 bytes
sha256: 2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360
```

The exact source archive and packaged executables remain governed by `reference-baseline.json`.

## Native B0 executable status

The packaged Linux executable remains the preferred B0 execution oracle, but it cannot run in the current VQ environment because the Intel runtime library `libimf.so` is absent. The Windows executable cannot be used either because no Windows compatibility runtime is available in the current environment.

This is an environment dependency, not a model discrepancy. No numerical evidence is accepted from a failed native launch.

## Provisional exact-source GNU runner

`tools/vq/b0_source_runner.py` builds TTUTIL and SWAP from the exact source archives contained in B0 and applies only the standalone-Linux Intel `!DEC$` branch selections.

Tested compiler:

```text
GNU Fortran (Debian 14.2.0-19) 14.2.0
```

Tested provisional executable SHA-256:

```text
5eca528a3635f82713abaa360701010868834397dcdff65d57c4385bb62784d5
```

The GNU build is **not** declared equivalent to the packaged Intel executable. VQ admits only specifically cross-checked outputs from it.

## Important correction: vector CSV is a GNU-runner portability limitation

Earlier VQ-1b evidence described the Hupselbrook `S_CONC` stop as an output compatibility issue. Hardening has now localized the mechanism more precisely.

A diagnostic-only GNU build showed:

```text
vars_s%name(1)  = RAIN
vars_s%name(40) = BALDEV
vars_v%name(1)  = NUL-filled / not initialized
vars_v%name(26) = NUL-filled / not initialized
```

The exact B0 source defines `S_CONC` as vector variable 26 in `SWAP_csv_output`, but under the tested GNU build the `vars_v` vector metadata initialized by the legacy `DATA` statement are not populated. Scalar metadata are populated correctly. Additional compile variants using `-fno-automatic`, `-fdec`, `-std=legacy` and combinations did not change this result.

Therefore:

```text
S_CONC lookup failure on GNU source build: RUNNER/COMPILER PORTABILITY LIMITATION
confirmed B0 CSV defect:                 NOT ESTABLISHED
```

No B1 difference may be registered from this finding. The source runner must not be used as an oracle for vector CSV output unless this portability gap is separately solved and qualified.

Disabling CSV remains useful for balance-only regression evidence, but it is now classified as a **runner-portability output workaround**, not as evidence of a B0 output defect.

## Official-case hardening matrix

The machine-readable record is:

```text
tools/vq/cases/b0-official-case-matrix.json
```

### 1. Hupselbrook

The unchanged official case requests vector CSV output and is rejected by the provisional GNU runner because of the vector-metadata limitation described above.

For balance-only qualification, `SWCSV=1 -> 0` is applied explicitly. With that workaround the full 2002-2004 simulation completes normally. The package-published 2002 water balance is reproduced exactly at the report precision, including:

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

### 2. Grass growth

The official `2.grassgrowth` case runs **unchanged** with the provisional GNU source build over the full interval 1980-01-01 through 1984-12-31.

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

All five annual `.BLC` records print zero balance deviation at legacy report precision.

This is the strongest current cross-case evidence for the GNU source runner because the official input is unchanged and the run completes through its normal CSV path.

### 3. Macropore flow

The full official `3.macroporeflow` interval is 1998-01-01 through 1999-04-26. It did not complete within the current bounded VQ execution window. The run was terminated by the verification environment before normal completion, without a SWAP error.

VQ therefore records:

```text
full official macropore case: NOT YET QUALIFIED_BOUNDED_RUNTIME
model failure:                NOT ESTABLISHED
```

A TEND-only 31-day smoke variant preserves the official macropore physics and input structure but changes:

```text
TEND = 1999-04-26 -> 1998-01-31
```

This bounded smoke case completes normally and repeats exactly after timestamp normalization:

```text
result_output.csv SHA-256:
b09e200702e1c90540816bbf2ce9e11fb1f66b2b946fb7b8e750cf98afb092e6
```

A seven-day variant also completes normally. These are execution-path smoke tests only; they do not replace qualification of the full official case.

### 4. Salinity stress

The official `4.salinitystress` example is not a ready-to-run directory. It uses the bundled R workflow to construct three runs from `datamodel.xlsx`:

```text
run 1 -> irrigation_id 2 -> 04dS
run 2 -> irrigation_id 3 -> 08dS
run 3 -> irrigation_id 5 -> 16dS
```

`Rscript` is unavailable in the current VQ environment. For diagnostic hardening only, the run matrix and irrigation records were read from the exact bundled workbook and the table formatting semantics were reconstructed from the bundled `SWAPtools` source. The generated inputs parse successfully in SWAP, but they have not yet been byte-cross-checked against an official R-generated run directory and are therefore **provisional preprocessing evidence**.

With vector CSV enabled, all three scenarios hit the same GNU `vars_v` metadata limitation as Hupselbrook.

With explicit output-only changes:

```text
SWCSV = 1 -> 0
SWBAL = 0 -> 1
SWBLC = 0 -> 1
```

all three four-year scenarios complete normally and repeat exactly. Normalized hashes are recorded in `b0-official-case-matrix.json`. Every annual `.BLC` record prints zero balance deviation at legacy report precision.

These runs show that the provisional GNU build can execute the salinity process path when the known vector-CSV portability path is bypassed. They are not yet a formal B0 oracle because the R preprocessing provenance remains incomplete.

## Water-balance extraction and mass-conservation boundary

`tools/vq/balance.py` converts legacy `.BAL` and `.BLC` reports into canonical machine-readable values. `tools/vq/qualify_hupselbrook.py` checks the published Hupselbrook 2002 package oracle.

Legacy `.BAL` and `.BLC` values are printed at `0.01 cm` resolution. A printed `Balance Deviation 0.00` proves report-level consistency only. It does not expose the unrounded residual required by invariant 13.

VQ therefore keeps the hard distinction:

```text
legacy report regression/accounting: PASS where recorded
hard SWAP5 mass-conservation gate:   NOT ELIGIBLE from BAL/BLC alone
```

The future B2 result contract must expose unrounded storage and interval-integrated flux/source accounting.

## Current qualification status

```text
Exact B0 identity                                  PASS
Packaged native Linux B0 runner                    BLOCKED: missing libimf.so
Provisional exact-source GNU build                 PASS as build
GNU scalar-output full official case               PASS: grass growth
GNU vector-CSV output                              UNQUALIFIED: vars_v metadata portability limitation
Hupselbrook balance-only workaround                PASS + published balance cross-check
Grass-growth repeatability                         PASS
Macropore full official run                        NOT YET QUALIFIED: bounded runtime
Macropore 31-day execution-path smoke              PASS + repeatability
Salinity official R preprocessing                  BLOCKED in environment
Salinity reconstructed balance-only process smoke  PROVISIONAL PASS + repeatability
Legacy report mass accounting                      PASS at 0.01 cm report resolution where tested
Hard machine-precision mass gate                   NOT YET AVAILABLE
B1 comparison                                      NOT AVAILABLE
B2 comparison                                      NOT AVAILABLE
```

## Relation to current main

During this hardening step `main` advanced to `f369e68a06e97780e7879a33937b41539a81c557`. Current main contains a `SWAP-011` B1 candidate dossier with technical state `FIX_TESTED / READY_PATCH_UPSTREAM`, but the exact qualified E7 patch payload is still pending and the B1 manifest remains unchanged.

Therefore VQ-1c is still blocked. A technically qualified candidate is not yet an immutable B1 reference snapshot.

## Integration boundary

VQ-1b adds only verification tooling, manifests and evidence. Diagnostic local source instrumentation used to identify the GNU vector-metadata limitation is not a production patch and is not admitted into B0 or B1.

A production discrepancy discovered by VQ must be handed to the owning workstream. VQ does not repair it inside the oracle.

## Next safe step

Continue VQ-1b hardening in two bounded directions:

1. treat the GNU source runner as capability-limited and obtain either a native Intel execution environment or an explicitly qualified portability build before vector CSV is admitted as B0 evidence;
2. draft the **unrounded B2 mass-accounting result contract** for handoff to TX/HY/runtime without changing production code in VQ.

The macropore full-case runtime can be revisited in a benchmark environment without weakening bounded-cost rules. `VQ-1c` remains the formal B1 pin and starts only after an immutable B1 tag and commit exist.
