# VQ-1b B0 runner and balance evidence

## Integration record

```text
WORKSTREAM: VQ
SLICE: VQ-1b
BASELINE: 40aef01c5c89dc9e02bba50d31c884dcdd2fd2d5
SCOPE: reproducible B0 execution bootstrap and canonical legacy water-balance extraction
PRODUCTION CODE CHANGED: no
INTERFACES CHANGED: no
INVARIANTS: 13, 25, 29, 30
```

VQ-1b remains verification infrastructure. It does not change SWAP physics, numerical policy, state ownership or production interfaces.

## B0 identity

The supplied archive used for this slice passed the VQ-1a identity gate:

```text
size:   8,959,314 bytes
sha256: 2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360
```

The case input `cases/1.hupselbrook/swap.swp` has SHA-256:

```text
a54d110efa0cf003b23537109a3aea83f17f941fa875a5de6aefd65291405b5b
```

## Native B0 executable status

The packaged Linux executable remains the preferred B0 execution oracle, but it cannot run in the current VQ environment because the Intel runtime library `libimf.so` is absent. This is an environment dependency, not a model discrepancy.

No numerical evidence is accepted from a failed native launch.

## Provisional exact-source runner

To avoid blocking all B0 qualification work, VQ-1b adds `tools/vq/b0_source_runner.py`.

The runner:

1. verifies the exact B0 distribution identity before extraction;
2. builds TTUTIL and SWAP from the source archives contained in that distribution;
3. applies only the standalone-Linux Intel `!DEC$` branch selections:
   - `linux = true`;
   - `multiswap = false`;
   - `with_sss = false`;
   - `with_animo = false`;
4. compiles with GNU Fortran;
5. treats legacy exit code `100` plus `swap.ok` plus empty `swap.err` as normal completion.

The tested compiler was:

```text
GNU Fortran (Debian 14.2.0-19) 14.2.0
```

This runner is **not** declared equivalent to the supplied Intel executable merely because it compiles and runs. Its outputs require independent qualification evidence.

## Hupselbrook output compatibility issue

The unchanged official Hupselbrook case has `SWCSV = 1`. Under the provisional GNU source build it stops in `csv_write` because `S_CONC` is reported as unknown in the CSV variable list. The run does not create `swap.ok` and is therefore rejected by the VQ runner.

For the water-balance bootstrap only, VQ-1b uses an explicit runner compatibility variant:

```text
SWCSV = 1  ->  SWCSV = 0
```

The patched `swap.swp` SHA-256 is:

```text
b4e6045e33abdb0fe6137e9cd555c6c23e8965d6b7441a05402c220520456b54
```

This is classified as `output_only_runner_compatibility`, not as B1 physics correction. It is never applied silently and it is recorded in the case manifest.

## Published B0 smoke oracle

The B0 package README publishes the first-year Hupselbrook water balance for 2002. The provisional source runner reproduces every published value at the report precision:

| Quantity | Published B0 | VQ-1b source run |
| --- | ---: | ---: |
| Rain + snow | 84.18 cm | 84.18 cm |
| Runon | 0.00 cm | 0.00 cm |
| SSDI | 0.00 cm | 0.00 cm |
| Irrigation | 2.40 cm | 2.40 cm |
| Bottom flux | 0.00 cm | 0.00 cm |
| Interception | 4.25 cm | 4.25 cm |
| Runoff | 0.03 cm | 0.03 cm |
| Transpiration | 34.73 cm | 34.73 cm |
| Soil evaporation | 11.99 cm | 11.99 cm |
| Crack flux | 0.00 cm | 0.00 cm |
| Drainage level 1 | 32.76 cm | 32.76 cm |
| Input sum | 86.58 cm | 86.58 cm |
| Output sum | 83.76 cm | 83.76 cm |
| Storage change | 2.82 cm | 2.82 cm |

The machine-readable oracle is `tools/vq/cases/b0-hupselbrook-readme-smoke.json`.

## Repeatability

Two fresh runs were made from separate case directories using the same exact-source build and the recorded output-only compatibility patch.

After removing only the generated timestamp line:

```text
result.bal SHA-256: a9cc9b18a404726dfbce22d8372df279b9d3bdf1bc76c8c38f33c8080430d0e7
result.blc SHA-256: 1bd2631d91cb21e72a5949f54524d0cb55ed0bb059a88fc4a4def8507693b77c
```

Both normalized hashes were identical between the two runs.

## Water-balance extraction

`tools/vq/balance.py` converts legacy `.BAL` and `.BLC` reports into canonical machine-readable values. `tools/vq/qualify_hupselbrook.py` checks the published 2002 package oracle and requires all printed `.BLC` balance deviations to be zero.

The tested Hupselbrook run passes that gate for 2002, 2003 and 2004 at the precision exposed by the legacy reports.

## Important mass-conservation limitation

This result must **not** be promoted to the final invariant-13 hard mass gate.

Legacy `.BAL` and `.BLC` water values are printed at `0.01 cm` resolution. A printed `Balance Deviation 0.00` therefore proves report-level consistency only. It does not expose the unrounded residual required for a strict machine-auditable SWAP5 acceptance gate.

VQ therefore records:

```text
B0 published smoke regression: PASS
B0 legacy report accounting:   PASS at 0.01 cm report resolution
hard SWAP5 mass gate:          NOT YET ELIGIBLE from these files alone
```

The future B2 gate must consume unrounded storage and integrated flux accounting from the SWAP5 result/diagnostic contract.

## Qualification status

```text
Exact B0 identity                         PASS
Native packaged Linux runner             BLOCKED: missing libimf.so
Exact-source GNU build                    PASS
Unchanged Hupselbrook execution           REJECTED: CSV-output compatibility issue
Explicit SWCSV=0 balance-only variant     PASS
Published 2002 README water balance       PASS at printed precision
Fresh-run repeatability                   PASS
Canonical BAL/BLC extraction              PASS
Hard machine-precision mass gate          NOT YET AVAILABLE
B1 comparison                             NOT AVAILABLE
B2 comparison                             NOT AVAILABLE
```

## Integration boundary

VQ-1b adds only verification tooling, a case manifest and evidence. No kernel, solver, runtime or legacy production source is changed.

A production discrepancy discovered by this harness must be handed to the owning workstream. VQ does not repair it inside the oracle.

## Next safe step

`VQ-1c` should separate two concerns:

1. close the B0 runner provenance gap by obtaining a runnable native Intel environment or by cross-qualifying the exact-source runner on additional official cases;
2. define the unrounded mass-accounting result contract that B2 must expose, without changing production code until the owning implementation workstream accepts the integration point.
