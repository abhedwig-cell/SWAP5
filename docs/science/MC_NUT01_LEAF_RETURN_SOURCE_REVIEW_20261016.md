# MC-NUT01 partial leaf return and retained dead material

Status: source-chain assessment canonically recorded through PR1261, merge
`7dc1adb594c4091d7df60229af4b779485ca9558`; partial-return production remains
unadmitted. Baseline canonical `d27c6abe023eecd4f2e63ae42ad2fb330ad2ef15`.
Recovery is `integration/audits/MC_NUT_SOL_STATUS.json`, field
`leaf_return_review_20261016`. PR1260's admitted N process and the existing
explicit full-return senescence route remain preserved.

## Source and physical distinction

The immutable B1.11 archive is
`integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64`.
Its pinned source members are:

| Member | SHA256 | Relevant source lines |
| --- | --- | --- |
| wofostnut.f90 | 071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2 | 99..101;253..268;277..311;315..319 |
| wofost.f90 | 3f7daf222835c9b4b395feaa665614e8aef88a03125cdec9e0776ca793c6271b | 1083..1085 |
| management_soil.f90 | 0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b | 583..625 |

FRadeceasedLvToSoil is optional, bounded0..1, with source default0. It is not
an admission authority for changing the existing explicit full-return profile.
For daily root/leaf/stem death DM `[2,10,3]kg/ha` and residual N concentration
.01, the source and admitted mapping differ:

| Quantity | Original source day | Existing explicit full-return route |
| --- | --- | --- |
| Root returned DM/N | 2/.02 | 2/.02 |
| Leaf returned DM/N | 10f/.1f | 10/.1 |
| Stem returned DM/N | 0/0 | 3/.03 |
| Leaf N remaining for later harvest | .1(1-f) | Already transferred to soil/pending |
| Stem N remaining for later harvest | .03 | Already transferred to soil/pending |

Changing only a leaf scalar in the present mapper cannot establish source
semantics: stem death remains above ground too. Nonreturned material is neither
new external input nor an immediate export. In the example, soil plus retained
leaf/stem N equals .15kg/ha. Omitting retained material leaves an actual deficit.
The historical NLOSSR accumulator is a gross root-loss diagnostic even though
roots return to soil; it must not also become a second retained root-N pool.
The source crop balance separately counts NLOSSLDeceasedLvToSoil. Current gross
crop loss is preserved by an explicit representation mapping, not by relabelling
these historical accumulators as the existing aggregate ledger.

## Executable source-chain discrepancy at harvest

The original growth routine adds all leaf death to `s%dwlv`. The partial-return
routine sends fraction f of that day's DM/N to soil and subtracts that returned
leaf N from NLOSSL, but does not subtract its DM from `s%dwlv`. Later harvest
returns fraction h of accumulated gross dead-leaf DM and h of remaining leaf N.
The source archive's fraction uses and dead-DM assignments were searched; no
subtraction of returned leaf DM from this accumulator was found.

The literal probe composes those exact source blocks, isolating dead material
with zero live organs at harvest. With10kg/ha leaf death, f=1 and h=1:

- daily returned leaf DM is10kg/ha;
- harvest returned dead-leaf DM is another10kg/ha;
- total returned leaf N is .1kg/ha, counted once.

The resulting20kg/ha soil input exceeds the10kg/ha dead leaf supply. A green N
budget alone cannot qualify this composition. The27-case grid over f and separate
leaf/stem harvest fractions contains9 cases in which leaf DM returned to soil
exceeds leaf death. O0/O2 produce identical results. This is an executable
source-block counterexample, not a claim that a full historical crop/calendar
trajectory has been reproduced or a formal B1 correction already admitted.

The real current pending/material constructors are also executed: unit conversion
is exact for source-returned material; the admitted full-return mapping stays
distinct; orphan N, subthreshold material and NaN still reject. The three-provider
review costs about1.06s total, including both optimizations. Its capsule retains
runner, driver, literal extraction, exact source members, commands, raw outputs,
provider identities and measured costs.

## Required decision and next implementation boundary

The reference policy in `docs/verification/principles.md` requires a confirmed
legacy defect to be corrected and qualified in B1 before SWAP5 follows a corrected
reference. The current scientific prerequisite is to adjudicate this DM overlap
in the B1 source chain, including ordinary harvest timing and allowed removal
events. Neither reproducing20kg from10kg nor silently replacing its formula is
admitted by this assessment. This is a scientific reference boundary, not a need
for another solver or full FCI run.

A conserving candidate would retain only `(1-f)*daily_leaf_death` above ground,
retain all daily dead stem, and apply harvest fractions to that retained stock.
Its isolated leaf harvest return would be h(1-f)10 instead of h10. This changes
historical soil OM input by hf10kg/ha and needs an explicit B1 correction decision
and source/chemistry qualification.

Once that reference is settled, extend the existing crop/Soil-N owner with
necessary physical retained aboveground leaf/stem DM and N. Four organ-specific
quantities are required; the aggregate gross N-loss ledger cannot reconstruct
independent harvest fractions. Keep one state/commit authority, not a second
crop N ledger or soil inventory. Use existing accepted clock/configuration
identity; retain returned application ages with pending material. Include retained
stock in whole N and OM, consume it exactly once at harvest, and preserve it
through rejection and restart.

Existing native tags1..8 cover empty/pending, thermal and harvest variants; none
carries this retained daily aboveground stock. A later codec extension must
preserve all admitted bytes and reject continuations that cannot represent the
selected policy. Do not allocate a tag or alter that shared ABI in this read-only
review. Actual source-order daily/harvest composition, retained stock,
native/opaque fresh continuation, full/default1253 preservation and owning gates
remain prerequisites for partial-return runtime admission.

No production, test, solver, codec or reference postimage is changed here.
No capability/count promotion follows. Aquifer remains excluded.
