# PUB-GC GMD figure export qualification

## Status

**PASS — REPRODUCIBLE PDF EXPORT PIPELINE QUALIFIED**

Date: 2026-09-19.

The governed F1–F7 SVG sources were exported to GMD-oriented vector PDFs and validated without modifying the scientific SVG sources.

## Qualified run

- workflow: `PUB-GC GMD qualified figure exports`;
- run: **35425367690**;
- job: **105850258985**;
- source head: `e99cfe76f97a5b01bcc5d71f101274d999013561`;
- conclusion: **SUCCESS**.

## Validation

All seven outputs satisfy the current GMD production gate:

- exactly one PDF per F1–F7;
- exactly one page per PDF;
- embedded font resources;
- each PDF below 2 MB;
- flat zip names exactly `f01.pdf` through `f07.pdf`;
- combined seven-PDF size: **164,666 bytes**;
- total figure size far below the 30 MB non-supplement budget.

| Figure | PDF | bytes | SHA-256 |
| --- | --- | ---: | --- |
| F1 | `f01.pdf` | 21,923 | `61f48bacc7bc353dd01aa9db8aa3d56a22652997a5cf7b81a8c1440b79578895` |
| F2 | `f02.pdf` | 25,804 | `1ecff067c6b16c2d684386472905cb8df5b69aa2d1f4572619f3dd65d2a27741` |
| F3 | `f03.pdf` | 24,629 | `2224cc33de771abdf2f9b89df06e344168be757bd640dcd041fdc2b76d2c852b` |
| F4 | `f04.pdf` | 21,918 | `481dfc24b504f1a5a2d18b1c9b60e0d301e6bf9362bacdbafb90953fbd35c0b0` |
| F5 | `f05.pdf` | 22,094 | `5bdd959f1ad3d9e83b4a199b9b3508471dde110524551c9686f4cafbb76a026a` |
| F6 | `f06.pdf` | 25,585 | `483822464e0818c0983291cfefb45302bd7ba46464b1bc9cea10465b7d81da9a` |
| F7 | `f07.pdf` | 22,713 | `6c4618cc10836f0946c0bc55d6e6c34e836c38daeccf2f293b5c2f7ae9f6b42e` |

Submission zip SHA-256:

`ae2e998d307f0cd78821d6ed9420649667b3289ddf7c46e7597f0764b3cfccb4`

GitHub Actions artifact:

- ID: **10578549141**;
- artifact wrapper digest: `sha256:390701f774e94d40eec03de54f71b722467a9c5be0491b000914bccf413fb468`;
- artifact retention expiry: 2026-12-18.

## Rendering rule

The repository SVGs remain authoritative. During PDF rendering only, the generic Arial/Helvetica/sans-serif declaration is normalized to DejaVu Sans so the PDF carries an embedded font program. Geometry, labels, data and figure semantics are unchanged.

## Repair evidence

Initial run **35425336798** stopped on F2 because the first validator inspected only a top-level Type0 font object. Type0 PDF fonts carry the actual font descriptor on a descendant CIDFont. The validator was repaired to follow `/DescendantFonts`; no SVG, layout or scientific content was altered.

## Final-release rule

This qualification proves the export route. After R1/L1 and the exact publication release/archive identity are fixed, regenerate the same F1–F7 package from that immutable release and record the final release-bound hashes. The temporary Actions artifact is not substituted for the persistent GMD archive.


## Repeatability clarification

A second successful run on the documentation-updated branch head (run **35425488276**, job **105850571113**) reproduced all structural qualification gates: seven one-page PDFs, embedded fonts, <2 MB per PDF, exact flat package membership and total size far below 30 MB.

The generated PDF byte hashes were not identical to the earlier successful run; sizes differed by at most two bytes. Cairo/PDF and zip metadata are not normalized to a fixed creation timestamp/document identifier. Therefore the qualification claim is **reproducible transformation and validation semantics**, not pre-release byte-for-byte PDF determinism.

The governed SVG blobs remain the scientific source authority. Final PDF and zip hashes are frozen only after regeneration from the immutable publication release. A final visual/upload review is also performed at that release-bound stage.

Latest confirmation:

- run 35425488276 — SUCCESS;
- artifact 10578682866;
- artifact wrapper digest `sha256:c64439b533ac482c8f493a7074c687d95e211b2c2847cb299476ccf3b9dff8a6`;
- run-specific submission zip SHA-256 `4dab31c587644d37542f0cf223c8e30a2ea623c224c326d9ad29814869eeabee`;
- combined PDF bytes 164,661.
