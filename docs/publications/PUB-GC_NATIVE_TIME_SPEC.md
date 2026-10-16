# PUB-GC native SWAP integration adequacy specification

Status: **frozen before implementation and execution**

Publication owner: `PUB-GC`

Supporting study: `PUB-GC-NATIVE-TIME-0001`

Affected later experiments: `PUB-GC-E2`, `PUB-GC-E3`

Authority dependency:
- macro-window design adjudication: `29f3bf635d69e076926d6cb99cf3f7d058f67a63`
- qualified macro response receipt: `docs/publications/results/PUB-GC-MACRO-WINDOW-QUAL-0001.yaml`

This study selects an internal SWAP integration policy only. It creates no H2/H3 result.

## 1. Scientific purpose

Future coupling-window experiments must vary external coupling macro-window duration without silently changing the native SWAP integration accuracy at the same time.

For a prescribed macro head and forcing history, define a family of native SWAP interval partitions over the **same** macro interval. The study asks whether endpoint SWAP state and integrated lower-boundary exchange are stable as the native partition is refined.

The selected policy is the coarsest preregistered native interval that satisfies all frozen adequacy criteria across all qualification-only cases, provided the finest refinement pair is itself stable.

## 2. Frozen implementation authority

Research branch to create after this specification:

`research/pub-gc-native-time`

Base:

`research/pub-gc-macro-window-response@32d1e9ae1bb3f0cda7a26e114eca0fe5fd900d12`

Frozen production source tree:

`d7ef6c045263de821db7800459289efcd8a6420b`

Qualified macro module blob:

`920b93b943ead1187887e683c50a84e0f4cb3a46`

Allowed mutations:
- `tests/publication/pub_gc/native_time/**`
- `.github/workflows/pub-gc-native-time.yml`

Forbidden:
- `src/**`
- `tests/publication/pub_gc/macro_window_response/**`
- all previously qualified PUB-GC component directories.

## 3. Common physical/numerical fixture

Use the same real B1.10 physical fixture and public transaction route as the qualified macro response.

Common values:
- initial committed time: 4200.125 d;
- initial pressure-head profile: -80 cm;
- bottom mode: prescribed head (mode 5);
- temporal mode: `TX_TEMPORAL_MODEL_CERTIFICATE`;
- model temporal indicator budget: 100;
- transaction hard mass tolerance: 1e-10;
- total macro duration: 0.04 d;
- all forcing switch times are exactly aligned with every level in the frozen ladder.

Top-flux factors are exact multipliers of the positive initial-state hydraulic conductivity `K0`.
Negative surface flux is downward into the soil; positive is upward extraction.

## 4. Frozen native interval ladder

Every level spans exactly 0.04 d:

- `N0`: 4 intervals of 0.01000 d;
- `N1`: 8 intervals of 0.00500 d;
- `N2`: 16 intervals of 0.00250 d;
- `N3`: 32 intervals of 0.00125 d.

`N3` is the comparison reference for policy selection, conditional on the independent N2-to-N3 stability guard.

No extra refinement level may be introduced after seeing results. If N2-to-N3 is unstable under the frozen criteria, this study returns **NO_POLICY_SELECTED_FINE_LEVEL_UNSTABLE** and a new preregistered design is required.

## 5. Frozen qualification-only cases

All cases are permanently excluded from H2/H3 primary inference and later stress-amplitude tuning.

### NT-C0 — constant baseline
- prescribed bottom head: -80 cm;
- top-flux factors by 0.01 d segment: [-1, -1, -1, -1].

### NT-W3 — wetting pulse
- prescribed bottom head: -80 cm;
- top-flux factors: [-3, -1, -1, -1].

### NT-D05 — drying pulse
- prescribed bottom head: -80 cm;
- top-flux factors: [0.5, -1, -1, -1].

### NT-R3 — forcing reversal
- prescribed bottom head: -80 cm;
- top-flux factors: [-3, 0.5, -1, -1].

### NT-H60 — lower-boundary head transition
- prescribed bottom head: -60 cm;
- top-flux factors: [-1, -1, -1, -1].

The cases are chosen before execution to exercise calm, wetting, drying, reversal and boundary-head response. Their observed terminal-surrogate mismatch is irrelevant to this study and must not be used for selection.

## 6. Required outputs per case and level

Persist:
- completed/failure classification;
- native interval count and duration;
- cumulative `Q_whole`;
- final endpoint pressure-head profile;
- final endpoint water-content profile;
- final total water storage;
- total transaction retries;
- total accepted internal substeps;
- authoritative origin lineage/revision/time before and after.

The terminal-flux surrogate difference may not be a policy-selection metric. Prefer not to emit it in the native-time summary.

## 7. Frozen adequacy tolerances

Reuse the already prospectively established state/reference tolerances from the earlier GC-REF supporting work rather than choosing new thresholds from this study:

- absolute cumulative exchange difference: <= 1.0e-4 cm;
- final maximum pressure-head difference: <= 1.0e-2 cm;
- final maximum water-content difference: <= 1.0e-5;
- final total-water-storage difference: <= 1.0e-4 cm.

All comparisons are against N3 unless explicitly labelled as the N2-to-N3 guard.

## 8. Fine-level stability guard

For **every** frozen case, N2 versus N3 must satisfy all four adequacy tolerances.

If any case fails:
- no native policy is selected;
- do not relax thresholds;
- do not remove the failing case;
- do not inspect terminal-surrogate mismatch to justify a choice;
- persist the failure and freeze a new design before further refinement.

## 9. Policy selection rule

Conditional on the fine-level guard passing:

1. evaluate N0 versus N3 across all cases;
2. evaluate N1 versus N3 across all cases;
3. evaluate N2 versus N3 across all cases;
4. select the **coarsest** level that passes all four adequacy tolerances in every case.

Possible results:
- `SELECT_N0_0P01000_DAY`;
- `SELECT_N1_0P00500_DAY`;
- `SELECT_N2_0P00250_DAY`;
- `NO_POLICY_SELECTED`.

The selected value is an internal integration policy for the controlled PUB-GC experiments, not a universal SWAP timestep recommendation.

## 10. Reproducibility and fail-closed controls

Qualification must additionally demonstrate:
- exact O0/O2 scientific-output identity;
- production source-tree identity with the frozen authority;
- qualified macro-module blob identity;
- authoritative accepted origin is unchanged by every disposable trajectory;
- all levels use the same physical initial state and exact forcing switch times;
- nonfinite telemetry or any failed native trajectory invalidates that case/level and prevents policy selection.

## 11. Interpretation boundary

A PASS can establish only:
- the macro response can be run under a preregistered internal-step ladder;
- the finest pair is stable under frozen state/exchange criteria;
- one frozen native interval is adequate for the controlled later PUB-GC experiment suite under these qualification cases.

It does not establish:
- H2;
- H3;
- superiority of whole-window exchange;
- a practical coupling-window limit;
- a MODFLOW6 result;
- a universal timestep criterion for SWAP;
- solver-performance results belonging to PUB-SQ.

## 12. Next permitted action

After this specification and its manifest are committed:
1. create `research/pub-gc-native-time` from the qualified macro-response head;
2. implement only the native-time supporting oracle;
3. execute the exact frozen ladder/cases under O0/O2;
4. persist every outcome and the mechanical selection result;
5. only after a policy is selected may new E2/E3 macro-window screening be preregistered.
