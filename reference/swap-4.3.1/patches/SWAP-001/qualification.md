# SWAP-001 qualification

## Audit evidence

The SWAP 4.3.1 audit classifies SWAP-001 as `FIX_TESTED` with very high certainty and high severity.

Recorded reproducer:

```text
B0 strict macropore run:
array-shape mismatch at VlMpDm1Cp assignment
reported extents 5000 / 112
```

Recorded corrected run:

```text
patched strict macropore smoke run:
Swap normal completion!
```

The audit proposal recommends the change as a safe maintenance fix.

## Current B1 provenance verification

The B0 source archive was independently checked before deriving this per-issue patch.

```text
SWAP/macropore.f90 B0 SHA-256
1cb5a2ce30610c05a4da5655bff217d6f52052d57d99efe8af7928f1d2187d0b

exact target byte sequence occurrences in B0
1

patched file SHA-256
f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f
```

The B1 helper `apply_and_verify.py` encodes the preimage hash, exact CRLF byte sequence and expected patched-file hash. It fails rather than applying the correction to an unknown source preimage.

The minimal `fix.patch` is the SWAP-001 hunk from the audited combined patch, isolated so B1 does not accidentally admit unrelated fixes from that historical multi-issue artifact.

## Acceptance reasoning

The original assignment is non-conformable whenever `macp /= numnod`. The corrected assignment makes both sides of the active slice conformable and explicitly initializes the unused tail. It does not alter the values copied for nodes `1:numnod`.

Therefore this is an implementation correctness fix rather than model development. No physical option, constitutive law, flux equation, state definition or solver policy changes.

## Qualification conclusion

```text
BUG_CONFIRMED: PASS
EXACT B0 PREIMAGE: PASS
MINIMAL PATCH ISOLATION: PASS
BYTE-SAFE PATCH OUTPUT: PASS
RECORDED STRICT REGRESSION: PASS
MODEL-CHANGE EXCLUSION: PASS
B1 ADMISSION: PASS
```

Scope of the qualification is the SWAP-001 array-shape defect and its direct macropore execution path. It is not a general qualification of all macropore physics.
