# Hupsel original-block water and solute route

Proposed successor to canonical `3e0dc5e08c07719a7ac2107d54d7d74f954805f1`.
Windows and Ubuntu26.04 GNU15.2 owning model gates passed. PR1641 carries
the qualified corrected-original-block successor; admission uses the exact
reviewed source and verified canonical postimage, separately from scientific equivalence.

## Functional change

`HYBRID_HUPSEL_WATER` runs the original 34-node, 2002–2004 Hupsel project
through the existing SWAP5 daily transaction host. It retains original Richards,
bottom6, drainage, crop rotation, root uptake, heat and CDE solute blocks. It uses
worker-owned legacy globals and explicit project/grid/clock/source-bound state.
The public cap is the complete original 1096 days. Existing native profiles and
Grassgrowth/Andelst physical tolerances remain unchanged.

Three demonstrated original defects are corrected only in the generated Hupsel
units: the small-runoff shortcut failed to remove booked runoff from pond stock;
CDE applied its minimum solute step after truncation to the water endpoint;
harvest transferred interception to loss without clearing the transferred stock.
Existing analytic linear runoff, endpoint truncation and harvest destination are
retained. Additional original Newton convergence and one residual-polishing
iteration enforce the existing 1e-10 cm mass guard; no looser tolerance is used.
These are a corrected original-block profile, not bitwise equivalence to unmodified
SWAP 4.3.1. [Failed diagnostic records](HYBRID_HUPSEL_DIAGNOSTIC_FAILURES_20261111.json)
remain visible.

The Hupsel `S5HUP010` auxiliary state owns original solute CMSY/CSURF/SAMPRO,
full irrigation module and saved routine context, previous-day irrigation feedback,
and WOFOST potential/actual rates omitted by the native endpoint. Crop transitions
keep the original fresh-crop initialization rules. Both native endpoint and auxiliary
payload are required. Old Grass and Andelst restart formats are preserved.

## Actual verification

Windows donor O2 with SWAP5 kernels O0/O2 passes all three project prefixes,
own restart, distinct-instance, refusal and repeated-publication controls.
Andelst records and corresponding cold/restored payloads match the same-platform
canonical control. No new cold/restored Andelst macro equality is claimed.
Hupsel includes saline-gift day5, invalid solute/uptake framing and auxiliary-state
rejection. The independent auditor verifies the retained source/build/input hashes,
all complete-run daily records and both full restart payloads.

The complete run accepted 1096 days in **5.7971821 s**, excluding build. Maximum
daily water residual is **9.996691511691622e-11 cm**; signed cumulative residual
is **2.667338342115643e-10 cm**. Maximum daily solute residual is
**2.0189359137172196e-13 mg/cm2**; signed cumulative residual is
**-2.7119257298790236e-12 mg/cm2**. Both daily guards remain 1e-10 in their units.
Nine own windows reproduce every physical suffix record and both endpoint
payloads exactly: 2→4, 4→6, 5→7, 120→122, 365→367, 523→526,
583→585, 730→732 and 1061→1096. The independent potential/actual/dry/oxygen/salinity/frost uptake closure is at
most 7.584536297622346e-16 cm per day. The actual public launcher independently
reproduces 583→585 and its complete checkpoint.

[Raw Windows capsule](hybrid-hupsel-windows-20261111.tar.xz), SHA-256
`678be090346a13ffd3b68f2a3447a947f86e52b8854fdc46f9fef798ab8b21c1`,
retains 3642 files including actual sources, generated units, compiler/object/library
identities, binaries, original inputs, all records and immutable checkpoint payloads.
Source build is pinned in each BUILD.json; the full run names source
`22c6b8753e39c8f7fd3a9603ce3c4c8a86a6461d`. Later commits package evidence
and qualification commands; compiled dependencies have not changed.

```sh
python -B research/hybrid-water01/prepare_generic_hybrid_reference.py --output /tmp/original-work
python -B research/hybrid-water01/qualify_generic_hybrid_waterhost.py --reference /tmp/original-work --output /tmp/hupsel-O2 --project hupsel --optimization O2
python -B research/hybrid-water01/run_hybrid_grass_full.py --project hupsel --reference /tmp/original-work --bundle /tmp/hupsel-O2 --output /tmp/hupsel-full
python -B tools/solute/run_water.py --model HYBRID_HUPSEL_WATER --reference-work /tmp/original-work --output /tmp/hupsel-public --days 7 --checkpoint-at 5
python -B tools/solute/run_water.py --model HYBRID_HUPSEL_WATER --reference-work /tmp/original-work --output /tmp/hupsel-public-own --days 7 --restart /tmp/hupsel-public/accepted-column-1-day-5.zip --restart-day 5 --checkpoint-at 7
python -B research/hybrid-water01/audit_generic_hybrid_proof.py --archive research/hybrid-water01/hybrid-hupsel-windows-20261111.tar.xz --sha256 678be090346a13ffd3b68f2a3447a947f86e52b8854fdc46f9fef798ab8b21c1
```

Use O0 as a separate output for the other kernel optimization. Full-run hard cap
is 180 s and each own window 60 s; measured own windows are about 1–1.4 s.
No accuracy-matched speed ratio or whole-energy qualification is claimed.

## Day 584 scientific decision

The [read-only comparison](HYBRID_HUPSEL_REFERENCE_20261111.json) preserves
separate original reference identities. Current hybrid oxygen reduction is
0.004793906349978937 cm. Against the frozen application reference
0.003593541147 cm it **fails** the unchanged 5.371840000016327e-7 cm boundary.
The original native result 0.0033488614852679407 cm still fails too.

A separate retained original high-precision-output CSV gives 0.004793370692 cm;
its difference 5.356579789372526e-7 cm happens to lie within that boundary.
This single comparison does not independently qualify a replacement reference.
The existing temporal/grid/equal-state reference-resolution blockers remain.
No reference is silently substituted, no additional reference trajectory is run,
and no scientific equivalence is claimed for this corrected route.

## Linux qualification and next delivery

The [historical startup failure](HYBRID_HUPSEL_LINUX_BLOCKER_20261111.json)
remains retained. The successful replacement run is
[43098736948](https://github.com/abhedwig-cell/SWAP5/actions/runs/43098736948),
job130784487221, exact source `287de920c6099928ca4b1ccfee6223f3d8032a73`,
Ubuntu26.04.1 image20261101.186.1, GNU15.2. All six bounded project/kernel
controls, actual same-runner canonical Andelst preservation, full1096/nine own
windows and public Grass/Hupsel cold/continuation pass. Other jobs are skipped.
A temporarily proposed Ubuntu24 fallback was reverted before dispatch: stale
API queue data did not justify changing the successful qualification platform.
No duplicate model run was launched; an attempted queue cancellation returned409.

Linux full1096 took **3.256074393 s** excluding build; each own window took
0.10–0.20 s. Maximum daily water residual is **9.997065718650444e-11 cm**,
signed cumulative **2.6666888331351084e-10 cm**; maximum daily solute
**2.1610435979544247e-13 mg/cm2**, signed cumulative
**-2.7733259900138115e-12 mg/cm2**. The unchanged guards apply independently
on each platform; cross-platform byte equality is not required or claimed.

[Linux raw capsule](hybrid-hupsel-linux-20261111.tar.xz), 4536 files,
SHA-256 `feaec2daeada9b5f01f0391352a7b15910f406c4a0034123e65c58418cd67bde`,
includes the actual current and canonical builds, objects, original inputs,
raw records and immutable own payloads. The original Actions ZIP digest is
`23120fb2d277a29ee115bce220090e8b4af21da7128a133e79e479c0de2c9bfb`.
The [complete job log](hybrid-hupsel-linux-ci-20261111.log.gz) retains actual
compiler/runner identities and every command. Run the same independent auditor
above with the Linux archive and digest. Source, generated physics, CLI and
qualification-driver dependency paths are unchanged after the successful CI head;
later changes package/read/audit evidence and documentation only.

After verified canonical admission, the next functional delivery is an explicit
accepted-state external-coupling contract for the consolidated route, with its
own small transactional driver. First inspect existing qualified coupling/restart
coverage, reuse unchanged dependencies and preserve all three native applications.
The day584 scientific reference blockade remains a separate acceptance point;
do not restart successful full/reference applications or expand coupling scope.
