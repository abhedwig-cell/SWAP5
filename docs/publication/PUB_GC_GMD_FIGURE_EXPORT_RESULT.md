# PUB-GC GMD figure export result

## Status

**VALIDATED GMD PDF EXPORT CANDIDATE**

Date: 2026-09-19.

F1-F7 were exported from the governed repository SVG sources to vector PDF and validated without changing scientific content.

Qualification:

- workflow run: **35405142243**;
- job: **105793234099**;
- result: **SUCCESS**;
- artifact: **10571902714** (`pub-gc-gmd-figure-package`);
- artifact digest: `sha256:c15ab068d7d6885533cf022640ae95090492333ca9044c0f9ed089122f6130e7`;
- flat submission ZIP SHA-256: `37ef7daf52ad2892b78b4f926f89983f64c097eba32839e20fce47211e5d43fb`.

| Figure | PDF | Size | SHA-256 |
| --- | --- | ---: | --- |
| F1 | `f01.pdf` | 23,995 B | `caffc98c2a46aa72b6cbea02dc80912c154d0c2d39e64f2a456e7b7611dac59b` |
| F2 | `f02.pdf` | 28,593 B | `111f4e57f2f937f7e3500bb22488458cc50c10c9550cc46ebf94e3ad024c36b7` |
| F3 | `f03.pdf` | 26,846 B | `41e9ce848e433684dfa5423df2e527810c86ca186491ff5ad559299e8ae48c76` |
| F4 | `f04.pdf` | 24,370 B | `580963bfc02f52da8f478bd7fbc82c9deb849c9a5373c0297f3b1e7a661be0d7` |
| F5 | `f05.pdf` | 23,483 B | `b0c63e32584ee1fc49c48ffceefb05275aa9eb4827f380bfdd46a9337d4bad69` |
| F6 | `f06.pdf` | 27,703 B | `421ba3979d92a37edadfe844e5caa25059e2dbee3e9501418939c908f9b46875` |
| F7 | `f07.pdf` | 24,652 B | `b1a3a702601e164701c96d85370642abde91494c0efc54c17ddea2fb3659e5ed` |

All PDFs are one page, preserve source aspect ratio, are far below the 2 MB GMD PDF-figure limit, and contain only embedded detected fonts.

The workflow also rendered every PDF with Poppler and required a nonblank render whose content did not touch the page edge. An additional 160-dpi render review of the downloaded artifact found no clipping, overlapping elements, black-square glyph failures or other visible export damage.

F7 remains scientifically bounded: it shows the realistic component-domain stop and does not imply that E7 loose/strong Hupsel coupling windows executed.

## Release rule

These files are validated presentation transforms, not new scientific authorities. At the final governed SWAP5 publication release, regenerate the PDFs from the same governed SVG sources and record the release-bound artifact/PID.
