# A23BU — Irrigation process continuation minimization

Status: `PASS_IRRIGATION_CONTINUATION_MINIMIZATION / EVENT_WORKSPACE_RECONSTRUCTIBLE / LEGACY_EVENT_GLOBALS_REMAIN_SERIAL_BACKEND`

## Scope
A23BU refines the A23BT Hupsel transaction adapter without changing physical formulas or solver policy. The irrigation process state is split by lifetime:

- persistent per-column continuation: `nirri`, `dayfix`;
- immutable model configuration: irrigation enabled, crop-calendar enabled;
- reconstructible per-attempt/day event workspace: `irrigevent`, `gird`, `isua`, `cirr`, `nird`, `dt_irr_event`, `qssdi(:)`, `qssdisum`.

The event workspace is explicitly normalized before each trial and then rebuilt by the existing B1.6 irrigation/day-start logic. It is therefore not stored in the persistent column state for the qualified whole-day Hupsel route.

## Why `nirri` remains state
The qualification case has a fixed irrigation event on 2002-01-05. The committed seed before that event has `nirri=1`. A negative-control run deliberately changes only this cursor to `nirri=2`.

- reference accepted storage: 7.7011710672204643E+01 cm
- bad-cursor storage: 7.4955096165939139E+01 cm

The endpoint changes materially, so the fixed-irrigation cursor is genuine physical continuation state and must participate in checkpoint/rollback/commit.

`dayfix` is retained because it is the scheduled-irrigation progression cursor. The Hupsel fixed-irrigation reference does not exercise its scheduled mode, so A23BU does not claim a dynamic scheduled-irrigation qualification for `dayfix`.

## State reduction
A23BT process cursor payload: 36 B/column.
A23BU process cursor payload: 8 B/column.
Reduction: 28 B/column (77.8%). At 100,000 logical columns that avoids 2.8 MB of unnecessary persistent process state for this representation.

## Physical qualification
O0 and O2 physical gate logs are byte-identical.

- full B1.6 endpoint SHA256: `4b77a52ca7c48a59a057dec036f596a8da4ebc9ede9296f7d3b36dcff528bfb9`
- physical gate log SHA256: `416b78c4bf1a4840b4e0e0c03b198e91cab20583ca9f1054961e2f0edd4f3347`
- accepted storage: 7.7011710672204643E+01 cm
- half-route mass residual: -1.7872350177583485E-07 cm
- hard B1.6 mass limit: `1e-6 cm`
- total / accepted internal retries: 20 / 10
- total / accepted Newton iterations: 956 / 478
- total / accepted HeadCalc calls: 162 / 81
- total / accepted Jacobian builds: 956 / 478
- total / accepted linear solves: 956 / 478
- total / accepted backtracking attempts: 1350 / 675

The full `jacobian_F()` block is byte-identical to A23BT: `9ba4ada31fe629a006d47f30d77b8c6f8a200b232a91483b31735a6b53fb38cb`.

## Isolation gates
`A23BU_PROCESS_EVENT_WORKSPACE_POISON PASS` deliberately contaminates legacy irrigation activation/event variables and then executes logical columns in interleaved order. Both physical state and diagnostics reproduce their independent serial references exactly.

Generic transaction regression: `8364385f32219a588fa7b04d776f07732cb13de9f08e4eb6e95a1a0a5abf9548` (O0/O2 identical).
Worker-context gate: `3f01cf842699ad711a2d73e3c3d167dcac7adc40a8e4f4deb01e047a6bc05b37`; 8 workers x 1000 checks = 8000 checks, 0 failures.

## Boundaries / holds
- The B1.6 physical backend is still serialized; irrigation event variables still exist as legacy module globals during execution.
- A23BU proves those event globals do not need to be persistent column continuation state at qualified whole-day boundaries; it does not yet make the irrigation backend thread-safe.
- Scheduled irrigation logic is not dynamically qualified by this Hupsel period.
- Sub-day transaction boundaries crossing an irrigation event are not yet qualified.
- Crop/WOFOST continuation state is not part of A23BU.
- Selective step-doubling and top-Jacobian formulas are untouched.

## Architecture invariants
A23BU directly advances invariants 3, 4, 7, 8, 13, 16, 23, 27 and 30. It also keeps the kernel I/O-independent; legacy files remain adapter/VQ concerns.
