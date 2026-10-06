# PPA-MICRO01 component closeout

PR #1069, merge `efaeffcc36205f54ed3990b2efaf99ac908e5c0d`, admits the unused typed MICRO matric-flux and
conductivity table, according to the [repair contract](PPA_MICRO01_TABLE_REPAIR_CONTRACT.md).
The immutable B1.11 source remains unchanged. The explicit correction fills
the terminal bracket and starts integration at -20000 cm. Earlier initialized
M values gain the missing terminal integral; this is a disclosed reference
repair, not bitwise preservation of the former truncated integration origin.

The original defect is confirmed by controlled variation of uninitialized
M/K cells. The corrected typed component passes 2600 comparisons per O0/O2
level with the explicitly patched literal source, synthetic constant and
head-dependent conductivity, an independent terminal integral, nonfinite/
shape/overflow rejection and previous-table isolation. Seven manifest entries
and the final artifact SHA256 match. Run 37417114385 is controlling evidence.
The first false-green pipeline and incorrect normal control remain negative
evidence. Documentation source, strict MkDocs and whitespace checks pass.

The proposed and actual admission tree both equal
`72b5b292b4a1b7bd1b25f9a0b6fe5b67fda792b6`. Admission record:
`integration/audits/PPA_MICRO01_CANONICAL_ADMISSION.json`. This closeout changes metadata only. No blanket CI-green claim.

No current uptake runtime, accepted mass owner, state or restart schema changes.
The typed table has no SAVE or file I/O and delegates conductivity to supplied
hydraulic-owner samples. Full MICRO nonlinear uptake, real hydraulic provider
binding, sink/state/restart and hydraulic lift/salt/osmotic/frost are not
admitted. Synthetic owners qualify table algebra only. Jarvis/Walsum remains
separate and admitted. Frozen Status A is unchanged.
