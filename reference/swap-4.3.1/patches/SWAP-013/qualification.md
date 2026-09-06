# SWAP-013 qualification evidence

Current B1 admission status: **ADMITTED IN B1.8**

## Audit evidence

The central issue register records SWAP-013 as `FIX_TESTED`, very-high certainty and high severity. The earlier audit patch compiled and the hydraulic test set passed. The audit note identifies the exact singular input examples: `HA=0` can reach `log10(0)`, while `HA=H0` makes the logarithmic denominator zero.

## Exact source/provenance gate

```text
target
SWAP/readswap.f90

canonical B0 SHA-256
3ab42ae4ad9a76d96b01d90b173cf821a9add8514620a965bf31eaf874405cf2

ordered B1.7 preimage SHA-256
3ab42ae4ad9a76d96b01d90b173cf821a9add8514620a965bf31eaf874405cf2

stored fix.patch SHA-256
066c1c1aba8f32cb3a9aab3d17f1900b0ba8a28f43173d80461c91fb1a8f25f3

corrected target SHA-256
e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c
```

B1.1–B1.7 do not modify `readswap.f90`; therefore the ordered B1.7 preimage equals the canonical B0 member. `apply_and_verify.py` checks that equality, requires exactly one target block and verifies the corrected byte identity.

The correction adds 402 bytes to `readswap.f90` and no other legacy source member changes.

## Placement/source-binding gate

The stored patch is checked for the following order:

```text
read HA
convert HA to positive magnitude
PDI model 8..11 guard
0 < HA < H0 relational test
read APAR
```

Thus the predicate operates on the same positive magnitudes used by the downstream PDI functions, and it executes before further PDI constitutive parameters are accepted.

## Fresh compiled predicate gate

A focused GNU Fortran 14.2.0 harness uses the exact predicate in the stored patch and is compiled with:

```text
-std=f2018 -O0 -Wall -Wextra -Werror
-fcheck=all -ffpe-trap=invalid,zero,overflow
```

Test matrix:

```text
model 8   HA=1e4      H0=1e6   accept
model 9   HA=1        H0=1e5   accept
model 10  HA=99999    H0=1e5   accept
model 11  HA=1e-30    H0=1e5   accept
model 8   HA=0        H0=1e5   reject
model 8   HA=1e5      H0=1e5   reject
model 11  HA=2e5      H0=1e5   reject
model 7   HA=0        H0=1e5   unaffected
model 12  HA=0        H0=1e5   unaffected
```

Fresh local result:

```text
GNU Fortran 14.2.0
SWAP-013_GUARD_HARNESS PASS 9/9
```

The same harness is part of the corrected-reference CI gate. `run_guard_gate.py` also independently verifies that `log10(0)` is outside the real domain and that `log10(HA)-log10(H0)` is exactly zero at equal positive values.

## Behavioural envelope

Expected difference from B1.7:

- PDI model 8–11 inputs with `HA <= 0` after magnitude conversion or `HA >= H0` are rejected at input validation;
- valid PDI inputs satisfying `0 < HA < H0` are accepted by the new guard;
- non-PDI models are not subjected to this relational guard;
- no retention, capacity, conductivity, solver or mass-balance equation changes.

A successful model run with previously valid input is therefore not expected to change numerically because of SWAP-013 itself.

## Mass-conservation interpretation

SWAP-013 acts before time integration on invalid input. A rejected invalid configuration has no accepted physical trajectory for which water balance can be traded or relaxed. For valid configurations the physical and numerical equations are byte-identical to B1.7. Consequently this admission introduces no mass-balance exception or tolerance change.

## Qualification boundary

This gate does not decide broader PDI behavior outside the dry boundary H0 and does not clamp constitutive outputs. Those are separate scientific/model-domain questions and are explicitly outside SWAP-013.

B1.8 deterministic source identity:

```text
members          63
source bytes      1,860,493
manifest SHA-256  e32395a6dc1c4ad0caa551739c411669f0b51117dcf68ba719cad75a82fbdcae
```

B1.8 admission is represented by the immutable snapshot/manifest and remains integrated repository state only after the admission PR passes CI and is merged to `main`.
