# PUB-GC GMD pre-submission checklist

## Status

**SCIENTIFICALLY READY / PREARCHIVE PACKAGE READY / GOVERNANCE FIELDS OPEN**

Date: 2026-09-18.

This checklist follows current GMD requirements verified on 2026-09-18.

## Scientific package

- [x] RQ1–RQ5 closed within bounded claims.
- [x] E7 closed as `REALISTIC_COMPONENT_DOMAIN_LIMIT`.
- [x] Manuscript complete through E7.
- [x] Figures F1–F7 complete.
- [x] Tables T1–T6 complete.
- [x] Claim-to-sentence audit passes.
- [x] Literature/reference audit complete.
- [x] Supplement and machine-readable evidence package available.

## GMD model/code requirements

- [x] Exact publication-code contents inventory prepared.
- [x] Source code, tests, workflows, evidence and postprocessing/figure sources identified for archival.
- [x] Exact historical SWAP 4.3.1 reference identity preserved without redistribution.
- [x] Official SWAP version-4 licence source independently verified.
- [ ] Governed SWAP5 publication release identifier — **A1**.
- [ ] Explicit SWAP5 publication-archive licence/redistribution declaration — **A2b**.
- [ ] Persistent exact-version archive DOI/PID — **A3**.
- [ ] Bind release identifier into title.
- [ ] Replace Code/Data Availability placeholders with exact archive/licence/PID values.

## GMD manuscript/upload requirements

- [x] GMD selected as primary target, Development and technical paper.
- [x] Short summary candidate = **432 characters including spaces**, below the 500-character limit.
- [x] Key figure candidate selected: F1.
- [x] Journal-facing abstract and conclusions already evidence-bounded.
- [ ] Final author names and full affiliations.
- [ ] Corresponding-author email.
- [ ] CRediT contributions.
- [ ] Funding statement.
- [ ] Acknowledgements.
- [ ] Competing-interests declaration.
- [ ] AI-tool-use statement if required by final submission policy.
- [ ] Convert final source to current Copernicus/GMD Word or LaTeX format.
- [x] Current F1–F7 SVG sources are individually far below 5 MB (largest current SVG source: F5, ~13 kB-equivalent text size).
- [ ] Export final individual figures to accepted production formats (prefer vector PDF where faithful) and recheck each exported file <5 MB.
- [ ] Final reference-format pass.
- [ ] Final title/version/archive identity cross-check.

## Automated gate

Run:

```text
python tools/publication/check_pub_gc_gmd_submission.py
```

This must pass prearchive integrity while A1/A2b/A3 remain visibly blocked.

After governance/archive closure run:

```text
python tools/publication/check_pub_gc_gmd_submission.py --submission-ready
```

The second command must return PASS before submission.


## Mechanical evidence recorded

Current frozen short summary:

```text
characters including spaces: 432
limit: 500
result: PASS
```

Current SVG source sizes are all orders of magnitude below the GMD individual-figure 5 MB limit. Final exported PDF/raster sizes must still be checked after conversion because the source-SVG size does not guarantee the exported-file size.
