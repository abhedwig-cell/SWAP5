# Common GNU x86-64 application arithmetic profile

## Qualified successor, 13 November 2026

Owner: `integration/f-ci/RC1_PLATFORM_STABILITY01.json`. The owner selected
continued platform-sensitivity work after closing the preceding performance
investigation with limitations. That historical closure is not rewritten.
Frozen RC1 remains11529865e76fb2259542f1e770726cd87af27603.

The same GNU15 version does not imply the same compiled arithmetic. The measured
Windows runner defaults to nocona without FMA; Ubuntu26.04 defaults to x86-64-v3
with FMA. Static disassembly finds1013 fused instructions in the Linux donor,
including30 in headcalc and34 in integral, and none in the Windows donor.
These are linked instructions, not executed counts; preserved macro routines
in that binary were not selected for execution.

The selected named application profile is `gnu-x86_64-separate-ops-v1`:
`-ffp-contract=off -march=x86-64 -mtune=generic`. It applies explicitly to TTUTIL,
original selected donor objects, generated donor objects and the no-macro kernel.
The [GCC contraction option](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html#index-ffp-contract)
controls operation fusion; the [GCC x86 target options](https://gcc.gnu.org/onlinedocs/gcc/x86-Options.html)
select the instruction baseline and tuning. These options provide an explicit
compilation policy, not an accuracy theorem or an identical-libm guarantee.

Source preparation, build identity and checkpoint binding contain the named
profile and its exact flag list. Unknown or mixed provider/build profiles refuse
before public output. A fresh provider/build is required; old and private states
are not rebound. The profile is restricted to the named GNU x86-64 applications.
Other architectures are not qualified. The original reference builder's default
invocation and active-macro branch keep their existing flags. RC1 is unchanged.

## Physical and state boundary

No original Fortran formula, execution order, physical option, solver stopping
test, time-step controller, balance limit, C durability operation or native codec
changes. The explicit profile replaces compiler target/fusion defaults; resulting
roundoff and later adaptive decisions can differ from previous source-bound
trajectories. Original reference FAILs and underqualified references remain.
The rejected feedback, receipt-projection and quadmath prototypes are not used
by the supported host. Their sources and raw evidence remain on the research
branch and in the hashed rejected/prefix archive.

The private common-profile Hupsel1096 frames give Windows/Ubuntu584 oxygen
reductions0.004793608905922416/0.004794137799582377cm, spread5.288936599616434e-7cm
versus the existing point bound5.371840000016327e-7cm. This improves that named
comparison; it does not establish whole-model scientific equivalence. Other
hydraulic spreads and original failed comparisons must remain separately visible.
The first full/native harness failed on a reused stage filename, after1095
guarded days; its failure is retained and is not a qualified full/restart result.

## Qualification and remaining limits

The initial public qualification completed on the laptop (GNU16.2),
Windows2022 GNU15 and Ubuntu26.04 GNU15. Hosted run
[43404227897](https://github.com/abhedwig-cell/SWAP5/actions/runs/43404227897)
succeeded on both systems. All three complete O2 periods (1827/1096/1461 days)
and own cut-to-end continuations are exact within each cohort, including physical
records, printed CSV and native/auxiliary terminal payloads. The kernel O0
four-day controls also pass; the original donor is compiled O2 in both kernel
profiles. Ten refusal cases and six external transaction/instance controls pass
per cohort. Daily water/kernel and solute guards remain 1e-10 in their units.
Supported thermal bookkeeping is preserved; no unmeasured energy flux is invented.

The public matched GNU15 point reproduces the private result above. This is a
bounded improvement of platform reproducibility, not qualification against the
original SWAP4.3.1 oxygen reference (0.003593541147 cm), whose FAIL remains.
The original and implicit reference families remain underqualified. Grassgrowth
day188 and all earlier scientific dispositions are preserved.

Full trajectory spreads are retained in
`integration/f-ci/platform-stability01/PUBLIC_CROSSPLATFORM.json`.
Hupsel still differs by up to 12.20396275 cm in pressure head, 0.0008707256 cm
in stock and 0.0004601525 cm in an uptake term. SaltFarm stock spread falls
from 0.0202189338 to 0.0049296497 cm (about 75.6 percent), but is not zero.
Hupsel maximum solute-ledger spread increases from 0.0002868614 to
0.0003991142 mg/cm2. The improvement is therefore not uniform across outputs.
No new fitted whole-profile tolerance or portable scientific PASS is declared.

On this laptop the previous and new profile produce exactly the same daily
physical JSON records and terminal native payloads for all three periods.
`LAPTOP_BASELINE_PRESERVATION.json` binds that observation to source and hashes.
A single alternating old/new paired cost observation with one terminal checkpoint
gives model-plus-controller seconds: Grass 8.684/9.002; Hupsel 4.645/4.643;
SaltFarm 10.773/10.232. This is a bounded cost check, not a statistical benchmark
or native-solver speedup claim. Earlier separate-day timings and unlike runner
hardware are not used as performance ratios. Exact commands and observations
are retained in `SAME_LAPTOP_PAIRED_COST.json`.

## Admission boundary

Canonical advanced through PR1669 and PR1670 during qualification. Their
explicit original-project/bottom dispatch and original history/reaction state
are merged into this candidate;
`project_case` remains authoritative and the profile check is additional.
The final combined runtime d54d4a3e1 is qualified by hosted carrier
982b5c605 (only the registered workflow wiring differs), run
[43408495599](https://github.com/abhedwig-cell/SWAP5/actions/runs/43408495599),
SUCCESS on Windows2022 and Ubuntu26.04, plus the fresh laptop cohort.
Both Ubuntu blockA and extended blockB coverage pass, including their retained
undrained-Hupsel refusal and history/state rejection controls. Prior runs
qualify their pinned sources only. Raw proof, member digests, exact invocations,
PREPARED/BUILD identities and terminal receipts are preserved under
`integration/f-ci/platform-stability01`. The owner record binds admission.

Across the canonical reconciliation the three laptop trajectories and native
payloads remain exact; `LAPTOP_CANONICAL_DELTA_PRESERVATION.json` records this
separately from the initial compiler-profile comparison. Source-bound checkpoint
identities are never rebound even where physical payloads are equal.

Each selected release-model invocation is capped at 60 seconds. The unchanged
canonical coverage harness uses its existing 180-second model cap and 300-second
subprocess cap; this is a selected preservation gate, not a new reference or
numerical search campaign. Scientific
references are reused rather than rerun under a new profile and silently
relabelled. Moving full F-CI, active macropores and retired highest-low-air
campaigns are not selected: those paths are unchanged. No such gate is claimed
PASS. Canonical admission requires the PR merge and actual postimage check;
frozen RC1 remains unchanged.

This package provides the explicit build policy and the named point improvement.
It does not solve the residual full-trajectory platform spread or independently
qualify the original oxygen reference. Further science must retain those visible
FAILs and establish independent reference accuracy before any equivalence claim;
no additional fitted tolerance or repeat reference campaign is authorized by
this admission.
