# F-GC-STRIP01 C2D: 50-column Dummy-SWAP strip

**Decision:** `DUMMY_STRIP_QUALIFIED_COUPLING_INFRASTRUCTURE_SUPPORTED`  
**Scope:** research harness; no production or canonical change.  
**Run source:** `31dd33167f2c3d8fb363bf8d7fc0d700c439e585`  
**Base C2B source:** `ac87e2484b1ecc54c8eac9072cd6f9248fbeb5e9`  
**Dummy-bank reference:** `work/f-gc-dummy-swap-shared-storage` at `4fd8861bf6300d8074051d3bd24ef993cb60dbda`

## What was tested

C2D replaces the real Richards participants with an analytic, memoryless storage response while retaining the 50-cell MODFLOW6 strip and the existing groundwater application service. One dummy participant maps to each MODFLOW cell. The harness uses the repository's `run_groundwater_application_window`, `Modflow6PreparedSolveSession` and the native Fortran F-GC34 package publisher. MODFLOW6 6.8.0 was fetched using the existing pinned route; the release archive SHA-256 is `33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e`, and the executed `libmf6.so` SHA-256 is `8589fceef108757f62bb82cb2b0282562172312a75187b70ae7a06f4bd15fbf9`.

The final A/B-aligned geometry and numerical settings are 50 columns, 50 one-metre MODFLOW cells, one layer from -2 to -10 m, Kx=0.5 m/day, a left drain at -1 m with conductance 100 m²/day, and no-flow right and bottom boundaries. Initial heads are -1 m, matching C2B. The MODFLOW IMS controls also match the C2B research runner. Each participant's state and ledger revision advanced exactly once per accepted window.

The preregistered sequence contains four zero-forcing equilibrium windows, followed by 80 quarter-day windows with uniform 0.001 m/day recharge and 40 quarter-day recession windows. Total recharge is 1.0 m³ over 50 columns. Two responses were tested:

| Response | Vertical conductance | Final internal-head/interface-head gap |
| --- | ---: | ---: |
| Near-zero resistance limit | 1,000,000 m²/day | 5.50×10⁻¹¹ m |
| Finite resistance | 0.125 m²/day | 4.54×10⁻⁴ m |

For the finite-resistance case, the largest error in `q = C (h_internal - H_interface)` was 7.59×10⁻¹⁸ m³/day. This keeps the two heads distinct while checking the prescribed resistance law. The high-conductance case approaches the zero-gap limit.

## Storage and flux ownership

The test declares disjoint research control volumes at the fixed interface z=-2 m:

- Dummy-SWAP owns one analytic top-system storage state per 1 m² column, above the interface. Its storage coefficient is 0.05 m³/m² per metre of head. It receives the uniform input and owns no ET, drain or internal memory.
- MODFLOW owns the separate confined aquifer storage from -2 to -10 m. Specific storage is 0.025 m⁻¹, giving 0.2 m³/m² per metre of head over the eight-metre layer.
- The drain belongs to MODFLOW alone. The MODFLOW DRN package is the only drain representation.
- Interface transfer is positive from Dummy-SWAP to MODFLOW. It is recorded once as Dummy-SWAP outflow and once as MODFLOW inflow. Those entries cancel in the complete-domain balance.
- Native `FLOW-JA-FACE` records provide lateral face fluxes. Those internal flows cancel over the complete strip; native DRN package budgets provide the external drain volumes.

The complete balance per window is `input - ΔS_dummy - ΔS_MODFLOW - drain - residual = 0`. The DSW storage work warns against counting shared/coextensive storage twice; the C2D contract instead assigns its two storage owners to disjoint vertical intervals. This experimental aquifer-storage authority applies only to this declared research domain. It does not amend the current fixed-interface production contract, which still does not admit independent physical MODFLOW storage or a production drain owner.

## Results

A final local rerun at the recorded source commit confirmed the compact persisted artifacts. The zero-forcing case published all four windows. All 50 heads and dummy states stayed exactly at -1 m; interface transfer, lateral flow, drain and storage changes were zero. Per-window and cumulative mass residuals were zero. The complete run replayed byte-for-byte in a fresh process.

Both dynamic configurations published all 120 windows with exact fresh-process JSON replay. The maximum coupling residuals were 1.61×10⁻²² m/s for near-zero resistance and 7.61×10⁻²³ m/s for finite resistance. Both cases were rerun with the stricter C2B diagnostic threshold of 2×10⁻¹⁵ m/s; all windows still published and the responses were unchanged.

| Measure | Near-zero resistance | Finite resistance |
| --- | ---: | ---: |
| Interface transfer to groundwater | 0.88182 m³ | 0.88037 m³ |
| MODFLOW drain outflow | 0.40908 m³ | 0.40527 m³ |
| Head rise at no-flow end, after 30 days | 0.07143 m | 0.07160 m |
| Largest absolute native lateral face flow | 0.01962 m³/day | 0.01943 m³/day |
| Largest absolute window mass residual | 2.71×10⁻¹⁴ m³ | 1.25×10⁻¹⁴ m³ |
| Cumulative mass residual | -1.52×10⁻¹² m³ | -4.99×10⁻¹³ m³ |
| Relative cumulative residual | 1.52×10⁻¹² | 4.99×10⁻¹³ |
| DRN budget versus conductance law, max error | 7.11×10⁻¹⁵ m³/day | 7.11×10⁻¹⁵ m³/day |

The default research coupling threshold was 1×10⁻¹⁰ m/s. The 2×10⁻¹⁵ m/s sensitivity above uses the same 50 cells, storage partition, initial condition, forcing, timestep sequence and MODFLOW settings. It shows that this linear dummy response can satisfy the C2B diagnostic threshold without demanding it as a general production setting.

The transient profile rises from the drain toward the right no-flow boundary, and then recedes. It is qualitatively consistent with the existing standalone strip oracle's mound direction. The standalone 50-cell oracle reports about 0.469 m for its steady distributed-recharge case; that value is not a point-for-point target here because C2D is a 30-day transient with recharge passing through a top-system storage response. No steady-state equivalence is claimed.

## A/B diagnosis and claim ceiling

C2B has the same horizontal mapping, initial head, drain stage/conductance, Kx and IMS controls. Its real SWAP/Richards route rejects an ordinary 0.001-day target-rain window. Its zero-seed forcing ramps under smaller windows still stop far below the 0.1 cm/day target, with later failure attributed to Richards transaction progress. C2D publishes the target 0.1 cm/day recharge for 20 days and a 10-day recession, including at the same 2×10⁻¹⁵ m/s diagnostic coupling criterion. It produces measurable lateral groundwater flow and drain discharge while closing the complete-domain ledger.

This strongly supports the interpretation that the observed C2B forcing blocker lies in the real SWAP/Richards predictor-corrector or its transaction execution, rather than in the shared application-service iteration and MODFLOW strip response tested here. It also shows that physically meaningful lateral response and a unique drain owner can be exercised without Richards.

The dummy participant itself is a research-only Python implementation of the service port. The F-GC49D native participant registry, real SWAP state publication and its production interface ledger are not exercised by C2D. Thus the result does **not** prove every production MultiSWAP registry/topology path, admit physical aquifer storage or drainage, qualify Hupsel, or establish a calibrated field model. C2D is qualified only for this analytic 50×1 service/MODFLOW research trajectory and its declared disjoint storage partition.

The dummy response and ownership decisions draw on the existing DSW materials at the pinned dummy-bank head. That branch's aggregate preserved research run records qualification through DSW20; later DSW23–25 records are used here as analytical/oracle design references where their own status still says preservation or live evidence is pending. This closeout does not relabel them.

## Persisted artifacts

- Preregistration: `integration/f-gc/strip01/F-GC-STRIP01_C2D_PREREGISTRATION.json`
- Strict-threshold addendum: `integration/f-gc/strip01/F-GC-STRIP01_C2D_PREREGISTRATION_ADDENDUM.json`
- C2B alignment addendum: `integration/f-gc/strip01/F-GC-STRIP01_C2D_PREREGISTRATION_ALIGNMENT_ADDENDUM.json`
- Machine summary and replay hashes: `integration/f-gc/strip01/results/c2d-local/summary.json`
- Per-window head, flux and mass records: the compressed JSON traces indexed in `summary.json`
- Profile figure: `integration/f-gc/strip01/results/c2d-local/profiles.svg`
- Rerun harness: `tests/fgc/strip01/run_dummy_strip_local.sh`
