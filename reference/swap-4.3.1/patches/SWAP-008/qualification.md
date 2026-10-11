# SWAP-008 qualification

## Audit evidence

The central SWAP 4.3.1 issue register classifies SWAP-008 as `FIX_TESTED`, certainty **very high**, severity **medium**, and recommends it as a safe portability fix.

Recorded evidence:

```text
bandec/banbks INTENT correction compiled/tested in the patch set
TRIDAG main solver: 500 random systems solved near machine precision
```

The technical audit separately establishes the language-semantics defect: `bandec` reads `a` and `banbks` reads `b` even though those dummies are declared `INTENT(OUT)`. Under Fortran semantics those incoming values are undefined at procedure entry.

The audit did not claim a specific hydrological output discrepancy caused by this defect. The correction is therefore qualified as a formal Fortran correctness and compiler-portability repair, not as a new numerical method.

## Current B1 provenance verification

```text
SWAP/tridag.f90 B0 SHA-256
6aa6bb863ec296f47afda35a9871b16105087d0eed485e37f13f5f5cdad96651

B0 bytes
6862

exact target declaration occurrences in B0
bandec a/al declaration: 1
banbks b declaration: 1

minimal patch SHA-256
8f97ff20e63a7765bfe8e225e2682029bafadc0eeb80ad0e4ce1564fb8c94f4c

patched file SHA-256
87b9b1cd6de65e6ee1d7c1775cddff6093c12d4d0744ffcde70844f5f28c6e7a
```

`apply_and_verify.py` enforces the exact B0 preimage and raw CRLF byte sequences before creating the corrected file.

## Acceptance reasoning

The correction changes only dummy-argument intent attributes. It does not alter the data values supplied to the routines, the banded LU factorization, pivot logic, forward/back substitution, fallback trigger, timestep controller, physical equations or water-balance accounting.

The correct contract is `INOUT` because the routines both consume incoming array contents and overwrite them with factorization/solution results.

## Qualification conclusion

```text
FORTRAN SEMANTICS DEFECT: PASS
FIX_TESTED AUDIT STATUS: PASS
EXACT B0 PREIMAGE: PASS
MINIMAL PATCH ISOLATION: PASS
BYTE-SAFE PATCH OUTPUT: PASS
MODEL-CHANGE EXCLUSION: PASS
B1 ADMISSION: PASS
```

Scope: this qualification covers only the argument-intent defect in `bandec` and `banbks`. The 500-random-system evidence supports the ordinary TRIDAG solver, but is not presented as a dedicated exhaustive test of every rare band-solver fallback path.
