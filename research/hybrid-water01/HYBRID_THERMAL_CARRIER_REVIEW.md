# Accepted original water carriers and the physical heat input boundary

Application successor to PR1643, baseline
`a0c07487c944ff7da2a7e3b502aa725f687e480a`.

## Delivered interface and decision

The opt-in original heat observation can now export actual original water faces,
root extraction, separate drainage inflow/outflow, matrixâ€“macropore net exchange,
subsurface drip, mobile/immobile increment, matrix area fraction and original soil
temperature endpoints at the **identical accepted heat step**. No heat or water
operation is changed. Default original launchers and SWAP5 host remain unchanged.

`app/hybrid_water/thermal_carriers.py` supplies an accepted-day read-only view:

```python
from thermal_carriers import read_accepted_carriers
inventory = read_accepted_carriers(trace, physical_receipts, project)
assert inventory['full_energy_balance_complete'] is False
```

Only committed days are included. The reader verifies nodal original water
recurrence, shared faces and contiguous complete day support. Nonfinite data,
changed water/face values and a displaced clock are refused. No nonzero water
amount is discarded by a thermal-donor threshold. Actual local soil temperature
endpoints are available; they do not establish an exact time-integrated energy.

The original `fluxes.f90` recurrence is the sign/unit authority. Original upward
faces become downward-positive integrated water. Drainage directions are separated
before summing levels. qimmob is retained as the original water-content increment,
not accidentally treated as a rate. Original macro matrix area weights its volume.
Macro is deliberately a **net matrix exchange inventory**, not an observation of
each opposing macropore-domain transfer. Its flagged unresolved thermal path must
not be interpreted as proof that every outward liquid donor is external: local
matrix outflow temperature endpoints are known, but macropore thermal state and
domain-resolved energy are unavailable. Gas motion is not inferred from theta.

## Actual distinguishing result

All six Windows original windows pass O0/O2 kernel/storage-owner controls with
original temperatureO2; all physical daily records and both complete native
endpoint payloads match corresponding original continuations exactly.

Ubuntu26 owning run43115292328/job130841606370 also passes all six cases at
`a913df87c80adaf9efbf363accf57cb2d109f867`. Windows has7,750 and Linux9,422
actual carrier/heat steps. The older platform-dependent Andelst stepping is
retained, not a cross-platform equality claim. Linux Andelst day3 includes
1.557112374001173e-5cm bottom inflow, which remains an additional unavailable
external donor path. Both platforms preserve exact same-platform original state.
Linux maximum nodal water residual is1.6479873021779667e-17cm; compile/link total
10.3156s. The actual newly invoked compiler binary hash/version was not separately
probed; frozen inherited compiler metadata, new commands/object/binary hashes and
runner identity remain separate provenance rather than a guessed compiler claim.

| Original window | Actual water evidence | Missing thermal authority |
| --- | --- | --- |
| Hupsel4-to6, day5 | top inflow2.4000000000000346cm; drainage out0.38441851392864157cm | Incoming water temperature |
| Grass2-to4, day3 | top inflow0.11098726691050208cm; root out0.0014973085487476772cm; bottom out0.13142582676890976cm | Incoming water temperature |
| Andelst2-to4, day4 | top inflow0.2124696876904175cm; net macroâ†’matrix0.05601174265607062cm; root out0.0005891940492487236cm | Incoming top water and macropore thermal/domain state |

The maximum Windows nodal water residual is below1.5e-17cm against the unchanged
1e-10cm budget. The original heat/conduction receipts independently retain the
unchanged1e-9J/cm2 budget. The exact observer and reader source identities,
input hashes, original source inventory, compile/link recipes, adopted checkpoints
and generated executable identities are retained in the proof capsules/record.

This answers the selected question without a speculative physics change: the
original inputs and observed states do not provide a complete physical heat
request. Air temperature is a conductive boundary, not a measured rain/irrigation
temperature. Soil endpoints are not a measured external groundwater/macropore
donor. A changing gas volume is not an independently known gas transport history.
The existing conservative-heat research request correctly requires these inputs;
it also retains a separate full-SWAP-energy flag even for its warm sensible scope.

The known production top/bottom thermal carriers, liquid sensible enthalpy owner
and whole-column storage owner remain unchanged. No new generic framework or
native restart schema is introduced. No temperature correction, zero-advection
assumption, inferred gas motion or residual-as-boundary compensation is selected.
The older reference/day188/day584 failures remain visible and unchanged.

## Reproduce only the bounded delivery

```sh
python -B research/hybrid-water01/qualify_original_heat_accounting.py --carrier-inventory --base-archive research/hybrid-water01/hybrid-hupsel-linux-20261111.tar.xz --workspace /work/original-base --output /work/carriers --case hupsel-O0 --case hupsel-O2 --case grass-O0 --case grass-O2 --case andelst-O0 --case andelst-O2
python -B research/hybrid-water01/check_thermal_carriers.py --runs /work/carriers
```

This relinks original temperature and the four existing small observation units;
immutable PR1641 objects, inputs, kernel and accepted origins are reused. Native
cohort cap240s, compiler/link cap45s each. Windows compile/link total12.5167s;
isolated native CPU and native/validation wall categories are UNKNOWN. This is
an observation experiment with additional I/O, not a model-speed benchmark.
No full original/native/reference application was repeated.

The owning record is
`integration/f-ci/HYBRID_THERMAL_CARRIERS_20261111.json`. Source inventory is
`thermal-carrier-source-inventory-20261111.json`; full raw proof and independent
source/object/endpoint/water/conduction/storage audit accompany the record.

## Functional scope and next delivery

Coverage stays three original projects. This block delivers real accepted water
path data for thermal coupling and a reproducible missing-input boundary, not full
physical energy or whole scientific equivalence. Original execution/restart proof
is preserved. No further historical heat run can measure absent donor temperatures.

Next independent functional acceptance: inspect the current generic external daily
coupling adapter's original forcing interface and determine a bounded, explicit
caller-supplied thermal-input handoff using existing thermal-binding owners. It
must distinguish caller-defined corrected physics from original execution and
refuse unavailable/nonfinite/foreign/rejected input before advancing accepted state.
Do not activate a new heat solver or select another full trajectory merely because
the inventory exists. Full physical energy needs an explicit physical-model and
input authority; it cannot be qualified from these source observations alone.

## Retained raw artifacts

Windows capsule `thermal-carriers-windows-20261111.tar.xz`:62,288,564bytes,
SHA256 `2e0c3fbc5efd12c20242004bbe1a7298659b2bf1cd69df417465535b555a8d68`.
Linux capsule `thermal-carriers-linux-20261111.tar.xz`:75,228,016bytes,
SHA256 `6d03dced083e4e18fa4e5e70a44d260eb0e1015da4e695e520b7c47af4d26825`.
Each retains348 files: exact executed observer/reader sources, generated original
unit, actual objects/executable/link recipe, accepted original origins/endpoints,
raw water/heat frames and actual-data refusals. Source-bound unchanged objects and
original inputs inherit the immutable same-platform PR1641 capsule. The complete
owning CI log is `thermal-carriers-linux-ci-20261111.log.gz`.

Independent audit command (data only, no compilation/model execution):

```sh
python -B research/hybrid-water01/audit_heat_accounting.py --archive research/hybrid-water01/thermal-carriers-linux-20261111.tar.xz --sha256 6d03dced083e4e18fa4e5e70a44d260eb0e1015da4e695e520b7c47af4d26825 --base-archive research/hybrid-water01/hybrid-hupsel-linux-20261111.tar.xz
```
