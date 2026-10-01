# PPA-WU05-PERCH19 source map — exact B1.11 FrReduQ continuation

Date: 2026-10-01

Status: `EXACT_SOURCE_MAP`

Authority:
exact SWAP 4.3.1 source from the user-supplied distribution.

## Source variables

`variables.f90`:

- `FlDecMpRat`: retry flag for reduced macropore exchange;
- `IDecMpRat`: reduction level;
- `dtold`: previous/recovery timestep.

`headcalc.f90` also owns saved local `NStep`, the accepted-step recovery counter.

## Rate mapping

`macrorate.f90`:

`FrReduQ = 0.1d0 ** dble(IDecMpRat)`.

The same factor is applied to the admitted macropore exchange branches, including:

- saturated exchange;
- unsaturated absorption;
- rapid drainage.

## Failure transition

When HeadCalc cannot converge:

- if `fldtmin = false`, normal timestep reduction is requested first;
- otherwise, with macropores active and `IDecMpRat < 3`:
  - `IDecMpRat += 1`;
  - `FlDecMpRat = true`;
  - `dtold = dt`;
  - `fldtmin = false`.

Then `TimeControl(5)` sees `FlDecMpRat` and sets:

`dt = sqrt(dtmin * dtmax)`.

Thus source behavior is not “hardcode factor 0.1” and not “always reduce flux before
reducing dt”.

## Accepted-step recovery

On convergence, HeadCalc:

- clears `FlDecMpRat`;
- when `IDecMpRat > 0`:
  - increments `NStep` while below 10;
  - if `dt > dtold` or `NStep >= 10`:
    - `dtold = dt`;
    - `NStep = 0`;
    - `IDecMpRat -= 1`.

Recovery is therefore gradual and persists across accepted timesteps.

## Typed SWAP5 ownership

The source state separates naturally into numerical continuation:

- `reduction_level` <-> `IDecMpRat`;
- `accepted_step_count` <-> `NStep`;
- `recovery_dt` <-> `dtold`.

`FlDecMpRat` is a transient retry action/result and need not be committed.

The factor is derived from the committed/candidate level and is not itself persistent.

This continuation is numerical policy. It is not part of the physical seven-field
macropore state.

## Deterministic initialization

Exact source declares saved local `NStep` without an explicit initializer.

SWAP5 will initialize the typed counter to zero. This is a deterministic portability
repair matching the observed static-runtime behavior; it is not a new physical model
choice.
