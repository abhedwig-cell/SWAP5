# SWAP-007 qualification

## Audit evidence

The SWAP 4.3.1 audit classifies SWAP-007 as `FIX_TESTED`, confidence high, severity medium.

Recorded strict regression:

```text
B0 strict-FPE grass run:
Program received signal SIGFPE
oxygenstress.f90:849

patched strict-FPE grass run:
running swap ....
Swap normal completion!
```

The audit also compared a normal original and patched grass run. After neutralizing only the automatically generated timestamp, `result_output.csv` was identical. This supports the conclusion that the guard leaves the ordinary numerical path unchanged and acts only when the raw Newton quotient would be unrepresentable.

## Current B1 provenance verification

The B0 source member has been checked against the canonical expanded-source manifest:

```text
SWAP/oxygenstress.f90 B0 SHA-256
2db206bf28e883a22a1419d4729e03c1bb6b9c6bcf560d2221248f3b12f75

exact target byte sequence occurrences in B0
1

corrected file SHA-256
8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87
```

The helper `apply_and_verify.py` encodes the byte-exact CRLF preimage and expected corrected-file hash and refuses unknown source input.

## Numerical interpretation

The correction does not change the Newton formula on representable updates. It only replaces an overflowing quotient with `lnew = huge(1.0d0)`, which causes the existing `lnew > 1.d3` restart route to activate. No new fallback physics or solver policy is introduced.

## Qualification conclusion

```text
BUG_CONFIRMED: PASS
EXACT B0 PREIMAGE: PASS
MINIMAL PATCH ISOLATION: PASS
BYTE-SAFE PATCH OUTPUT: PASS
STRICT FAILURE REPRODUCTION: PASS
PATCHED STRICT COMPLETION: PASS
NORMAL OUTPUT EQUIVALENCE: PASS
MODEL-CHANGE EXCLUSION: PASS
B1 ADMISSION: PASS
```

Scope is limited to the SWAP-007 overflow defect in the oxygen-stress Newton update. It is not a general requalification of the oxygen-stress model.
