# External daily acceptance of the consolidated original-block route

Proposed RT-TX application successor to canonical
`30026511e8d03f6c77bc30377d60a65259afb2fc`. The same three-project daily
host and all native/default process implementations remain unchanged.

## Problem and resulting behavior

`DailyHost.step` locally accepts a physical day immediately. It cannot let an
external caller inspect that day and decline it while retaining a reusable accepted
origin. The new `CoupledDailyColumn` adapter gives that caller `prepare`, `discard`
and `accept`, using private original donor/kernel processes and the existing schema3
restart and durable C publisher. Each proposal starts from the exact immutable
accepted native/auxiliary origin. No general framework or new physical codec is used.

A proposal explicitly reports `committed=False` and `candidate_only=True`; local
kernel acceptance is not external publication. Discard leaves accepted clock,
revision and package unchanged; retry reproduces the same physical records and
both complete candidate payloads. Accept checks origin/candidate bytes again,
publishes through the existing C owner, then advances the external revision.
The external revision is distinct from the private kernel's process-local revision.
Binding includes original input/build, adapter source and explicit coupling identity;
receipt lineage includes parent checkpoint SHA, origin revision and exact clock window.

The owner permits one live proposal. Foreign/stale/repeated decisions, implicit
native adoption and changed origin/prepared bytes refuse. Separate output directories
own independent instances. A publication failure may happen after replacement;
that owner refuses further proposals and requires explicit verified disk recovery.
It never claims that a failed directory sync was rolled back. Private diagnostics
remain retained, outside the externally accepted package namespace.

The original forcing policy is fixed and source-bound. Bottom amount is whole-day
cm positive outward; mean exchange is amount*0.01/(duration_day*86400) m/s,
and area-explicit volume is amount*0.01*area_m2 m3. No pressure head is relabelled
as hydraulic head or terminal flux as integrated exchange. Andelst3, Grass1 and
Hupsel6 boundary modes remain unchanged. Existing Groundwater Coupling v1 semantic
and publication authorities are reused; this adapter does not implement its
restricted-pc1 feedback solver, a new forcing override, peer-model backend or
atomic multi-party commit. The external caller owns coordination with its partner.

```python
import sys
from pathlib import Path
sys.path.insert(0, 'app/hybrid_water')
from daily_host import HUPSEL
from daily_coupling import CoupledDailyColumn

column = CoupledDailyColumn(
    Path('/work/hupsel-O2'), Path('/work/original'), Path('/work/coupled-column'),
    HUPSEL, 'field-column-17',
    origin=Path('/work/hupsel-O2/continuous/accepted-column-1-day-2.zip'),
    day=2, adopt_native=True)  # explicit adoption of a verified native package
proposal = column.prepare()
print(proposal.budget, proposal.mean_bottom_outward_m_per_s)
column.discard(proposal)       # no externally accepted day3 package
proposal = column.prepare()  # exact retry from accepted day2
checkpoint = column.accept(proposal)
# A fresh owner resumes only with the same explicit coupling/source/build binding.
resumed = CoupledDailyColumn(
    Path('/work/hupsel-O2'), Path('/work/original'), Path('/work/fresh-owner'),
    HUPSEL, 'field-column-17', origin=checkpoint, day=3)
```

## Actual qualification and cost decision

Windows GNU16.2 and Ubuntu26 GNU15.2 use the exact admitted originalO2 donors
and both O0/O2 SWAP5 kernels. Source/generated/executable/original-input hashes
are checked before reuse; no original model is recompiled and no full application
or reference is rerun. C publisher compilation is measured separately.

All six cases per platform pass: explicit native day2 adoption, prepare/discard,
exact retry, peer/stale/busy refusal, accept day3, fresh external recovery through
day4, actual post-replacement failure and explicit recovery. Physical day3/day4
records match the unchanged admitted controls. Separate Hupsel controls refuse
modified native state, altered accepted origin, occupied owner directory and implicit
native adoption, and decline advancement of the retained original day1096 endpoint
before any trial. That terminal test reuses original full-run proof; it is not a run.
The existing Andelst cold/restored96-byte auxiliary limitation is unchanged: the
new comparison is exact SAME-ORIGIN repeated proposals and own external recovery.

Initial measured Windows feedback cost was90.9598015s, including62.3197337s
in66 identical C compilations. The adapter now lazily loads one stateless publisher
per owner and explicitly binds each private host before its first advance.
No shared module/global patch or DailyHost change is used. Final Windows feedback
is54.0675609s with24 C compilations costing26.2967821s. Linux changes from
24.479937765s/66 compilations to15.079757329s/24, with2.394897718s compilation.
All pre/post native payloads remain byte-exact. These are bounded interface-feedback
wall times including compilation and validation, not full-model speed ratios or
portable performance guarantees; native CPU time remains UNKNOWN.

Successful Linux current run:
[43104058773/job130802649326](https://github.com/abhedwig-cell/SWAP5/actions/runs/43104058773/job/130802649326),
source `7debee302675c864794e218b79c48286d95f5aac`. Previous measured control run
43103157732 at88116fdc9 is separately retained. All unrelated jobs are skipped.
The new application source and its actual qualification drivers remain unchanged
after the current qualified head; subsequent files retain/audit/document evidence.

## Reproduction and retained proof

Prepare paths from the existing PR1641 admitted build/capsules. On Windows the
workspace is the retained temporary directory; on Linux extract the admitted
Linux capsule to a new workspace and restore executable permissions on the six
`generic-*/day_donor` and `day_kernel` pairs. The existing owning workflow performs
this exact pinned reuse and checks `hybrid_daily_coupling` selection first.

```sh
python -B research/hybrid-water01/qualify_daily_coupling.py --platform linux --workspace /work/qualified-hybrid --output /work/external-daily
python -B research/hybrid-water01/qualify_daily_coupling_corruption.py --platform linux --workspace /work/qualified-hybrid --output /work/external-daily-corruption
python -B research/hybrid-water01/audit_daily_coupling.py --archive research/hybrid-water01/external-daily-linux-20261111.tar.xz --sha256 ca3fa5b0babad0a53c43e7e190fa35a1d016dcb635a478fe39a9b250c404b1b7 --base-archive research/hybrid-water01/hybrid-hupsel-linux-20261111.tar.xz
```

[Windows raw proof](external-daily-windows-20261111.tar.xz), 2400 files,
SHA256 `beb647405568e3000ea2b5d7d3ea6c4fe17e5575bb15681c505f197a87f57a02`;
[Linux raw proof](external-daily-linux-20261111.tar.xz), 2400 files,
SHA256 `ca3fa5b0babad0a53c43e7e190fa35a1d016dcb635a478fe39a9b250c404b1b7`.
They retain current and pre-reuse actual records, complete private/accepted native
payloads, compiler events, publisher binaries, inputs and exact executed adapter/
driver source bytes. Original donor/kernel binaries and inputs are inherited by
exact hash from the independently audited, canonically admitted PR1641 capsules.
The [complete current Linux log](external-daily-linux-ci-20261111.log.gz) retains
actual platform, commands and results. Source-bound
[contract](HYBRID_DAILY_COUPLING_CONTRACT.md) and owning record
`integration/f-ci/HYBRID_DAILY_COUPLING_20261111.json` define acceptance.

## Scope and next acceptance

Functional coverage remains three original projects; this adds externally controlled
serial daily publication/rejection with real models, rather than another component
formula proof. Reliability is exact accepted-origin replay/recovery and no tentative
external publication, with the existing daily water/solute guards retained. The
qualified direct windows are day2 through4 plus the Hupsel terminal refusal;
no full coupled application run, arbitrary feedback boundary, peer backend or
whole scientific qualification is implied.

Native Grass1827, Andelst481, Hupsel1096 and the admitted full hybrid runs keep
their own exact scopes and source dependencies. Day188/day584 original scientific
comparison failures and reference-resolution blockers remain visible. No scientific
criterion, mass tolerance, original physical block or numerical policy changes.

Next independent programme acceptance: inspect the consolidated original heat
owner's existing energy/storage/flux receipts and identify a concrete missing
all-process energy-accounting contract. Reuse current full-run records and existing
small accepted-heat drivers; select a new model calculation only for a specific
uncovered hypothesis. Do not repeat successful full/native/reference campaigns
or create a broader coupling framework.
