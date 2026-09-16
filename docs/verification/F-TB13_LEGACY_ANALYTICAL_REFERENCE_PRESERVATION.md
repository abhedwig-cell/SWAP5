# F-TB13 — Legacy analytical reference preservation

## Purpose

F-TB13 turns the strongest reusable assets recovered by F-AR01 into a durable, non-production testbank surface without importing the whole historical verification framework as current authority.

## Reconciled authority

Canonical at work-unit start: `integration/f-ci-canonical@289e64e1ba826aa7ebb42b8ae5c5a80575a223c4`.

Corrected legacy reference: B1.11, 63 source members, 1,886,519 bytes, member-manifest SHA-256 `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.

Recovered framework archive SHA-256: `199f3d1d607255a813bb023c5741de17eacb173c2537a56bfa214ad2827b0fca`.

## Fresh qualification

The suite was first rerun unchanged against the framework GNU executable. The four preserved output files reproduced their packaged identities exactly.

B1.11 was then reconstructed from the exact canonical B0 distribution and built with GNU Fortran 14.2.0. Only the already-understood Intel `!DEC$` standalone/Linux conditional subset was resolved in the disposable build tree; the exact B1.11 reference source remained immutable.

The fresh B1.11 replay produced:

- steady-state water: 12/12 successful runs;
- comparison with the documented Technical Addendum metrics: 12/12 PASS;
- Srivastava-Yeh/Gardner transient analytical benchmark: 12/12 PASS;
- coarse-to-fine h-RMSE convergence: PASS at t = 1, 2, 5 and 10;
- byte-identical CSV/convergence outputs between the historical framework GNU replay and the B1.11 GNU replay.

The largest steady-state pointwise head error in the preserved suite is 22.72959133561503 cm in a sharp-interface case, while the documented benchmark criteria still pass. F-TB13 therefore preserves the benchmark's defined acceptance behavior and does not reinterpret every pointwise error as small.

Preserved output identities:

```text
steady_state_water_summary.csv
  ebdbc7fff0495702919e9cf82e0af6782010ad2ab79f276dcb4574aeb2a9b774
steady_state_water_vs_documented.csv
  7a23144ff3db4ded15ca4dccfb194295e982a76dc5a985a378cfbe1d7c389033
srivastava_yeh_homogeneous_summary.csv
  05d0a78efd08f5d699d232c160572da82e502f07eb54c75137450d40ead80580
srivastava_yeh_convergence.txt
  a269884e05f295e172b47922c3925058868c472fe53876c9ee3a98763645e039
```

The deterministic preserved asset archive is pinned at SHA-256 `57a75c64e1b057223fbd32ac3051a2c56938209f19b86912d7236f4f1d5fc069`. The repository gate verifies the archive identity, all nine member identities, the expected case counts and PASS markers, and the cross-replay B1.11 identity marker without needing external numerical packages.

## Admission boundary

F-TB13 preserves the test definitions, analytical oracles, template, expected results and replay receipt. No `src/**` or `reference/**` file is changed. No physics, solver algorithm, timestep rule, retry policy, mass tolerance or B1 identity is changed.

The steady-state solute reconstruction remains useful verification evidence but its historical 2021 RMSE table stays informational until the original historical input/executable is recovered. Basha (1999) remains blocked on missing adjusted parameters. Those assets are not silently promoted by F-TB13.

## Verdict

`QUALIFIED_LEGACY_ANALYTICAL_REFERENCE_PRESERVATION_CANDIDATE`
