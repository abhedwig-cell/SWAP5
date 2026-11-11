# Original heat receipts and physical-energy completeness

Qualified read-only application successor to canonical
`f5606e455cf1e558d23e3a0af5b7d8847fbdc954`. This qualifies a shared bridge
from the actual original heat solve to existing production sensible-storage
accounting. It does not replace original heat physics or qualify full energy.

## Concrete result

The original temperature routine solves conduction with a frozen mean water-
dependent heat capacity. Its numerical conduction closure is not the same as a
complete changing-composition sensible-energy balance. Existing
`mod_whole_column_sensible_energy_accounting` already distinguishes these scopes;
the missing piece was observing its actual original inputs at accepted model days.

`heat_accounting.f90` receives original grid, water0/1, temperature0/1, mean heat
capacity and independent conductive faces immediately after the unchanged original
Thomas solve. Original material fractions supply the solid capacity. Three existing
production accounting units are reused without modification. The observer's actual
call leaves mass-carried heat/reference terms unavailable and preserves the owner's
`WCSA_INCOMPLETE_BOUNDARY` status. A separately labelled counterfactual supplies
zero missing advection solely to measure its projected residual.

All reported sensible quantities use the explicit **0 degrees C reference** of this
observer. They describe the material represented by the original soil-temperature
owner, not all pond/macropore/plant/atmospheric reservoirs. A different caloric
reference requires consistently translated mass-carried energy; no missing donor
temperature is inferred from air or soil temperature here.

The initial distinguishing Hupsel4-to6 original irrigation window contains278 heat
calls. Actual conduction closes to5.74e-13J/cm2, below the existing1e-9J/cm2
numerical heat budget. All278 real storage evaluations return incomplete boundary.
The zero-missing-energy counterfactual reaches3.429024786J/cm2 per step. It
**fails** the unchanged budget. This is a source-formulation/accounting coverage
limitation, not proof of a migration implementation error, a measured whole-model
energy residual, or permission to alter temperatures or silently book a residual
as boundary heat. The zero assumption is the failed comparison; actual full
physical energy remains **unavailable/unqualified**.

## Accepted observation interface

`heat_receipts.read_accepted_heat(trace, physical_receipts, project)` returns daily
conduction/storage evidence only for kernel-accepted days. Calculated but unaccepted
days are omitted. Incomplete day support, nonfinite frames, promoted full-energy
flags, noncancelling faces or numerical conduction exceeding1e-9 refuse the view.
It independently reconstructs the numerical balance from actual exported coefficients,
not another temperature model. Every result retains
`full_energy_balance_complete=False` and unavailable sensible mass-carried boundary.
A reported complete storage calculation is not a complete boundary balance.

The observer is opt-in through the bounded qualifier/relink recipe; existing public
model launchers, daily host, coupling adapter, original source distribution, default
profiles and physical/numerical tolerances are unchanged. Removing precisely the
marked observation blocks recovers the entire original temperature source text
after explicit platform CRLF/LF normalization. Windows raw bytes also match;
Linux read_text/write_text normalizes the selected source's CRLF to LF. No
original constitutive or Thomas operation is changed. Each observed donor has a new
source/object/executable identity and explicit verified original-origin adoption;
no accepted original ZIP is rebound to the observation profile.

```python
import json, sys
from pathlib import Path
sys.path.insert(0, 'app/hybrid_water')
from daily_host import HUPSEL
from heat_receipts import read_accepted_heat
window = Path('/work/heat-observation/hupsel-O2/window-4-to-6')
accepted = [json.loads(line) for line in (window/'daily.jsonl').read_text().splitlines()]
receipt = read_accepted_heat(window/'original/original-heat-accounting.txt', accepted, HUPSEL)
assert receipt['full_energy_balance_complete'] is False
```

## Actual generic qualification

Original donor temperature code remains O2. The new production accounting closure
and unchanged SWAP5 kernel run at O0/O2. Actual Windows GNU16.2 and Ubuntu26
cohorts cover original Grass2-to4, Andelst2-to4 and Hupsel4-to6. Every physical day
record and both complete native/auxiliary endpoint payloads match the corresponding
admitted same-platform original continuation exactly. Andelst's older cold/restored
auxiliary limitation is unchanged; these are corresponding warm continuations.

| Project | Windows heat calls per optimization | Largest step conduction residual, J/cm2 | Largest zero-missing-energy counterfactual, J/cm2 |
| --- | ---: | ---: | ---: |
| Hupsel | 278 | 5.74e-13 | 3.4290 |
| Grassgrowth | 52 | 1.79e-12 | 0.9753 |
| Andelst | 3545 | 1.55e-12 | 0.2432 |

Linux has278/52/4381 calls respectively and the corresponding same-platform
original state remains exact. The compiler/platform-dependent old Andelst stepping
is retained; no cross-platform byte equality is asserted. Every actual storage call
retains status3 and the missing-energy counterfactual fails on both platforms.

The accepted-only reader discards every unaccepted observation and rejects an
actual independently corrupted conductive face. Full-energy flags cannot be promoted.
The successful initial Windows HupselO2 probe is reused: only the remaining five
Windows cases were subsequently executed. Linux executes one complete six-case
cohort. No full original/native/reference trajectory is rerun. Only three existing
accounting units, the new observer and instrumented original temperature unit are
compiled; all other source-bound donor/kernel objects and original inputs inherit
immutable PR1641 capsules. Compile/link commands and durations are retained; native
CPU and isolated native/validation wall categories are UNKNOWN rather than guessed.
The overall native qualifier cap is240s and each compiler/link command45s.

Owning Linux run:
[43109370745/job130821031484](https://github.com/abhedwig-cell/SWAP5/actions/runs/43109370745/job/130821031484),
source `b7ca516f60caa448109a0f72980d9948de1f25e9`, SUCCESS. All unrelated jobs
are skipped. Later changes retain/read/audit evidence; the executed application,
Fortran sources, original observer qualifier and actual reader remain unchanged.

## Reproduction and raw proof

```sh
python -B research/hybrid-water01/qualify_original_heat_accounting.py --base-archive research/hybrid-water01/hybrid-hupsel-linux-20261111.tar.xz --workspace /work/heat-original-base --output /work/heat-observation --case hupsel-O0 --case hupsel-O2 --case grass-O0 --case grass-O2 --case andelst-O0 --case andelst-O2
python -B research/hybrid-water01/check_original_heat_accounting.py --runs /work/heat-observation
python -B research/hybrid-water01/audit_heat_accounting.py --archive research/hybrid-water01/original-heat-linux-20261111.tar.xz --sha256 46a7e502b4e46bb460b2c9222d893fb619197f89028371b61a7998b828ced338 --base-archive research/hybrid-water01/hybrid-hupsel-linux-20261111.tar.xz
```

[Windows raw capsule](original-heat-windows-20261111.tar.xz),29788740bytes,
SHA256 `53350b8cfb37eb5b7a89a3f6c63bf99877792ce3572c1e5550b3360ff5006ade`;
[Linux raw capsule](original-heat-linux-20261111.tar.xz),35832564bytes,
SHA256 `46a7e502b4e46bb460b2c9222d893fb619197f89028371b61a7998b828ced338`.
They retain exact sources, generated observation blocks, actual objects/binaries,
link recipes, raw unrounded nodal/face/step data, physical receipts and complete
endpoint packages. Source-bound inherited objects/inputs are anchored to the
unchanged admitted PR1641 raw capsules. Deliberately corrupted face files are
retained losslessly as a one-line byte patch plus complete reconstructed SHA, so
large otherwise identical traces are not stored twice. The independent reader
verifies the reconstruction before auditing originals. Full uncompressed controls
and both first uncompacted capsules remain locally retained as historical material.
[Complete Linux log](original-heat-linux-ci-20261111.log.gz) and owning record
`integration/f-ci/HYBRID_HEAT_ACCOUNTING_20261111.json` retain CI/build provenance.

## Scientific disposition and next functional delivery

Functional project coverage remains three original configurations. This block adds
accepted-state observability and a fail-closed energy acceptance boundary; it is
supporting balance/reliability evidence, not another full-project migration claim.
It distinguishes a correct numerical conduction solve from an unqualified physical
energy closure using actual process states, without changing physics or tolerances.
Native1e-5C temporal qualification, whole energy and whole scientific equivalence
remain separate. Original day188/day584 failed comparisons and independently
underresolved reference families remain visible; no new reference campaign is selected.

The next coherent energy-coupling block must inventory actual water/root/drain/macro
thermal carriers and their temperatures using existing production carrier/storage
owners and the conservative-heat request contract. Unknown external donor/reference
inputs must remain unavailable. Do not compensate with the measured residual or
rerun the proven conduction-only experiment. Select a small actual accepted source
window only if it can determine whether a defensible mass-carried energy contract
can be assembled; preserve the original heat route and its scientific limits.
