# SWAP-008: fallback band-solver INTENT correctness

B1 status: **ADMISSION CANDIDATE**

Audit status: **FIX_TESTED**

## Defect

In B0 `tridag.f90`, fallback routines `bandec` and `banbks` declare arrays as `INTENT(OUT)` while immediately reading their incoming contents.

Examples from B0:

```fortran
real(8), intent(out) :: a(np,mp),al(np,mpl)
...
dum = a(k,1)
```

and:

```fortran
real(8), intent(out) :: b(n)
...
dum = b(k)
```

Under Fortran semantics an `INTENT(OUT)` dummy becomes undefined on routine entry. Reading those incoming values is therefore formally invalid and can become compiler/optimization dependent.

## Correction

Change only the arguments whose incoming values are required:

```fortran
real(8), intent(inout) :: a(np,mp)
real(8), intent(out)   :: al(np,mpl)
...
real(8), intent(inout) :: b(n)
```

No arithmetic, pivoting, elimination, substitution or fallback-selection logic is changed.

## Exact identities

```text
B0 file: SWAP/tridag.f90
B0 SHA-256: 6aa6bb863ec296f47afda35a9871b16105087d0eed485e37f13f5f5cdad96651
B0 bytes: 6862

minimal fix.patch SHA-256:
8f97ff20e63a7765bfe8e225e2682029bafadc0eeb80ad0e4ce1564fb8c94f4c

patched tridag.f90 SHA-256:
87b9b1cd6de65e6ee1d7c1775cddff6093c12d4d0744ffcde70844f5f28c6e7a
patched bytes: 6899
```

The patch is the exact SWAP-008 hunk isolated from the audited `SWAP_4.3.1_proposed_fixes.patch` and checked against the byte-exact B0 preimage.

## Classification

- implementation / language-semantics defect: yes
- physics/model change: no
- numerical algorithm change: no
- expected B0-to-B1 difference: removes formally undefined fallback-solver argument semantics; ordinary results need not change on compilers that happened to preserve incoming storage
- mass-balance concession: none
