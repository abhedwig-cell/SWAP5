# SWAP-001: macropore array-shape defect

B1 status: **ADMISSION CANDIDATE**

Audit status: **FIX_TESTED**

## Defect

In B0 `macropore.f90`, `VlMpDm1Cp` has the fixed `macp` extent while the right-hand side slice has only `numnod` elements:

```fortran
VlMpDm1Cp= VlMpDmCp(1,1:numnod)
```

For the supplied macropore regression case this is a non-conformable whole-array assignment (`5000/112`) under strict runtime shape checking.

## Correction

Clear the complete destination, then assign only the active node slice:

```fortran
VlMpDm1Cp = 0.0d0
VlMpDm1Cp(1:numnod) = VlMpDmCp(1,1:numnod)
```

This preserves the intended active-node copy while making the inactive remainder deterministic.

## Exact identities

```text
B0 file: SWAP/macropore.f90
B0 SHA-256: 1cb5a2ce30610c05a4da5655bff217d6f52052d57d99efe8af7928f1d2187d0b
B0 bytes: 88138

minimal fix.patch SHA-256:
6dd75db2603f71def58db0a0f5c77bfcd2fba2688add837436fd0d09713e5770

patched macropore.f90 SHA-256:
f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f
patched bytes: 88174
```

The patch is derived from the exact SWAP-001 hunk in the audited `SWAP_4.3.1_proposed_fixes.patch` and checked against the byte-exact B0 preimage.

## Qualification

The recorded strict regression reproduces the original `5000/112` array-bound/shape failure and the patched macropore smoke run reaches normal SWAP completion. The central issue register classifies the fix as `FIX_TESTED`, certainty very high, severity high, and recommends it as a safe maintenance fix.

## Classification

- implementation defect: yes
- physics/model change: no
- input/output compatibility change: no
- expected B0-to-B1 difference: affected strict/conforming macropore execution no longer fails at this assignment; inactive destination entries are explicitly zeroed
- mass-balance concession: none
