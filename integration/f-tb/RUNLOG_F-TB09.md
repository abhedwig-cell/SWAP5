# F-TB09 run log

## Composition

Frozen base: `integration/f-ci-canonical@42544af575db522d012db491db801615577048df` tree `4360cd08fd0e952978df9e2742bcc34fdede9ef1`.

The initial TB09 commit was created only after canonical had advanced through F-CI49. During final review canonical advanced once more to `ca1dbf6f51e606bdd2a89aa9057ed40b2d99b868` through F-CI49P. F-CI49P is a moving-preservation/governance reconciliation with no production source, reference, scientific tolerance or solver-functionality delta. The frozen TB09 base therefore remains scientifically current for this workunit.

## Live F-TB01 through F-TB08 recheck

The authoritative final run IDs are stored in `F-TB09_AUTHORITY_RECHECK.json`:

- F-TB01 `1d039292d5768496c4550a8e1b35a92c6f836504` run `34553040742`: success
- F-TB02 `549531e2e233cccab1416dba04edb266653a5da5` run `34559093286`: success
- F-TB03 `65d5e5202446212390dbdd84b06e6b2a80e7121c` run `34588150201`: success
- F-TB04 `85280c6c436a73c211b70996f9a22f4ad6b04f9c` run `34620867757`: success
- F-TB05 `81d4f0479a99bc456803f583457862387c267ec0` run `34621948220`: success
- F-TB06 `163ed723cc4f2277746bdd54f338c4b06e2eaaa9` run `34642847060`: success
- F-TB07 `4fd0e3a4cb30254135c8da086a733eb3c790b834` run `34643844345`: success
- F-TB08 `d240d5e90a4cb778429af7286250435cdc4f03c3` run `34647338808`: success

The initial TB09 manifest/work-unit contract recorded stale or non-resolvable run IDs for F-TB04 through F-TB07. Those metadata fields are superseded, not silently retained as authority.

## Permanent-case inventory

The final deduplication crosswalk names the already-permanent cases explicitly. It includes the F-TB01 integrated DIVDRA and surface-evaporation cases, F-TB01 root/effective-forcing cases, the F-TB03 RB1 release cases, F-TB04 restart cases and F-TB06 thermal cases.

This matters because TB09 is an interaction layer. Existing primitive or already-integrated cases are reused, not cloned under new TB09 IDs.

## Catalog

Eight bounded, pairwise/risk-selected interaction specifications remain. Every case has stable identity, physics scope, F-TB01 oracle class, explicit hard water balance, tolerance provenance, profiles, expected diagnostics, theory/equation references and invariant IDs.

No TB09 entry claims executed physics qualification. The catalog decision qualifies the catalog contract only.

## Conservation clarification

The canonical accounting sign is positive into the SWAP domain and negative out. Expanded case equations that subtract `Q_bottom` use it as a positive outward magnitude. Upward flow is an input and must never be double-booked. The machine-readable authority is `F-TB09_AUTHORITY_RECHECK.json`.

## Source boundary

Production source changes: none. Source defects fixed: none. Mass tolerance relaxed: none.

## Exact-head closeout

The amended workflow verifies that the live branch ref equals `GITHUB_SHA` at workflow start and end, then validates the support-only diff and catalog/recheck authorities. A later commit invalidates the closeout until exact-head CI runs again.
