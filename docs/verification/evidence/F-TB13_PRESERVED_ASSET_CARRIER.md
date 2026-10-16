# F-TB13 preserved asset carrier

The exact deterministic analytical-reference payload has SHA-256 `57a75c64e1b057223fbd32ac3051a2c56938209f19b86912d7236f4f1d5fc069` and 17,122 decoded bytes.

It is stored losslessly as four ordered Base64 text parts under `tests/legacy_reference/extended_analytical/asset_parts/`, totaling 22,832 encoded bytes. The F-TB13 preservation gate concatenates the parts in lexical order, validates Base64, reconstructs the archive in memory, checks the archive identity, then checks all nine member identities and expected analytical-result gates.

The carrier format is storage plumbing only. Scientific authority is the decoded archive/member identities and the fresh replay receipt, not the textual Base64 segmentation.
