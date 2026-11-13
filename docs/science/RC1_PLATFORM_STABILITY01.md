# Common GNU x86-64 application arithmetic profile

## Proposed successor,13November2026

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

## Selected admission evidence

Before promotion: fresh WindowsGNU16/UbuntuGNU15 public O0 four-day and O2 complete
1827/1096/1461-day controls, exact within-profile physical/CSV/native own
continuations, source/profile/compiler refusals, independent-instance/discard
contracts, matched GNU15 Hupsel point/full/native assessment and source/build
identities. Each model invocation is capped60seconds. Whole candidate cohorts
are expected to take3-4minutes including compilation. Scientific references are
reused rather than rerun under a new profile and silently relabelled.

Moving full F-CI, active macropores and retired highest-low-air campaigns are
not selected: their model/contract/default build paths are unchanged. No such
gate is claimed PASS. This document is a proposed profile until the owning
qualification and actual canonical PR postimage have been verified.
