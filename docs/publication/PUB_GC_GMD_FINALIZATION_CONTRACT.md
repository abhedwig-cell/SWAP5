# PUB-GC GMD finalization contract

## Status

**MECHANICAL FINALIZATION PATH PREPARED — AUTHORITY VALUES STILL REQUIRED**

Date: 2026-09-19.

This contract converts the remaining GMD submission work from an informal checklist into a fail-closed machine gate. It does **not** choose a release identifier, licence, redistribution statement, archive DOI/PID or author metadata.

## Controlled input

The only machine-readable authority input is:

`PUB_GC_GMD_FINALIZATION_INPUT.json`

Its unresolved state is intentional. Values may be populated only from explicit controlling authority.

Required progression:

1. **pre-authority** — publication assets are exact and governance fields may remain null;
2. **authority-ready** — R1 release identifier and L1 licence/redistribution statement plus authority/effective date are explicit;
3. **archive-ready** — exact publication commit is frozen and the persistent archive DOI/PID exists;
4. **submission-ready** — title, Code and data availability, cover/submission metadata and author/declaration fields contain no unresolved placeholders.

## Fail-closed rules

The finalizer must reject:

- reuse of immutable predecessor identifier `SWAP5-RB1-v1` as the new paper release;
- an empty or placeholder licence/redistribution statement;
- a publication commit that differs from the checked-out release commit in archive-ready mode;
- an absent archive DOI/PID in archive-ready mode;
- unresolved `<<...>>` placeholders in submission-ready mode;
- accidental inclusion of a `SWAP_4.3.1*.zip` distribution in the repository/archive worktree;
- drift of any publication-critical blob frozen in `PUB_GC_GMD_PREARCHIVE_INVENTORY.json`;
- loss of the E7 zero-window / `REALISTIC_COMPONENT_DOMAIN_LIMIT` guard.

## Output

After R1/L1 and archive creation, the tool may emit a final immutable binding manifest containing:

- publication release identifier;
- exact publication commit;
- licence/redistribution authority;
- archive DOI/PID and creation date;
- exact publication-critical blobs;
- external SWAP 4.3.1 hash/size and non-redistribution guard;
- E7 bounded outcome.

That manifest is metadata. It does not replace the persistent archive itself.

## Commands

Repository-controlled pre-authority validation:

```text
python tools/publication/finalize_pub_gc_gmd_release.py
```

After R1/L1 are governed:

```text
python tools/publication/finalize_pub_gc_gmd_release.py --authority-ready
```

On the exact release commit after the archive DOI/PID exists:

```text
python tools/publication/finalize_pub_gc_gmd_release.py --archive-ready --emit docs/publication/PUB_GC_GMD_FINAL_ARCHIVE_BINDING.json
```

Immediately before upload:

```text
python tools/publication/finalize_pub_gc_gmd_release.py --submission-ready
```

## Scientific boundary

This finalization layer cannot reopen or strengthen E1–E7. In particular it may not manufacture Hupsel loose/strong output, infer realistic correction magnitudes, alter coupling tolerances, or change the E7 component-domain classification.
