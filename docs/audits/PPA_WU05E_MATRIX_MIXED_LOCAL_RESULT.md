# PPA-WU05-E restricted matrix mixed-stress local result

Status: bounded application lifecycle qualified by the persisted replay below;
full salt transport physics and canonical admission remain held.
The source postimage and exact dependency hashes are recorded in
[`PPA_WU05E_MATRIX_SALT_LOCAL_GATE.json`](https://github.com/abhedwig-cell/SWAP5/blob/work/ppa-wu05e-salinity-state-root-stress-20261004/integration/audits/PPA_WU05E_MATRIX_SALT_LOCAL_GATE.json).
The design boundary is [the explicit matrix numerical contract](PPA_WU05E_BASE_SALT_TEMPORAL_CONTRACT.md).

## Result

The actual typed production application now reaches matrix dissolved-salt
transport with sensible soil temperature, real Feddes drought and Bartholomeus
oxygen, Maas-Hoffman salinity and Jarvis ALL compensation. The prior requirement
for macropores no longer blocks this particular combination. The established
oxygen/macropore incompatibility remains intact.

The mixed fixture produces positive residual drought, oxygen and salinity
losses after compensation. Their sum plus final root uptake equals potential
transpiration. The water residual is approximately 1.6e-16 cm in the mode-2
fixture, within its unchanged 1e-12 cm hard gate. Mode-7 application execution
also commits within that hard gate. The interval salt ledger independently
closes external soil-interface fluxes, root salt uptake and two signed drainage
levels. Prescribed subsurface irrigation adds water with zero solute under the
pinned source contract.

Unit salinity alpha preserves the hydraulic state and water receipt bitwise
against salinity-disabled execution on the same salt numerical route. Invalid
profile initialization is atomic; initialized inventory cannot be reinitialized.
A missing policy and invalid forcing provenance fail closed at bootstrap.
Backend reinitialization clears the opt-in policy and requires explicit
reconfiguration. An unattainable salt budget rejects a real full/half attempt with no published
candidate. A stricter attainable 1e-13 mg/cm2 budget exercises 46 temporal
rejections and 16 accepted substeps while completing the interval and preserving
an independent accepted-only salt ledger. These counts are fixture results,
not a performance recommendation.

The actual caller and application additionally execute seven stress cases:
drought only, oxygen only, salinity only, drought plus salinity, oxygen plus
salinity, all three with ALL compensation, and all three with salinity
selector 4. Each closes water/salt accounting and residual stress attribution;
accepted actual-transpiration publication equals the integral of the accepted
final nodewise root sinks.

## Persistence and preservation

The committed Restart v4 record preserves matrix salt and sensible temperature.
The test exports the decoded record, terminates the writer process and restores
it in a separately invoked executable. With changed boundary concentration and
revision, the full resulting hydraulic, salt and temperature payload is byte
identical to uninterrupted continuation. The test-only stream encoding is not
a public production restart file format. O0 and O2 physical continuation bytes
are also identical.

The existing D2 application, mixed drought/oxygen, accepted publication,
transaction and parallel preservation roles pass locally, as do D3 Walsum,
real Richards/macropore A8 and the independent process salt oracles. Their
recorded dependency hashes match the final production postimage. No claim of
all historical hand-listed build runners or all CI workflows is made.

## Claim ceiling

This verifies a restricted explicit dissolved upwind transport route, a short
four-node mixed fixture, and its application/transaction/persistence chain.
Dispersion, sorption, decomposition, surface mixing, dynamic aquifer salt
ownership, seasonal stability, and full B1.11 transport equivalence remain
separate migration work. The qualified physical source contract must precede
any broader production claim. Canonical admission has not occurred.

## Persisted bounded qualification

The final replay [37311241437](https://github.com/abhedwig-cell/SWAP5/actions/runs/37311241437)
completed successfully on source commit
`abff5c95fe4bd072f9e24c5497d6f4b2f069364a`, tree
`93d89b1422065fd037d714f2900dfc75dc92d5a6`. GNU Fortran 13.3 O0/O2
passed all seven actual stress cases, separate-process changed-forcing restart,
and the declared D2, D3, process and real Richards/macropore preservation gates.
The downloaded artifact digest matches GitHub metadata; all 816 recorded
source-manifest entries match the published postimage.

`integration/audits/PPA_WU05E_MATRIX_LIFECYCLE_QUALIFICATION.json` persists
the exact result payload and reviewed scope. This qualifies the bounded
application lifecycle described here. It does not qualify full B1.11 salt
transport. The review decision retains the draft PR and holds canonical
admission pending the independent transport physics migration.
