# Caller-controlled Cauchy water forcing in the hybrid daily adapter

Application successor to canonical `ce04a4db9a21f264c077d0832e2173e5468e9d70`.
This adds an actual water input consumer to the existing external daily transaction,
without changing original Fortran physics or the original-forcing default.

## Input and accepted-state contract

```python
from daily_coupling import CoupledDailyColumn, CAUCHY_FORCING
column = CoupledDailyColumn(bundle, reference, output, project, coupling_id,
    origin=day20, day=20, adopt_native=True, forcing_mode=CAUCHY_FORCING)
segment = column.cauchy_forcing(-80.0, -79.999, 'caller-aquifer-head-v1')
proposal = column.prepare(cauchy=segment)
forcing_receipt = proposal.forcing       # detached copy, no accepted state
checkpoint = column.accept(proposal)    # or column.discard(proposal)
```

The opt-in mode is `andelst-cauchy-daily-v1`, restricted to the original Andelst
SWBOTB3/SW3=2/SW4=0 configuration. Values are deep-aquifer heads in **original local
datum and cm**, not converted groundwater elevations or interface-cell pressure.
Original resistance, shape, implicit Cauchy formulation and interpolation remain
owned by the unchanged Fortran blocks. No peer groundwater iteration is added.

Each frozen segment binds coupling ID, accepted origin SHA/day, exact day1900
window, two heads and caller provenance. Nonfinite/bool/out-of-original-range heads,
foreign/stale origins and clocks, absent input/provenance and an override in original
mode refuse before an attempt or model advance. Original-project remains the
constructor default; external Cauchy mode requires an explicit segment every day.

Every private trial copies original inputs and changes only the requested aquifer
head knots. Original neighboring table rows and unchanged decimal spellings remain
intact. The original adaptive clock may evaluate a final abscissa a few ulps past a
nominal day; retaining the original table avoids changing that historical rounding
path. Original `ReadSwap` reads HAQTAB before native/auxiliary restore and `afgen`
uses the current `t1900+dt`; no saved HAQTAB interpolation cursor is introduced.

Private candidate packages have a distinct `external_cauchy_trial` input binding;
modified input is never labelled original-only. Public external acceptance persists
the exact input document/digest and actual worker BBC hash alongside the existing
complete native/auxiliary payloads. Proposal metadata is a detached copy. Discard
keeps the accepted origin/clock/revision; retry starts from identical immutable
state. Recovery verifies source/build/project/mode/coupling and stored forcing
lineage/digest. No new native codec, hidden global owner or shared Fortran change.

## Actual verification and numerical scope

Windows and Ubuntu26.04 pass actual original donorO2 with kernelO0/O2 for day20→22.
Original forcing, same-origin discard/retry and live-vs-cold external recovery
produce exact physical daily records and both complete endpoint payloads. An actual
0.001cm end-head perturbation changes the computed water exchange. Its entire day
record and both native payloads exactly match a separately edited original BBC
control using the unchanged DailyHost, not the new table-writing helper.

| Platform, both optimizations | Original one-day bottom outward amount,cm | Changed-head amount,cm |
| --- | ---: | ---: |
| Windows | 0.19533361561655016 | 0.19532362950912902 |
| Ubuntu26 | 0.19532446941794768 | 0.19537529078756663 |

These are **same-platform** original-control comparisons. The older platform-
dependent Andelst adaptive trajectory is retained. The signs and magnitudes of
these finite perturbations are not a common derivative, monotonic-response proof
or cross-platform scientific-equivalence claim. Both independent original controls
give exactly the corresponding platform result. No causal physics repair or new
reference campaign is selected from this application-interface evidence.

Six original-forcing Grassgrowth/Hupsel/Andelst adapter cases also pass, including
peer/instance ownership, own recovery, discard/stale refusal and ambiguous publisher
failure recovery. Mutated native candidate/origin and terminal-Hupsel guards pass.
Six additional corrupted persisted forcing inputs refuse before any model run.
Year364/365/453 BBC preparation is checked as **input transformation only**.
Actual externally forced year/481-day execution is not newly qualified. Original
full applications and their scientific/profile boundaries remain unchanged.

Old retained day20 has a different build binding. It is not relabelled. Current
compatible day20 is constructed once from accepted day2 by18 ordinary days per
needed build; the already accepted WindowsO0 prefix is strictly verified and reused
after a test-only presentation assertion failure. No full application is repeated.

All selected model processes are finished. Windows Cauchy cohort32.328s; Linux19.052s.
Current six-case original-forcing preservation is separately timed in its raw report.
No Fortran compilation is required; immutable admitted binaries/objects are reused.
Existing C publisher compilation costs remain explicit in the default report.
Isolated native CPU and native-only wall cost are UNKNOWN. This is not a full-run
speed/accuracy ratio. The native cohort cap is240s; no tolerance changes.

## Evidence and reproduction

Owning record: `integration/f-ci/HYBRID_CAUCHY_FORCING_20261112.json`.
The source-bound contract, actual failed probes, raw sources, build/input identities,
native states, forcing receipts and independent byte audits are retained under
`research/hybrid-water01`. Linux owning run43123554632/job130869817599 at
`20a85e286b48ed203ca923786dde1fba1b597d78` is SUCCESS. Later evidence/audit/docs
changes do not alter the executed application or model qualifier.

```sh
python -B research/hybrid-water01/qualify_cauchy_daily_forcing.py --workspace /work/extracted-original-proof --output /work/cauchy
python -B research/hybrid-water01/audit_cauchy_daily_forcing.py --runs /work/cauchy --output /work/cauchy-audit.json
```

Three development outcomes remain explicit: TTUTIL refused mixed real/integer
lexical columns; a shortened table changed last-ulp original results; and a direct
accepted receipt was initially compared with a deliberately uncommitted external
proposal flag. The fixes retain real lexical form, the larger original table and
separate publication status from physical quantities. Exact native comparisons and
all original physical/numerical guards remain mandatory.

Full energy, thermal feedback, a peer groundwater solver and whole scientific
equivalence are not supplied by this water input interface. The next bounded
functional extension is the same transaction discipline for the existing original
Grassgrowth prescribed-groundwater boundary, after inspecting its owning input/
state contract. Hupsel's original zero-flux bottom must not silently become a
head boundary. Reuse completed project evidence; no full trajectory is selected.
