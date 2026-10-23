# F-WOF-EXT01: real native leaf-rate diagnostic, 2026-10-17

Research evidence, **not scientific equivalence qualification**.

## Executed gate

- Targeted contract workflow: https://github.com/abhedwig-cell/SWAP5/actions/runs/39058395486
- Native Fortran job ID: 117470998647, conclusion SUCCESS.
- GitHub YAML parse error in previous workflow revisions was corrected at commit `024d5ec161e22458ef3cc92938c2633c52a5c9a4`. Both native O0 and O2 drivers ran 60 transitions, with byte-identical CSV output.
- Cross-language first divergence reproduced: LAI row 21 (2010-05-06), Fortran - Python `-0.0004639948884571643`; TAGP row 22 (2010-05-07), `-0.0064008650550277935` kg/ha. Final TAGP remains 360.35137145341423 Fortran vs 533.5071863311674 Python kg/ha.

## Actual native diagnostic observation

The newly inserted Fortran `EXT01_LEAF_TRACE` shows, at transition 20 (for state row 21):

- pre-day DVS `0.2475625`, LAI `0.07915390038711569`, LAIEXP `0.099370458298378525`;
- RFTRA `0.5`, RFRGRL `1.0`;
- GRLV `0.96619717836732`, corrected SLAT `0.0027575845518691414`, GLAIEX `0.002664370413125274`;
- pre-day DVS exceeds 0.2, so PCSE `WOFOST_Leaf_Dynamics_N` applies juvenile factor `1.0`, while the SWAP5 Fortran common rate finalizer applies `0.5` to GLAIEX unconditionally when LAIEXP <6.

Thus there is a **directly exercised input-side divergence in the rate formulas** in the first-divergence window. It does not yet prove that this is sufficient to explain all 60-day discrepancies. Actual PCSE internal day-rate and cohort values have not yet been logged side-by-side. A particular ambiguity is that the first output LAI departure is later than the DVS=0.2 boundary: source-limited/GLASOL clipping may have hidden earlier changes to LAIEXP, and the exact day/output phase needs checking.

## Next scientific gate

Instrument PCSE `WOFOST_Leaf_Dynamics_N.calc_rates` test-only around 2010-05-04 through 2010-05-07, capture pre-rate DVS, LAIEXP, `RFRGRL`, `RFTRA`, `GRLV`, `GLAIEX`, `GLASOL`, `SLAT`, and leaf class vectors after integration. Compare these to Fortran with index alignment, then perform a research-only alternative native GLAIEX gate and test whether the first LAI fork disappears. Preserve original snapshots and never reclassify research equivalence before full matched 12-field re-run and transactional/restart gates.

Status: **technical O0/O2 and native trace PASS; cross-language science FAIL, cause partially isolated; NO production admission**.
