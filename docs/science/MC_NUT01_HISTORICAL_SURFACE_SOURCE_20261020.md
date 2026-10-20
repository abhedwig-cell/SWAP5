# MC-NUT01 original surface-source diagnostic, 20 October 2026

**QUALIFICATION_ONLY.** This extends the negative-source investigation; it does
not admit negative N forcing, persistent ponded Soil-N, or full historical-model
equivalence. Canonical baseline is `b0c2e94b69d7d21519611af92866fb4dbf713ea2`.
Production source tree remains `06d4d60b83432f4fbd54178437d29d47d4efb16d`.
The existing [closure report](MC_NUT01_FINAL_CLOSURE.md) and
`historical_surface_source_diagnostic` in the existing MC-NUT01 status own the
result. No capability disposition or mastercoverage denominator is promoted.

## Original authority and executable boundary

The decoded `SWAP431_B111_AUTHORITY.tar.gz.b64` has SHA256
`18396ecb9ec297e360d9ef720b8f5359522bca05070c6305c5d9608324247f4c`.
The runner pins this identity before extracting:

* `boundtop.f90`: the literal `h0max` producer and complete `PONDRUNOFF`, including
  its original internal runoff function;
* `integral.f90`: literal gross rain and runoff integration statements;
* `management_soil.f90`: literal `help` aggregate;
* `wofost_soil_watern.f90`: the complete, byte-identical original routine.

Original `swap.f90`, `readswap.f90`, and `timecontrol.f90` are included for source
inspection. Original `headcalc.f90` calls `boundtop(2)` followed by `pondrunoff`
when `FlRunoff` applies. `swap.f90` integrates accepted water before the day-end
`Soilmanagement(4)` call. The integral reset clears gross rain and runoff, and
records the current pond separately; it does not empty pond storage.
The inspected daily-output branch permits `outper=1` with a new interval each
day. This diagnostic imposes that daily interval explicitly, rather than executing
the original timer or whole management routine.

The top-node head is prescribed at 0 cm, conductivity at 0.01 cm/day and node
distance at 0.5 cm. Module scaffolding supplies these states and switches; it is
not an original Richards solve. Original runoff uses fixed `pondmx=0.1 cm`,
`rsro=1 day`, exponent 1, with no macropores, snow, irrigation, runon,
interception or evaporation. Those runoff values are within the original
`readswap` input bounds. Finite runoff resistance allows pond height to exceed
the threshold. No threshold change or externally imposed initial pond is needed:
the first wet step produces the pond used by the second dry step.

## Equations and measured results

For this selected original linear-runoff branch, with all lengths in cm:

\[
p_1=K\Delta t/d,\qquad
P_1=\frac{P_0+q_0\Delta t-K\Delta t+p_1h+\Delta t P_{max}/r}
 {1+p_1+\Delta t/r},\qquad
R=\Delta t(P_1-P_{max})/r.
\]

The independent water assertion evaluates infiltration
\(I=K[1+(P_1-h)/d]\Delta t\) and
\(P_0+rain\Delta t-R-I-P_1\). The actual original N aggregate reduces to
\(q_N=0.01(rain\Delta t-R)/outper\) m/day.

| Original surface-process step | Rain (cm/day) | Initial pond (cm) | Runoff depth (cm) | Final pond (cm) | N carrier (m/day) | Water residual (cm) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Wet | 2 | 0 | 0.93465346534653471 | 1.0346534653465347 | 0.010653465346534654 | 0 |
| Dry | 0 | 1.0346534653465347 | 0.45675914126066075 | 0.55675914126066073 | -0.0045675914126066079 | 0 |

Thus an original surface-process composition can produce a negative aggregate
from stored water. It is not valid to declare that aggregate impossible merely
because rain, irrigation and runon are individually nonnegative.

The second carrier is then supplied to unchanged `Wofost_SoilWaterN`, with
constant water fraction 0.3, depth 0.3 m, top concentration 0.005 kg N/m³, and no
other process flux. These are separate conditional N calls: the depleted initial
stock is **not** obtained by simulating N on the wet first step.

| Conditional N stock | Initial (kg N/m²) | Specified external input (kg N/m²) | Final (kg N/m²) | Signed residual (kg N/m²) | Absolute relative residual |
| --- | ---: | ---: | ---: | ---: | ---: |
| Funded | 0.002 | -2.2837957063033041e-5 | 0.0019771620429369671 | 0 | 0 |
| Depleted | 1e-8 | -2.2837957063033041e-5 | 9e-14 | -2.2827957153033037e-5 | 0.99912465215402724 |

Residual is initial + specified input − final. Relative residual uses
initial + absolute specified input as scale. The depleted deficit is
0.22827957153033037 kg N/ha; it exceeds the admitted 1e-12 kg/m² daily balance
tolerance by over seven orders of magnitude. It is not an optimization effect.
The original concentration floor leaves a nonnegative stock while the specified
negative external input exceeds available N.

GNU Fortran 13.3 O0/O2 raw outputs are byte-identical. Fresh final execution
`121e675d` measured 0.312131347 s combined compile/link and 0.003518194 s native
execution. Compile/link separation and physics-only cost are UNKNOWN.

## Consequence, preservation and remaining proof

The preserved reference choice is the original gross-input convention. Its
negative depleted-stock branch conflicts with hard element conservation.
SWAP5 therefore continues to reject negative aggregate input atomically.
Admitting that branch requires an explicit, separately qualified reference
resolution; neither silent clipping nor a newly invented surface-N inventory is
authorized by this diagnostic.

**Complete original caller reachability remains NOT_PROVEN.** In particular,
these runs do not solve the historical water column or evolve historical crop
uptake until the same depleted stock and negative aggregate coexist. They do not
replace the previously admitted actual SWAP5 Richards/crop/N calculations,
rollback or fresh-process restart evidence. Snow/interception, persistent ponded
application, remaining native grammar/output and complete original multiyear
comparison remain separate unqualified envelopes.

No production, shared transport, test, input-parser or existing admission-guard
source changes. The existing exact NUT/grid source and evidence authority is
revalidated; full F-CI and repeated coupled runs are NOT_SELECTED_IMPACT.
RossFast and highest low-air remain NOT_SELECTED_POLICY. MC-SOL01 science is
unchanged. The nine existing master rows keep ACTIVE_MIGRATION with their
previously admitted bounded facets.

## Reproduction and immutable evidence

From a clean checkout with GNU Fortran 13:

```bash
FC=gfortran N_SURFACE_SOURCE_RESULT_DIR=/tmp/nut-surface-source-fresh \
  PYTHONDONTWRITEBYTECODE=1 \
  python integration/audits/run_nut_historical_surface_source.py
PYTHONDONTWRITEBYTECODE=1 python tests/nut-crop/verify_hist_native_successor.py
```

The output directory must not exist. Evidence
`integration/audits/evidence/MC_NUT01_HISTORICAL_SURFACE_SOURCE_20261020.tar.xz.b64`
has decoded SHA256
`40b8bf7d5e07cc2c4a6a7dc8d088a349f0a6d4b3c975145acf148cd51f30030b`,
40,992 compressed bytes and 47 members. It preserves both the initial diagnostic
and final archive-pinned execution, source scaffolding, original files, runner,
commands, raw stdout/stderr, timings and a per-member SHA256 manifest. The first
execution is historical feedback; only the final execution binds the final
runner identity. Executables, objects and module files are excluded.

Evidence integrated by [PR1334](https://github.com/abhedwig-cell/SWAP5/pull/1334), qualified head `609bb095ae30b696b3ddc1ce5cd6ee684c5355eb`, canonical merge `820bc86ef33ff09cb7b1a938d542163bacc7e61a`, identical tree `f3662dfe16fa5bd1bb411753d67120080e350c02`. The existing NUT/grid authority passes on the actual merge. This integrates the diagnostic evidence, without production admission of the negative-source envelope.
