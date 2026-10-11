# SWAP-013 — PDI HA/H0 input-domain validation

Status: **ADMITTED IN B1.8**

## Defect

For PDI hydraulic models 8–11, `readswap.f90` reads negative `H0` and `HA` values and immediately converts them to positive magnitudes. B0 accepts `HA=0` and permits the converted `HA` to equal or exceed `H0`.

The downstream PDI formulation uses `log10(HA)` and a denominator involving `log10(HA)-log10(H0)`. Therefore `HA=0` is outside the logarithm domain and `HA=H0` makes the denominator zero.

The audit issue register classifies this as `FIX_TESTED`, very-high certainty and high severity. The historical patch was compiled and its hydraulic tests passed.

## Minimal correction

After the existing `H0`/`HA` sign conversion and before subsequent PDI parameters are read, reject only PDI layers that violate:

```text
0 < abs(HA) < abs(H0)
```

No valid PDI constitutive formula is changed. Models outside 8–11 are not subject to this guard.

## Exact identity

```text
target
SWAP/readswap.f90

canonical B0 SHA-256
3ab42ae4ad9a76d96b01d90b173cf821a9add8514620a965bf31eaf874405cf2

ordered B1.7 preimage SHA-256
3ab42ae4ad9a76d96b01d90b173cf821a9add8514620a965bf31eaf874405cf2

fix.patch SHA-256
066c1c1aba8f32cb3a9aab3d17f1900b0ba8a28f43173d80461c91fb1a8f25f3

corrected target SHA-256
e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c
```

`readswap.f90` was not changed by B1.1–B1.7, so the ordered B1.7 executable preimage equals canonical B0 for this target. The equality is explicit rather than assumed.

## Qualification boundary

The correction changes accepted-input behavior for mathematically singular PDI combinations only. Valid PDI input and all non-PDI input remain in the previous domain. It changes no SWAP5 production code, no constitutive equation, no solver policy and no water-balance tolerance.

See `qualification.md`, `ADMISSION_CHECKLIST.md`, and immutable snapshot `reference/swap-4.3.1/snapshots/B1.8.yml`.
