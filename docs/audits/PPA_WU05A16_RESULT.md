# PPA-WU05-A16 result — inner-Richards macropore callback prototype

Date: 2026-10-01

Status: `CLOSED_QUALIFIED_INNER_CALLBACK_PROTOTYPE`

Baseline:
`research/ppa-wu05-a15-exchange-derivative@dec0211bbae0a8e57b539cb7a95bf47e3d4ebc54`

Canonical reconciliation:
`integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`.

Qualified postimage:
`dc0e8dec75188dcbeb2fe61ce81ee94965aaa155`.

Qualification run: `36843916653` — SUCCESS.

## Decision

`QUALIFIED_INNER_CALLBACK_PROTOTYPE`

A16 demonstrates that SWAP5 can evaluate macropore exchange inside the explicit
Reference-Richards nonlinear path without giving HeadCalc ownership of persistent
macropore continuation state.

This remains research/prototype scope and is not a production or canonical admission.

## Solver interface prototype

The previously unused `macropore_exchange_provider_t` is extended into two source-order
operations:

1. `evaluate_rate(h,theta,...)`, invoked during `vector_F`;
2. `evaluate_derivative(h,theta,C,...)`, invoked during `jacobian_F`.

The split is intentional and source-faithful.

Current water content is available when the residual is evaluated. Current hydraulic
capacity is guaranteed consistent with the Newton iterate when `jacobian_F` is built.
This mirrors exact B1.11:

- `MACROPORE(2)` / `MACRORATE(1)` for rate;
- `MACROPORE(3)` / `MACRORATE(2)` for derivative.

## HeadCalc ownership

For explicit provider mode:

- legacy `swmacro` remains zero;
- no legacy macropore globals are used;
- provider rate is subtracted exactly once from the matrix residual;
- provider derivative is subtracted exactly once from the Newton diagonal;
- a provider is mandatory when explicit `physical%macropore_active` is requested;
- provider absence leaves the existing explicit Reference-Richards path unchanged.

The generic timestep-constant `source_sink_provider_t` remains untouched.

## G1 — inactive preservation: PASS

The analytical gate compares:

- ordinary explicit Reference-Richards with no macropore provider;
- explicit macropore mode with a provider returning inactive/zero exchange.

Candidate pressure head and water content, top flux and bottom flux are bitwise identical.

Marker:

`PPA_WU05A16_INACTIVE_PRESERVATION=PASS`.

## G2/G3 — current-iterate residual/Jacobian callback: PASS

The analytical provider uses:

`Q_i = lambda * C * dz_i * h_i`

with exact local derivative:

`dQ_i/dh_i = lambda * C * dz_i`.

The known solution is:

`h = h0 / (1 - lambda*dt)`.

Qualification run `36843916653` reports:

- callback calls = 3;
- first current iterate head = `-1.0 cm`;
- last iterate head = `-1.0526315789473681 cm`;
- analytical expected head = `-1.0526315789473684 cm`;
- nonlinear iterations = 2.

The provider therefore sees changing nonlinear iterates rather than a timestep-constant
state, and the residual/Jacobian composition reproduces the analytical solution.

Markers:

- `PPA_WU05A16_CURRENT_ITERATE_CALLBACK=PASS`;
- `PPA_WU05A16_RESIDUAL_JACOBIAN_ANALYTIC=PASS`;
- `PPA_WU05A16_O0_O2_IDENTITY=PASS`.

## G4 — actual A11/A15 provider: PASS

A16 adds a read-only provider adapter over:

- accepted seven-field macropore continuation state;
- immutable geometry/configuration;
- accepted ponding and main-groundwater carrier;
- current nonlinear matrix `h/theta`;
- A6 rates;
- corrected A11 perched carrier;
- qualified A15 derivative.

No rate physics is duplicated.

For the corrected A11 perched fixture, with competing transfer paths disabled, run
`36843916653` reports:

- first iterate summed exchange = `-4.5714285714285721 cm/day`;
- changed-iterate summed exchange = `-6.7777777777777786 cm/day`;
- source-faithful explicit perched derivative = `0`.

Thus the real provider responds to the current nonlinear iterate and reaches the exact
perched `QInIntSat` path that A12/A13 could not retain through outer coupling.

Markers:

- `PPA_WU05A16_ACTUAL_PERCHED_RATE=PASS`;
- `PPA_WU05A16_ACTUAL_DERIVATIVE_SEMANTICS=PASS`.

## G5 — state isolation: PASS

The provider owns a private copy/read-only trial context.

Repeated current-iterate rate and derivative calls leave the external accepted
seven-field macropore continuation state bitwise unchanged.

Marker:

`PPA_WU05A16_ACCEPTED_STATE_ISOLATION=PASS`.

No restart payload or persistent-state schema is added.

## Preservation

The same qualification run passes:

- A15 exact derivative gate;
- corrected A11 perched carrier gate;
- complete A7/A8/A9/A10 admitted macropore preservation gate.

Final preservation marker:

`PPA_WU05A10_RAPID_DRAIN_GATE=PASS`.

## What is still missing

A16 does not yet integrate the actual inner provider into the serialized FMR macropore
transaction path.

Therefore it does not yet prove:

- accepted candidate macropore storage from inner-Richards exchange;
- exact internal matrix/macropore mass cancellation at transaction level;
- reject/discard/replay with the inner callback active;
- restart after an accepted inner-callback interval;
- top-input and rapid-drain composition in the same active inner-callback transaction;
- production or canonical admission.

The provider currently uses accepted ponding and accepted ordinary-groundwater carrier
while receiving current `h/theta`. This is consistent with the bounded perched
prototype/source ordering but must be reviewed explicitly before broader surface/main-GWL
production scope.

## Next safe step

Open **PPA-WU05-A17 — serialized inner-callback transaction integration**.

A17 should:

1. bind the A16 provider inside the existing serialized FMR trial;
2. remove the outer macropore fixed-point loop for this explicit inner-callback route;
3. obtain the converged final A6 rate receipt at the accepted matrix state;
4. build the macropore candidate exactly once from that receipt;
5. prove internal mass cancellation;
6. prove reject/replay and restart;
7. preserve A8-A10 when inner callback is disabled.

Only after those gates pass should a production-admission candidate be considered.

The frozen Status-A denominator remains unchanged.
