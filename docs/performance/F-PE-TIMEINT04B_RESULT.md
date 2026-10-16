# F-PE-TIMEINT04B result — BDF2 representation-aware total balance floor

Date: 2026-09-28

Status: `BDF2_MECHANISM_QUALIFIED_WITH_REPRESENTATION_AWARE_TOTAL_FLOOR`

Authority:

- canonical base: `integration/f-ci-canonical@bd9a3fcc54000b9cdafee77f4a20e739a5abfaf2`;
- Actions run: `36446025738`;
- qualification job: `109008425370`;
- conclusion: SUCCESS.

## Candidate

Only for test-only BDF2 mode, the scalar total-balance convergence criterion used:

`effective_total = max(configured_total, bdf2_total_floor)`

with:

`bdf2_total_floor = sum_i 0.5 * dz_i/dt * (1.5 spacing(theta_np1_i) + 2 spacing(theta_n_i) + 0.5 spacing(theta_nm1_i))`.

No local balance, head, ponding, Newton, Jacobian, conductivity, mass or forcing rule changed.

## Qualification result

BDF2_KIMPL_FLOOR:

- complete ladders: 4/4;
- refined top-head orders:
  - B01, 2 cm/day: 2.0488;
  - B01, 4 cm/day: 2.0462;
  - O05, 2 cm/day: 2.0730;
  - O05, 4 cm/day: 2.0551;
- median refined order: 2.0519;
- 4/4 orders >=1.5.

The previously missing B01 / 4 cm/day / dt=0.00125 d run completes.

## Performance

Median deterministic work per step:

- BE_KIMPL: 16.1875;
- BDF2_KIMPL_FLOOR: 16.0.

Ratio:

`0.9884`.

Thus the qualified BDF2 mechanism does not carry a material per-step work penalty in this smooth fixed-flux bank.

## Preservation

All 15 points that already completed under baseline BDF2 remain numerically identical to very tight bounds.

Maximum candidate-minus-baseline endpoint differences:

- top head: about 2.27e-13 cm;
- middle head: about 1.42e-13 cm;
- bottom head: about 1.99e-13 cm;
- terminal storage: about 7.11e-15 cm.

The BE route was exercised with the test-only floor switch off and on.

Result:

`BE_PRESERVED_EXACTLY = true`.

No BE endpoint or work-index difference was observed.

## Interpretation

The missing BDF2 completion was caused by applying a total-balance convergence discriminator below the finite-representation resolution of the three-level BDF2 storage term.

Once that distinction is respected, fully implicit BDF2:

- completes the full smooth qualification matrix;
- exhibits the expected second-order convergence;
- preserves existing successful endpoints to roundoff;
- has essentially the same deterministic work per step as fully implicit Backward Euler.

## Decision

Classification:

`BDF2_MECHANISM_QUALIFIED_WITH_REPRESENTATION_AWARE_TOTAL_FLOOR`.

This is research mechanism qualification only.

It does not production-admit:

- BDF2;
- SWKIMPL=1;
- the BDF2 total floor;
- variable-step BDF2;
- dynamic-top BDF2;
- a new automatic timestep controller.
