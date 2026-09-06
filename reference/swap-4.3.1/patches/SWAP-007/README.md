# SWAP-007: oxygenstress Newton overflow guard

B1 status: **ADMISSION CANDIDATE**

Audit status: **FIX_TESTED**

## Defect

In B0 `oxygenstress.f90`, the Newton update only checks whether `fi_a` is exactly nonzero before evaluating `fi/fi_a`:

```fortran
if (dabs(fi_a) > 0.d0) then
    lnew = dabs(l - (fi / fi_a))
end if
```

A tiny but nonzero derivative can therefore make the quotient overflow. Under strict floating-point traps the supplied grass case reproducibly stops with `SIGFPE` at `oxygenstress.f90:849`.

## Correction

The division is performed only when the quotient is representable. Otherwise `lnew` is set to a very large value, which is handled by the existing restart logic:

```fortran
if (dabs(fi_a) > dmax1(tiny(1.0d0), dabs(fi)/huge(1.0d0))) then
   lnew = dabs(l - (fi / fi_a))
else
   lnew = huge(1.0d0)
end if
```

## Exact identities

```text
B0 file: SWAP/oxygenstress.f90
B0 SHA-256: 2db206bf28e883a22a1419d4729e03c1bb6b9c6bcf560d2221248f3b12f75
B0 bytes: 63565

minimal fix.patch SHA-256:
e65b703b73b530915414265c3b647a403f995adc568390ed5da4ecb55be75b96

corrected oxygenstress.f90 SHA-256:
8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87
corrected bytes: 63738
```

The patch is the isolated SWAP-007 hunk from the audited `SWAP_4.3.1_proposed_fixes.patch` and is checked against the byte-exact B0 preimage.

## Qualification

The audit records the defect as `FIX_TESTED`, confidence high, severity medium. The original strict-FPE grass run crashes at the identified oxygenstress line, while the patched strict run completes normally. A normal original-versus-patched grass run produced identical `result_output.csv` after neutralizing only the generated timestamp.

## Classification

- implementation/numerical robustness defect: yes
- physics/model change: no
- normal-path result change demonstrated: no
- expected B0-to-B1 difference: pathological tiny-derivative cases are routed into the pre-existing restart mechanism instead of overflowing
- mass-balance concession: none
