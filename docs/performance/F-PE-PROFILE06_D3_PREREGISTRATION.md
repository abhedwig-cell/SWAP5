# F-PE-PROFILE06 D3 — difficult live-coupled mapping

Date: 2026-09-26

Status: `PREREGISTERED_OBSERVATION_ONLY`

## D1/D2 basis

D1 exact discovery found several stable difficult direct Reference workloads.

The absolute heaviest case, O14 wet at 0.05 day, required 45 nonlinear iterations and therefore exceeds the current FGC44 fixture's 16-iteration production-shaped cap.

For first coupled mapping select a difficult case that remains inside that cap:

- material: `O05`;
- regime: wet;
- initial pressure head: `-10 cm`;
- top forcing factor: `0`;
- interval: `1e-3 day`;
- exact direct Reference burden: 14 nonlinear/Jacobian/linear iterations;
- mass residual: 0.

## Mapping

Use the existing FGC44 real SWAP + MODFLOW6 architecture.

Change only test-fixture inputs:

- hydraulic material -> O05;
- initial top-node pressure head -> -10 cm with the existing hydrostatic node spacing;
- coupling window -> 1e-3 day;
- predictor qbot -> 0 cm/day;
- top flux -> 0 cm/day.

Keep:

- mode-5 corrector;
- exact production solver/tolerance policy;
- max iterations 16;
- retry policy;
- temporal policy;
- participant/transaction ownership;
- MODFLOW prepared-solve architecture.

No `src/**` changes.

## D3A exact stability gate

Run exact/default first.

Required before any A1/A2C timing:

- configured SWAP initialization succeeds;
- predictor directional response succeeds;
- first corrector succeeds;
- live SWAP + MODFLOW6 converges;
- mass/ledger publication succeeds;
- at least one SWAP corrector trial shows materially more nonlinear work than the trivial two-iteration baseline.

Run at least six independent replicas.

## D3B advancement

Only if exact is 6/6 robust, build the four-arm comparison on exactly the same fixture.

Any change needed to make the candidate converge must be preregistered before testing A1/A2C.
