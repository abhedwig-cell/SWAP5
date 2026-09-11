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

The separate exact-head-green audit authority `qualification/f-ci47r-accidental-support-file-remediation-record@1b6affe15e1e823c6f5d08dc6e36959c7b43d3b3` records the temporary empty-root-file tooling incident and its fast-forward remediation. Audit workflow `34646802638` passed. That audit branch is not part of F-TB08 and is not merged into canonical.

## Qualification history

Precloseout FAST passed on `e2f9717d934fea1ec482aec1ae83071ed83c369f`:
- workflow run `34647272253`
- FAST job `103420942218`
- exact-head start/end PASS
- registry/provenance/source/reference/support composition PASS

The final closeout head must still pass FAST and RELEASE on the same exact `[ftb08-release]` commit before the target decision becomes final.

## Frozen nonclaims

No numeric `H_app`; no numeric `A_temporal`; no external source-byte verification in the adapter; no file or JSON parsing; no project-policy selection; no production SWAP-MODFLOW admission; no mass-conservation relaxation.
