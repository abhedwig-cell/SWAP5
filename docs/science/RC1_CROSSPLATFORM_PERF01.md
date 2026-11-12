# RC1 cross-platform and performance successor

## Frozen scope and first transport discriminator

RC1 remains `release/swap5-nomacro-rc1-20261112` at
`11529865e76fb2259542f1e770726cd87af27603`. The workstream owns
`integration/f-ci/RC1_CROSSPLATFORM_PERF01_20261112.json`.
No active macropore or broad migration work is selected.

Existing exact-input benchmarks retain the GNU16.2/O2 original, actual input
bytes, output-only compatibility settings, failed literal CSV attempts and
original scientific FAIL dispositions. Mixed WindowsGNU16.2/LinuxGNU15.2
full trajectories are evidence of combined build/platform differences, not an
isolated operating-system effect or an accuracy-matched speed ratio.

The measured dominant wall bucket is waiting for the Fortran donor. Worker CPU
is reported separately from overlapping wall buckets. Process launch, Python
JSON and transcript flush are smaller; they are not assumed to explain the
whole SaltFarm ratio. Zero budget-step rejections do not mean zero extra Newton
iterations: the strict original-block mass-polishing policy is retained.

A full SaltFarm coherent-worker replay without the SWAP5 kernel reproduces every
unrounded physical record and the original CSV exactly. Thus Python/kernel state
transfer is not the source of the baseline field differences on this profile.
The generated worker still has daily return boundaries; this alone does not
exclude a Fortran day-return dependency. That distinction remains explicit.

## Internal exact hydraulic frame v1

The candidate changes only original-worker hydraulic output serialization. Each
binary64 groundwater, bottom flux and pressure-head value is transferred to an
ISO `int64` bit pattern and emitted as sixteen hexadecimal digits. The tag is
`HYBRID_HYDRAULIC_HEX_V1`; order remains groundwater, bottom flux, all grid heads.
This is a text framing change, not a binary restart codec or a process equation.
The Python receiver reconstructs the exact IEEE bits, checks word width and
finiteness, and supplies the existing canonical hydraulic view. Existing decimal
frames remain readable. Signed zero and all finite normal/subnormal values round
trip exactly. Empty, truncated, invalid-hex and nonfinite frames refuse.

No values, state, original process order, mass guard, rollback, journal durability,
input, user CSV, external transaction or restart codec are omitted or relaxed.
Source/build binding changes deliberately; old checkpoints are not rebound.
Candidate admission requires actual whole-trajectory and own-native-restart
preservation on each tested platform, and relevant O0/O2 coverage.

The output-only prototype preserves every SaltFarm CSV record and terminal
native/auxiliary byte. Its hex variant also preserves all daily unrounded heads.
Its one-shot cost change is only a discriminator, not the accepted speed result;
paired full application measurements determine whether the candidate is useful.
