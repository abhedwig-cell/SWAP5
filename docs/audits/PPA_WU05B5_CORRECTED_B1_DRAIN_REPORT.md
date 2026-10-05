# Bounded corrected B1 frost drainage reporting

Status: locally qualified source correction, not yet admitted as a reference
component. It does not migrate a SWAP5 production drainage path or promote a
new global B1 snapshot. The original byte-exact B1.11 source stays immutable.

The actual HeadCalc sink is the nodal `qdra`; Integral reports the separate level
and aggregate drain totals. The original low-air FrozenBounds SWDIVD=0 branch
changes level totals without changing the nodal sink. The reproduced
[source finding](PPA_WU05B_FROZEN_DRAIN_SOURCE_FINDING.md) establishes that these
owners can report different water.

FROST-DRAIN-01 corrects only ordinary `SWDRA=1`, `SWDIVD=0`, `SWMACRO=0` under the
existing low-air/deep-frost condition. After the original physical assignments it
recomputes each reported level from its final actual nodal sink. The existing
aggregate loop then derives qdrtot from these same levels. It changes neither
qdra nor qbot, the hydraulic factors, geometry, solver or restart. Surface-water
feedback (SWDRA=2) and macropores are guarded out rather than assigned a new
unqualified physical-equivalence claim.

The original and corrected actual FrozenBounds routines are compiled together
with separate test namespaces and explicit globals at O0/O2. Fifty-four cases
cover signed/zero bottom and drain fluxes, two levels with an above-frost cut,
normal air, shallow frost, no-drain and unchanged surface-water/macro guard
branches. Actual nodal and bottom outputs agree bit for bit. Ordinary corrected
level and aggregate totals equal the node sums, and independently calculated
node/report exchanges close. The pre-correction discrepancy is required to be
present in the affected signed cases; the test does not hide it by changing
physical sink values. This is a direct source-component probe, not a full legacy
simulation, an executed HeadCalc/Integral run or full SWDIVD=1 qualification.

The applicator accepts only the exact original source hash and one patch context,
checks the exact target hash, forbids overwriting the original and rejects a
conflicting existing output. Invalid-source and overwrite probes pass. Imported
and corrected reference copies retain CRLF/source bytes; authored tests, JSON and
docs pass whitespace checks.

Exact source/target identity and the bounded exclusions are in
`reference/swap-4.3.1/frost-corrections/FROST-DRAIN-01/manifest.json`.
Qualification and recovery are in `integration/audits/PPA_WU05B5_REF_STATUS.json`.
Run `bash tests/frost/run_ppa_wu05b5_corrected_drain_source.sh`.

Still separate: SWDIVD=1 redistribution, macropores, surface-water feedback,
invalid deepest drain indexing and frozen-depth interpolation/last-node policy.
The safe next SWAP5 unit is typed drainage flux composition with one final nodal
owner, initially bounding out low-air redistribution until its geometry contract
is separately qualified. This correction supplies a consistent reporting
reference for the ordinary source branch; it does not complete frost migration.

## Canonical reference-component admission

PR #1038 admitted this bounded component at `7257d884136396823286783971357ba2d80b836e`, after verifying proposed merge `6efafd69bb72bce332fcaab0d363d186541d6dfe` had exact qualified tree `834136ed2978aeeeeb146a5e2b28df2a57d5bb02`. The admission uses completed local gates recorded in the status authority; it makes no queued Actions success claim. The original B1 snapshot and SWAP5 production source remain unchanged.
