# SWAP-005 qualification

## Audit evidence

The central SWAP 4.3.1 issue register records:

```text
ID: SWAP-005
component: crop calendar
category: bounds/portability
status: FIX_TESTED
certainty: very high
severity: medium
source: MOD_cropdevelopment.f90:232
proposed fix: nest if(i<ifnd) before accessing i+1
test evidence: strict build passes
upstream advice: submit safe fix
```

The audit technical note separately explains the Fortran-language basis: evaluation of both operands of `.AND.` cannot be relied upon to short-circuit, so the final active crop record must not protect `cropstart(i+1)` through operand ordering alone.

## Patch provenance

The exact SWAP-005 hunk is present in the audited combined file `SWAP_4.3.1_proposed_fixes.patch`. The B1 `fix.patch` contains only that hunk.

B0 source identity:

```text
SWAP/MOD_cropdevelopment.f90
SHA-256 c2df137291357553541d4d7026b8859242c32565affe173c66a685d565190ccf
size 81873 bytes
```

Minimal isolated patch identity:

```text
SHA-256 9c3839ac0674d7c5c3eb2de797684c7baf83fdc3a18d64de68c9746de9878e66
```

`apply_and_verify.py` first checks the exact B0 file hash, then requires exactly one occurrence of the original three-line target before applying the five-line nested replacement while preserving the existing newline convention.

## Behavioural scope

The sequence check itself remains:

```text
cropstart(i+1) - cropend(i) < 0.5 d
```

Only the order in which the array bound is enforced changes. For `i < ifnd`, the same test and same error call are executed. For `i == ifnd`, B1 does not evaluate `cropstart(i+1)`.

No crop physics, phenology, water balance, forcing interpretation, solver path or state definition is changed.

## Qualification conclusion

```text
BUG_CONFIRMED: PASS
FIX_TESTED audit status: PASS
EXACT B0 PREIMAGE PINNED: PASS
MINIMAL PATCH ISOLATED: PASS
STRICT BUILD EVIDENCE: PASS
MODEL-CHANGE EXCLUSION: PASS
B1 ADMISSION: PASS
```

The scope is specifically the crop-calendar bounds/portability defect. It is not a general crop-development qualification.
