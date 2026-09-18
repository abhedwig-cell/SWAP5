# PUB-GC GMD formatting and upload handoff

## Status

**FORMAT ROUTE FROZEN — EXECUTION AWAITS FINAL VERSION/AUTHOR/ARCHIVE METADATA**

Date: 2026-09-18.

## Current GMD requirements verified

The final submission package must preserve the following current requirements:

- model name and version/unique identifier in the title where appropriate;
- exact code version available from a persistent archive with a unique identifier;
- Code availability / Code and data availability section;
- model code, relevant configuration/input material and scripts covering reported processing/results;
- 500-character maximum non-technical short summary;
- full first and last names and full affiliations on the title page;
- individual figure files for production; accepted formats include PDF/EPS/JPG/PNG/TIF/GIF;
- individual figure files should remain below 5 MB;
- total non-supplement submission files should remain below 30 MB;
- key figure selected separately for online article presentation.

Official pages checked 2026-09-18:

- `https://www.geoscientific-model-development.net/about/manuscript_types.html`
- `https://www.geoscientific-model-development.net/policies/code_and_data_policy.html`
- `https://www.geoscientific-model-development.net/submission.html`

## Frozen content mapping

### Main text

Source:

`PUB_GC_COUPLE_MANUSCRIPT_DRAFT.md`

Required journal transformations after A1/A2b/A3 and author metadata resolve:

1. bind final versioned title;
2. populate author/title page;
3. convert to current Copernicus Word or LaTeX format;
4. retain numbered sections and journal-facing captions;
5. insert final Code/Data Availability;
6. insert Author contributions, Competing interests, Acknowledgements and Financial support;
7. normalize references to Copernicus style;
8. remove repository-internal evidence pointers from the journal body or move them to supplement as appropriate.

### Figures

Use F1 as key figure.

Production assets currently exist as SVG. Prepare accepted upload derivatives without altering scientific content:

- F1 ownership/authority;
- F2 typed hydrological interface;
- F3 closure versus head correction;
- F4 response identity;
- F5 response-information value;
- F6 component-admission envelope;
- F7 realistic component-domain limit.

Prefer vector PDF for schematic/data figures when conversion preserves text and geometry. Do not redraw F7 as a successful coupled Hupsel result.

### Tables

T1–T6 are frozen in `PUB_GC_MANUSCRIPT_TABLES.md`. Convert layout only; unavailable quantities and zero E7 coupled-window counts are scientific values/statuses and may not be editorially replaced.

### Supplement

Use `PUB_GC_SUPPLEMENTARY_METHODS_AND_EVIDENCE.md` as the journal-neutral supplement source.

## Pre-upload gates

Before generating the final submission PDF:

1. A1 release identifier resolved;
2. A2b SWAP5 archive licence declaration resolved;
3. A3 persistent archive DOI/PID resolved;
4. author/affiliation/contribution metadata resolved;
5. `check_pub_gc_gmd_submission.py --submission-ready` passes;
6. archive PID resolves to exact submission release;
7. final title version equals archive version;
8. code/data statement licence equals archive metadata;
9. short summary recounted and remains <=500 characters;
10. key figure and figure exports meet current GMD file rules.

## Scientific firewall

Formatting work must not:

- add a positive Hupsel coupling trajectory;
- imply MODFLOW executed for the E7 frozen dates;
- reinterpret component-domain failure as convergence failure;
- claim regional Hupsel groundwater validation;
- broaden N:1 aggregation claims;
- resurrect standalone ACCELERATE novelty.
