# SWAP-005: crop-calendar bounds/portability defect

B1 status: **ADMISSION CANDIDATE**

Audit status: **FIX_TESTED**

## Defect

B0 checks crop sequencing with this compound expression:

```fortran
if ((cropstart(i+1) - cropend(i)) < 0.5d0 .AND. i < ifnd) then
```

Fortran does not guarantee short-circuit evaluation of `.AND.` operands. Therefore `cropstart(i+1)` may be evaluated before `i < ifnd` has excluded the final record. The code is consequently dependent on evaluation order and on what lies beyond the active crop-calendar range.

## Correction

Make the index bound an explicit control-flow guard before accessing `i+1`:

```fortran
if (i < ifnd) then
   if ((cropstart(i+1) - cropend(i)) < 0.5d0) then
      ...
   end if
end if
```

The crop-sequence criterion itself is unchanged.

## Exact identities

```text
B0 file: SWAP/MOD_cropdevelopment.f90
B0 SHA-256: c2df137291357553541d4d7026b8859242c32565affe173c66a685d565190ccf
B0 bytes: 81873

minimal fix.patch SHA-256:
9c3839ac0674d7c5c3eb2de797684c7baf83fdc3a18d64de68c9746de9878e66
```

The minimal patch is isolated from the exact SWAP-005 hunk in the audited `SWAP_4.3.1_proposed_fixes.patch`; unrelated historical changes are not admitted.

## Qualification

The central issue register records SWAP-005 as `FIX_TESTED`, certainty very high, severity medium. The strict build passes with the nested-bound form. The audit note classifies this primarily as a portability/bounds fix and explicitly states that there is no evidence that common official builds already produced wrong normal results because of it.

## Classification

- implementation/Fortran portability defect: yes
- physical model change: no
- crop-calendar criterion changed: no
- expected B0-to-B1 difference: the final active crop record can no longer trigger an out-of-range/sentinel-dependent `cropstart(i+1)` evaluation
- mass-balance concession: none
