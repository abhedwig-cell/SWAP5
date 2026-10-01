# PPA-WU05-PERCH19 source map — IDecMpRat / FrReduQ

Date: 2026-10-01

Status: `EXACT_SOURCE_MAP`

Authority: exact SWAP 4.3.1 source from nested source archive SHA-256
`1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

## variables.f90

`MOD_swap_mp` owns:

- `FlDecMpRat`, SAVE logical;
- `IDecMpRat`, SAVE integer initialized to 0.

`variables` owns `dtold`.

## macrorate.f90

Each rate evaluation sets:

`FrReduQ = 0.1d0**dble(IDecMpRat)`.

That factor multiplies:

- saturated matrix/macropore exchange;
- unsaturated absorption;
- rapid drainage.

It is therefore a numerical multiplier over the existing physical rate laws.

## headcalc.f90 — nonconvergence

After exhausting nonlinear iterations:

1. if `.not.fldtmin`:
   - reset trial matrix state;
   - set `fldecdt=.true.`;
   - return;

2. else if macropores active and `IDecMpRat < 3`:
   - `IDecMpRat += 1`;
   - `FlDecMpRat=.true.`;
   - `dtold=dt`;
   - `fldtmin=.false.`;
   - return;

3. otherwise legacy warns and can continue.

PERCH19 replaces item 3 by fail-closed exhaustion.

## timecontrol.f90 — retry timestep

For ordinary `fldecdt`, timestep is reduced toward `dtmin`.

For macropore `FlDecMpRat`:

`dt = sqrt(dtmin*dtmax)`.

## headcalc.f90 — accepted-step recovery

On convergence:

- `FlDecMpRat=.false.`;
- if level > 0:
  - if `NStep < 10`, increment `NStep`;
  - if `dt > dtold` or `NStep >= 10`:
    - `dtold=dt`;
    - `NStep=0`;
    - decrement `IDecMpRat`.

`NStep` is a SAVE local in HeadCalc and is therefore numerical memory.

The source does not explicitly initialize `NStep`; common static-storage runtimes make
it zero in practice. SWAP5 makes the initialization explicit and deterministic.

## Ownership interpretation

Persisted numerical fields:

- reduction level;
- recovery-step count;
- last comparison timestep.

Derived/transient:

- reduction factor;
- escalation action;
- next retry timestep;
- `FlDecMpRat`.

No physical water state belongs in this service.
