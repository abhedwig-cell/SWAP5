# F-PE-TIMEINT14 preregistration — conservative multistep storage and interval mass contract

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@56a072f6484b8c8dd92e0c72bb2e71ab1d55ed94`

Parent authority:

- TIMEINT13 P0: extrapolated-K BDF2 is near-second-order on the smooth fixed-flux bank with no per-step work penalty versus fully implicit BDF2.
- TIMEINT13 P1: dynamic-top candidate completes 10/12 and has median work ratio about 1.01 versus KLAG, but the ordinary accepted-interval physical ledger is O(1e-3..1e-2 cm) on ponded/head-regime trajectories.
- No production BDF2 admission exists.

## Question

Is the TIMEINT13 ledger mismatch:

1. a real loss of discrete conservation; or
2. the exact algebraic consequence of applying SWAP's one-step physical storage ledger to a BDF2 multistep storage equation?

If it is case 2, what storage/history quantity is actually conserved by BDF2 and can that quantity coexist with SWAP5's transaction mass semantics?

## Constant-step BDF2 identity

For soil-column storage `S_n` and net soil-water flux rate `F_{n+1}`, constant-step BDF2 solves:

`1.5 S_{n+1} - 2 S_n + 0.5 S_{n-1} = h F_{n+1}`.

The ordinary one-step interval residual is:

`L_n = (S_{n+1}-S_n) - h F_{n+1}`.

Algebra predicts:

`L_n = -0.5 (S_{n+1} - 2 S_n + S_{n-1})`.

For dynamic top, the surface reservoir is advanced by its own exact step balance. Therefore the ordinary total-column-plus-ponding ledger should differ from zero by the same soil-storage history term if the BDF2 soil equation itself is conservative.

## Algorithmic conserved storage

For constant-step BDF2 define:

`A_n = 1.5 S_n - 0.5 S_{n-1} + P_n`

where `P_n` is ponded surface storage.

Then, if the soil BDF2 equation and surface balance are both satisfied:

`A_{n+1} - A_n = rain*h - runoff - bottom_outward_exchange`.

This is an exact telescoping discrete balance for the multistep method.

It is not identical to physical storage `S_n + P_n`.

## P0 — attribution

Reuse the TIMEINT13 fixed-dt dynamic-top candidate and record for every completed accepted step:

- physical total ledger already used by TIMEINT13;
- soil storage `S_{n-1}, S_n, S_{n+1}`;
- predicted BDF2 history residual
  `R_hist = -0.5(S_{n+1}-2S_n+S_{n-1})`;
- `physical_ledger - R_hist`;
- algorithmic storage `A_n` and `A_{n+1}`;
- algorithmic interval ledger.

The BE bootstrap step is evaluated separately and must retain the ordinary physical ledger.

## P0 gates

Attribution qualifies only if, for every completed BDF2 step in every completed TIMEINT13 dynamic-top trajectory:

1. `|physical_ledger - R_hist| <= 1e-10 cm`;
2. algorithmic interval ledger <= 1e-10 cm;
3. BE bootstrap physical ledger <= 5e-8 cm;
4. no endpoint, solver control, conductivity prediction or forcing changes are introduced.

If these gates fail, classify the TIMEINT13 mismatch as a genuine unresolved conservation defect.

## P1 — contract consequence

Only if P0 passes.

Document, without changing production contracts, whether the current transaction identity can remain:

`physical_storage_end - physical_storage_start = physical_in - physical_out`

for a BDF2 step whose solved endpoint has nonzero `R_hist`.

The decision is algebraic:

- if `R_hist != 0`, the current exact physical one-step identity cannot hold for the unchanged BDF2 endpoint and unchanged external flux integral;
- exact conservation can instead be stated using algorithmic storage/history debt.

No hidden tolerance relaxation is allowed.

## Stop rule

TIMEINT14 does not silently redefine transaction storage.

If P0 confirms algorithmic conservation but physical interval identity is incompatible, close with an explicit architecture decision and open a successor for a conservative second-order one-step integrator or an explicitly qualified numerical-history mass contract.

## Possible outcomes

- `BDF2_ALGORITHMIC_CONSERVATION_CONFIRMED_PHYSICAL_INTERVAL_CONTRACT_INCOMPATIBLE`;
- `BDF2_PHYSICAL_LEDGER_DEFECT_NOT_EXPLAINED`;
- `BLOCKED_<reason>`.

## Production boundary

No production `src/**` changes.

LEGACY_NUMERICS remains default.
