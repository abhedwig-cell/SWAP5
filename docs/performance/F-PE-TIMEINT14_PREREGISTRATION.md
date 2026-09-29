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


## P0 exact operator reconstruction

Define soil storage (S_n), ponding storage (P_n), accepted-step duration (h_n=t_{n+1}-t_n), and net external soil-water flux rate (F), positive into the soil control volume. Source/sink terms are included in (F) with the same sign convention. The transaction ledger remains a separate physical statement over one accepted interval.

### BE / KLAG

For one-step backward Euler with conductivity lagging only in the spatial constitutive evaluation, the storage operator is

`S_(n+1) - S_n`.

The solved balance is

`S_(n+1) - S_n = h_n F_(n+1; lagged-K)`

up to solver tolerance.

The physical accepted-interval increment is the same quantity,

`DeltaS_n = S_(n+1) - S_n`.

If the published integrated external mass is the same discrete flux mass used by the solve,

`Q_n = h_n F_(n+1; lagged-K)`,

then the physical interval ledger is

`DeltaS_n - Q_n = 0`

up to the qualified solver/balance tolerance. There is no multistep history term.

### Fully implicit constant-step BDF2

For constant (h),

`1.5 S_(n+1) - 2 S_n + 0.5 S_(n-1) = h F_(n+1; endpoint-K)`.

Equivalently, in physical increments `DeltaS_n=S_(n+1)-S_n` and `DeltaS_(n-1)=S_n-S_(n-1)`,

`1.5 DeltaS_n - 0.5 DeltaS_(n-1) = h F_(n+1; endpoint-K)`.

The ordinary physical interval ledger against the solved endpoint flux mass is therefore

`L_n = DeltaS_n - h F_(n+1)`

`    = -0.5 (DeltaS_n - DeltaS_(n-1))`

`    = -0.5 (S_(n+1)-2S_n+S_(n-1))`.

Thus a nonzero one-step physical ledger is algebraically expected even when the BDF2 residual is solved exactly.

### Predicted/extrapolated-K BDF2

TIMEINT13 changes the conductivity representation in (F), not the BDF2 storage algebra:

`1.5 S_(n+1) - 2 S_n + 0.5 S_(n-1) = h F_(n+1; Kpred)`.

Consequently the same identity holds:

`L_n = -0.5 (S_(n+1)-2S_n+S_(n-1))`

provided the physical ledger publishes the same external flux mass represented by the solved residual.

Therefore the first attribution hypothesis is that the TIMEINT13 O(1e-3..1e-2 cm) signal is primarily the ordinary BDF2 history term, not a conductivity-prediction mass leak.

### Surface reservoir

If ponding is advanced by an exact one-step surface balance, its physical increment (P_(n+1)-P_n) remains ordinary one-step mass. The BDF2 history correction belongs only to the soil storage operator unless the surface reservoir itself is discretized multistep.

For total physical storage (T_n=S_n+P_n), the expected ledger mismatch is therefore still the soil history term.

### Algorithmic storage and cumulative balance

Define constant-step algorithmic storage

`A_n = 1.5 S_n - 0.5 S_(n-1) + P_n`.

Then the BDF2 soil residual plus the one-step surface balance imply

`A_(n+1)-A_n = Qexternal_n`

up to solver tolerance.

This telescopes exactly in (A), but (A_n) is not physical water storage. Replacing (S_n+P_n) by (A_n) in transaction publication would therefore change the mass contract rather than satisfy the existing one.

The cumulative ordinary physical ledger over steps 1..N is not generally zero either. The history corrections telescope only to an endpoint increment term:

`sum_n L_n = -0.5 (DeltaS_N - DeltaS_bootstrap)`

for the constant-step BDF2 segment. This is an O(h) boundary remainder for smooth solutions, not an exactly cancelling physical mass.

## P1 frozen candidate set

No additional candidate class is to be introduced after result exposure unless separately preregistered.

### Candidate A — increment-form BDF2

Algebraically solve BDF2 for the current physical increment:

`DeltaS_n = (2/3) h F_(n+1) + (1/3) DeltaS_(n-1)`.

Interpretation:

- `DeltaS_n` is physical storage change;
- the second term is numerical history;
- if used as a published interval inflow/outflow, one third of the previous interval mass is reassigned to the current transaction.

Gate:

Candidate A is admissible only if the current interval can be represented using current-interval physical boundary/source quantities without importing prior accepted-interval mass into the published ledger. Otherwise reject as transaction-lineage incompatible even though the algebra is exact.

Formal-order expectation: second order as the same BDF2 endpoint equation.

Work expectation: no nonlinear-work increase.

### Candidate B — unchanged BDF2 endpoint plus reconstructed physical interval flux

Define a reconstructed current-interval mass

`Qphys_n = DeltaS_n`

or equivalently

`Qphys_n = h F_(n+1) + 0.5(DeltaS_n-DeltaS_(n-1))`.

This closes the interval ledger by construction.

Interpretation:

- the added term is explicitly numerical history correction;
- it is not an observed or independently quadrature-derived external physical flux.

Gate:

Reject as a physical-flux publication method unless the correction can be derived from a second-order quadrature of current-interval boundary/source rates only. Exact equality obtained solely by copying the storage increment is insufficient because it destroys independent mass-accounting meaning.

Formal-order expectation: endpoint order unchanged.

Work expectation: negligible.

### Candidate C — second-order physical flux/source quadrature

Seek an interval quadrature (Q_n) built from boundary/source rates belonging to the current interval, with second-order truncation error, and require simultaneously

`DeltaS_n = Q_n`

within existing mass authority.

For an unchanged BDF2 endpoint equation, any such (Q_n) must also be algebraically consistent with the BDF2 derivative. The test is whether a local current-interval quadrature exists without history-mass reassignment.

Gate:

- physical terms only;
- no hidden storage-derived correction;
- per-interval ledger passes existing tolerance;
- second-order convergence retained;
- no material work penalty.

If no such quadrature exists for unchanged BDF2, Candidate C closes negative for BDF2 rather than being rescued empirically.

### Candidate D — explicit numerical history debt

Track

`H_n = A_n - (S_n+P_n)`

as a numerical temporal state separate from physical storage.

The algorithmic identity becomes

`(S_(n+1)+P_(n+1))-(S_n+P_n) + (H_(n+1)-H_n) = Qexternal_n`.

Interpretation:

- physical mass remains (S+P);
- (H) is nonphysical temporal debt;
- transaction publication must never label (H) as water.

Gate:

Candidate D is compatible with the current physical interval mass contract only if the physical ledger itself still closes without moving (H) into physical in/out. If the only exact identity requires adding (Delta H), classify the current contract as incompatible with BDF2.

Formal-order expectation: unchanged BDF2 order.

Work expectation: negligible, but transaction/checkpoint state expands if ever admitted.

## P1 decision rule

A mathematically exact multistep identity is not sufficient for admission. TIMEINT14 requires exact or authority-level closure of the existing physical accepted-interval ledger using physical current-interval flux/source mass.

If P0 confirms the history identity and A-D cannot meet that condition without relabeling numerical history as physical mass, TIMEINT14 closes:

`CLOSED_BDF2_INCOMPATIBLE_WITH_INTERVAL_MASS_CONTRACT`.

A successor may then test a conservative second-order one-step formulation, for example trapezoidal/Crank-Nicolson-type storage-flux integration with predicted conductivity, but that is outside TIMEINT14 unless separately preregistered.
