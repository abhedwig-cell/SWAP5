# RUNLOG F-TB08

## Authorities

- Testbank parent: F-TB07 `4fd0e3a4cb30254135c8da086a733eb3c790b834`
- Current canonical at scope freeze: `82280e350ea7514cc9f394db882d5cb3ef25b18c`
- Composition base: `4172e7e639d13e178fb75471263636a6cfa792fc`
- F-GC14: `6d91bedc305504cc2fa08b196e6a9903c48c9461`
- Adapter blob: `9212d600e89c85287e9280832c7e0a94befb642e`
- Canonical application-accuracy contract blob: `c07d573d21e7d013ab962c0a9d28102ab7b5cdfc`
- Immutable F-GC14 test blob: `7f4f8f044b06ad3e445e4499b575bb98e424c2a0`

## Preconditions

F-CI46/F-CI46P admitted the typed adapter. F-CI47 reconciled moving canonical preservation and the broad canonical workflow run `34646474926` passed on repaired current canonical head `82280e350ea7514cc9f394db882d5cb3ef25b18c`, including `current-restricted-canonical-preservation`.

The separate audit authority `qualification/f-ci47r-accidental-support-file-remediation-record` records the temporary empty-root-file tooling incident and its fast-forward remediation. That audit branch is not part of F-TB08 and is not merged into canonical.

## Qualification history

Pending FAST and exact-head RELEASE qualification.

## Frozen nonclaims

No numeric `H_app`; no numeric `A_temporal`; no external source-byte verification in the adapter; no file or JSON parsing; no project-policy selection; no production SWAP-MODFLOW admission; no mass-conservation relaxation.
