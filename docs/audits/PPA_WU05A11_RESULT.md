# PPA-WU05-A11 result — source-faithful FMR perched-zone carrier

Date: 2026-10-01

Status: `CORRECTED_IMPLEMENTED / REQUALIFICATION_REQUIRED`

Baseline: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

Corrected code checkpoint: `8ff742c6ba02bce9ecc745e83ef094ab9d5b59c6`

Corrected oracle checkpoint: `463c720e4d56ddd07c80f256cc7f984b26ca86d1`

## Correction

Subsequent A13 investigation re-read the exact SWAP 4.3.1 source and found that the first
A11 source translation was off by one compartment.

The exact active B1.11 assignment is:

`ICpTpPerZon = NPeGwl`

not `NPeGwl + 1`.

The `+ 1` is source comment text, not executable code.

The previously represented optional `ICpSatPeGwl` behavior is likewise historical
commented code. Active SATFLOW instead always applies the perched-level fraction in the top
saturated compartment.

The implementation and source-oracle test have been corrected accordingly.

## Direct corrected evidence

A13 direct runtime probing on the corrected carrier produced:

- perched topology detected = true;
- raw perched interflow amount =
  `5.3846153846153863e-8 cm`;
- limited perched interflow amount =
  `5.3846153846153863e-8 cm`.

This demonstrates that the corrected carrier reaches the A6 `QInIntSat` path.

It is not, by itself, a replacement qualification run for A11.

## Superseded prior qualification

Qualification run `36834246991` is superseded for the corrected carrier because it
tested the earlier off-by-one implementation.

No canonical admission of A11 occurred, so canonical A8/A9/A10 behavior is unaffected.

## Required closure step

Run the corrected focused A11 source/carrier gate, followed by A10 preservation, on one
persisted corrected postimage.

Only after that run is green may A11 return to `QUALIFIED` status.

The frozen Status-A denominator remains unchanged.
