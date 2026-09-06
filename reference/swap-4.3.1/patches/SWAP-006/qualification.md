# SWAP-006 qualification

## Audit evidence

The central SWAP 4.3.1 issue register records SWAP-006 as:

```text
status: FIX_TESTED
certainty: high
severity: medium
reproducible: yes
test evidence: NaN-initialized test exposed issue; patched build passes
upstream advice: submit safe fix
source: MOD_meteo.f90:264-270
```

The technical audit note describes the same defect as meteo loading that uses an unused zero-initialized `cropstart` entry as a sentinel instead of the actual record count `ifnd`.

## Current B1 provenance verification

The exact B0 `MOD_meteo.f90` member has been checked against the B0 member manifest.

```text
B0 SHA-256
5a095c16ec82fa544f7dd20ba568ba3a2b72906bff7dd3505af16e6722d86822

B0 bytes
85550

exact target byte sequence occurrences
1

corrected SHA-256
99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f

corrected bytes
85541
```

The isolated patch is the exact SWAP-006 hunk from the audited combined patch. `apply_and_verify.py` applies the correction only to the exact B0 preimage and verifies the deterministic corrected-file hash.

## Acceptance reasoning

The intended iteration domain is the set of crop calendar records actually read, whose count is `ifnd`. Iterating to `ifnd` makes that domain explicit and removes dependence on compiler initialization of unused array elements. The existing date-overlap criterion and dynamic-crop test are preserved.

This is therefore a portability/implementation correctness repair, not a crop-model change.

## Qualification conclusion

```text
BUG_CONFIRMED: PASS
EXACT B0 PREIMAGE: PASS
MINIMAL PATCH ISOLATION: PASS
BYTE-SAFE PATCH OUTPUT: PASS
RECORDED NAN-INITIALIZATION REGRESSION: PASS
MODEL-CHANGE EXCLUSION: PASS
B1 ADMISSION: PASS
```

Scope is limited to removal of the hidden sentinel/initialization dependency in this meteo-loading loop.
