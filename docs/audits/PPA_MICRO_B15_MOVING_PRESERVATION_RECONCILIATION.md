# PPA-MICRO02–06 and B15 moving preservation reconciliation

Status: candidate successor under qualification, not a canonical admission.
Target is `integration/f-ci-canonical` at
`e5eab995ef04fc813dd644025fb0f32e4f5050a1`; draft PR #1077 is the
review surface. MICRO production source tree is pinned to
`ac822aafd5403547a2c7ffad5c3ba02c9fa36496`.

The PPA-WU05B15 moving preservation check in F-CI run 37429592867 stopped
at its historical exact serialized backend pin. MICRO extends the backend
with an opt-in independent microscopic uptake route and extends the
application bootstrap with its physical parameter and forcing carriers.
The two postimages are respectively
`b7d8d3a1626a82e408434b584abda2c9fe5a520c` and
`32a218d3a08ca56e43ff4df35c56b3e3b67bf947`. All other B15 source
postimage checks remain exact and unchanged.

The candidate F-CI guard accepts these two postimages only when the *whole*
production source tree matches the named MICRO tree. For every other tree,
the historical B15 checks still apply. The B15 runtime, additional control
and finer-reference, and incumbent preservation runners have an explicit
`--micro-successor` switch with the same source-tree pin. Their default
historical preimage remains unchanged. The bounded frost workflow chooses
that switch only on the exact MICRO tree and runs normal and low-air routes
with O0/O2. This route must pass against the persisted PR merge postimage
before the guard can be treated as a qualified successor.

The dedicated MICRO stack gate passed on canonical-target PR merge
`d7572236fff9c91d572a8319aadcba2c36388b5d` in run 37429592800;
the source tree equals the tested branch tree. Local B15 normal runtime
completed six configurations at O0 and O2 with byte-identical output.
The normal B15 activation and finer-reference gate passed O0/O2. Its ten
incumbent preservation programs passed O0/O2 with identical outputs. The full local F-CI moving
preservation script passed with the exact MICRO successor marker and all
downstream moving preservation checks. All six low-air O0 configurations and
the activation/refinement controls passed, with output byte-identical to the
previous local B15 run. Their replay is
`docs/audits/evidence/PPA_MICRO_B15_LOW_AIR_O0_LOCAL.json`. Low-air incumbent
preservation and O2 remain in progress. No full frost compatibility claim is
inferred from this partial local result or the standalone MICRO stack gate.
Local receipts and exact output digests are recorded in
`docs/audits/evidence/PPA_MICRO_B15_LOCAL_SUCCESSOR.json`; its replay ZIP
contains 20 source-bound incumbent receipts, runtime outputs and the full
normal and F-CI logs.

Other historical workflows also reject the candidate because of fixed
source ownership/scope lists. For example, F-PE-ELASTIC09 application
behavior passed O0/O2 in run 37429593155, then its source-scope check
rejected the MICRO process, binding, backend and bootstrap paths.
PUB-P2E04 run 37429593171 failed compilation because its source list lacks
the already present drainage extended-exchange module; this is a separate
gate issue and cannot be counted as a MICRO behavior regression or pass.
Each affected owner must either qualify its new dependency surface or
document its immutable historical gate as outside this admission. No
historical scientific tolerance, mass gate or source postimage is relaxed.

F-KT22's EB-I25 preservation gate is a different kind of red check. Its
runtime fails at the external full-half outflow fixture after two prior
markers pass in run 37432003245. I ran the same unmodified gate in a clean
archive of the canonical preimage `e5eab995ef04fc813dd644025fb0f32e4f5050a1`
(`e5eab995:src` tree `52d5b774ce12369a7113e39445886d463fbe7dd2`). It exits
1 at the identical assertion, with `EB_I25_TWO_HALF_ACCEPTED_AGGREGATION`
and `EB_I25_MISSING_TOP_DONOR_FAIL_CLOSED` passing first. The baseline log
SHA256 is `7de696b5058501fda530235777cb2b5a8ab3fe9b16d09469e347e1ddc8225677`.
The compressed full log is
`docs/audits/evidence/PPA_MICRO_FKT22_CANONICAL_BASELINE.log.gz` (SHA256
`0bdd60cee6059525dbfa06be667450675336f12330e5721237741c8833b59a1c`).
This shows the failure pre-exists MICRO; it does not qualify EB-I25 or excuse
its separate repair by its owner. The central F-CI qualification, MICRO stack,
documentation and all B15 jobs except the still-running highest low-air job
passed on the draft candidate at `3d0e5f2effd9bb4855ec831890ca1335cbaaba42`.

Canonical admission remains false until the moving preservation and
controlling cross-workstream checks pass on the persisted merge tree and
the central F-CI owner records the accepted postimage.
