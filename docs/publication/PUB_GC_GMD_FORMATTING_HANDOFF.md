# PUB-GC GMD formatting and upload handoff

## Status

**FORMAT ROUTE FROZEN — FINALIZATION WAITS ONLY ON AUTHORITY/AUTHOR METADATA**

Date: 2026-09-19.

## Journal-facing route

Current GMD requirements checked on 2026-09-19 require or support:

- model name and version/unique identifier in the title where appropriate;
- a persistent exact-version code/data archive;
- a final section titled **Code and data availability**;
- preprocessing/run-control/postprocessing material covering reported results;
- a non-technical short summary no longer than 500 characters including spaces;
- figures supplied individually in one flat zip;
- vector PDF preferred for line/vector figures;
- PDF figures <=2 MB, other figure formats <=5 MB;
- overall non-supplement submission <=30 MB.

## Main text handoff

Source: `PUB_GC_COUPLE_MANUSCRIPT_DRAFT.md`.

After R1/L1/DOI and author metadata resolve:

1. bind final versioned title;
2. populate author/title page;
3. convert to current Copernicus Word or LaTeX layout;
4. insert final Code and data availability wording;
5. insert Author contributions, Competing interests, Acknowledgements and Financial support;
6. normalize references to Copernicus style;
7. remove or relocate repository-internal evidence pointers from the journal body.

## Figures

Use F1 as key figure. Export F1–F7 per `PUB_GC_GMD_FIGURE_EXPORT_PLAN.json`.

Do not redraw F7 as if coupled Hupsel MODFLOW windows executed.

## Tables and supplement

T1–T6 are scientifically frozen in `PUB_GC_MANUSCRIPT_TABLES.md`. Layout may change; unavailable values and zero E7 coupled-window counts may not.

Use `PUB_GC_SUPPLEMENTARY_METHODS_AND_EVIDENCE.md` as the supplement source.

## Final pre-upload gates

- R1 release identifier governed;
- L1 archive licence/redistribution governed;
- persistent DOI/PID resolves to exact release;
- author/affiliation/contribution metadata complete;
- strict repository submission checker passes;
- figure exports satisfy size/render constraints;
- title version, archive version, licence statement and Code/Data wording agree exactly.
