# PPA-WU05-A11 source map — exact 4.3.1 perched groundwater carrier

Date: 2026-10-01

Status: `CORRECTED_EXACT_SOURCE_MAP / REQUALIFICATION_REQUIRED`

Baseline: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

Corrected implementation checkpoint: `8ff742c6ba02bce9ecc745e83ef094ab9d5b59c6`

## Exact source recovery

The user supplied `SWAP_4.3.1.zip` directly in this workunit.

The nested source archive is byte-exact with A1 authority:

- path: `SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP`;
- bytes: 411,215;
- SHA-256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

Relevant exact members:

- `SWAP/macropore.f90`: SHA-256
  `1cb5a2ce30610c05a4da5655bff217d6f52052d57d99efe8af7928f1d2187d0b`;
- `SWAP/macrorate.f90`: SHA-256
  `537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7`;
- `SWAP/calcgwl.f90`: SHA-256
  `d7649f02bf6cd629cc7eceb1c761a6c38d6f0adf0d0c072c7aaab3af4562f5eb`.

## CALCGWL perched-zone construction

After the ordinary groundwater table has been identified, CALCGWL searches upward from
the main groundwater zone for a saturated compartment above an under-saturated separator.

The `watertable` helper accumulates:

`TotUndSatVol += max(0, ThetaS - Theta) * dz`.

The under-saturated interval is a real separator when the accumulated deficit reaches the
source criterion. Otherwise the search bridges that interval and continues upward.

The perched top and bottom levels are reconstructed with the source zero-pressure-head
interpolation and `nodlev` mapping.

## Corrected exact MACRORATE mapping

A13 source reinspection found an error in the first A11 transcription.

The **active** B1.11 code is:

`ICpTpPerZon = NPeGwl`

The visually adjacent `+ 1` is after the Fortran comment marker `!` and is therefore
not executable source.

Likewise the historical `ICpSatPeGwl` alternatives in this source block are commented
out and must not be represented as active B1.11 logic.

Therefore, when `NPeGwl > 0`:

- `ICpBtPerZon = BPeGwl`;
- `ICpTpPerZon = NPeGwl`.

When no perched groundwater exists:

- `ICpBtPerZon = -1`;
- `ICpTpPerZon = ICpTpSatZon`.

## Exact SATFLOW top fraction

The active SATFLOW loop starts at `CpTpZon`.

For that top saturated compartment it always multiplies the resistance/conductance term
by the fraction:

`(Lev - (Z(ic) - 0.5*DZ(ic))) / DZ(ic)`.

Thus the active B1.11 source always applies the `PeGwl`-derived matrix saturation
fraction in the top perched compartment. There is no active current-source switch that
turns that fraction off for a fully saturated top compartment.

## Corrected A11 oracle

For the six-node source fixture used by A11:

- with `CritUndSatVol = 0.005 cm`, corrected perched bounds are compartments **3..4**;
- with `CritUndSatVol = 0.02 cm`, corrected perched bounds are compartments **2..4**.

The perched water-level and bottom-level interpolation values remain unchanged from the
previous oracle; the correction is the source-exact compartment mapping and top-fraction
semantics.

## Runtime representation

A11/A13 now represents the exact source mapping as a recomputable hydraulic view:

- active flag;
- source-exact top compartment;
- bottom compartment;
- perched water level;
- bottom level;
- top fraction active for SATFLOW.

No new persistent state is introduced.

The existing A6 contracts remain the owning rate layer:

- perched exclusion from unsaturated absorption;
- `QInIntSat` via the existing SATFLOW evaluator;
- internal matrix/macropore mass ownership unchanged.

## Superseded evidence

The earlier A11 qualification run `36834246991` was green against the first
implementation, but that implementation contained the off-by-one top-node transcription
described above.

That run is therefore superseded for the corrected perched carrier. A fresh corrected A11
qualification is required before the carrier is again labelled qualified.

The frozen Status-A denominator and canonical A8/A9/A10 envelope are unchanged.
