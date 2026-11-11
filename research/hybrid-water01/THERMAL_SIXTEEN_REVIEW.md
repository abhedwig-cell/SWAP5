# Sixteen versus four original heat solves: bounded discriminator

This is private research on canonical059728c6176ba9e0fe5005e1c1fb5e58ff8f89fb,
following the native cost attribution in PR1634. Production source and its
admitted one/four policy remain unchanged. A generated, renamed heat module
allows16 steps only inside the research driver. There is no application profile
or disk-checkpoint rebinding. Existing explicit state, forcing, hydraulic view
and energy guards are used directly.

The original six-boundary/state/refusal driver is reused with16 sequential
original implicit solves as the control. It retains existing1e-12 state/face
assertions, the production per-cell/global energy tolerance, A/B/A isolation,
committed-state preservation and invalid-forcing/stale-receipt refusal. The
whole required contract chain is compiled cold at both O0 and O2; no O2 object
is substituted into the O0 closure. Neither graph is the full application.

O0 and O2 produce identical numerical results in all six boundary cases.
At fixed0.04day outer intervals, the16/4 full-versus-two-half temperature-error
ratios span0.094801 to0.277138. Both routes would reject those long intervals
under the existing1e-5C budget; lower error alone is not labeled acceptance.

One fixed two-cell case, using the temperature/flux-correction top and zero
bottom heat flux, bisects the interval against the unchanged1e-5C budget:

| Quantity | Four steps | Sixteen steps |
| --- | ---: | ---: |
| Accepted interval estimate (days) | 0.0000728859334049048 | 0.000146104926679982 |
| Full/half temperature difference (C) | 0.00000999999999962142 | 0.000009999999967647 |
| O2 kernel CPU time per call (microseconds) | 1.25313 | 4.13223 |
| O0 kernel CPU time per call (microseconds) | 3.06748 | 9.80392 |

The accepted-interval ratio is2.00457 in this fixed case. This is a bisection
estimate, not a global monotonicity proof or a composed water/crop controller
measurement. The O2 kernel cost ratio is3.29752; O0 is3.19608. Each final
timing arm accumulates at least0.5 CPU seconds to limit Windows clock
quantization. These tiny-kernel timings are host/compiler observations, not
portable estimates of application acceleration.

The initial20k-call timing used too few CPU-clock ticks for a useful ratio.
Its successful numerical controls and coarse timings are retained separately;
only the precision run supports the reported cost conclusion. Initial native
checks total1.201s; final native checks total2.366s. Cold compile/link totals
are7.898s and6.278s respectively. All commands, raw generated source, modules,
objects, executables and output are retained in the353036-byte
[archive](thermal-sixteen-contract-20261111.tar.xz), bound by the
[selection/result](../../integration/f-ci/THERMAL_SIXTEEN_DISCRIMINATOR_20261111.json).
Verify without a model run:

```powershell
python -B research/hybrid-water01/audit_thermal_sixteen.py --archive research/hybrid-water01/thermal-sixteen-contract-20261111.tar.xz
```

Decision: this is a positive discriminator for reducing outer water/oxygen
trial frequency without weakening the thermal budget. It justifies composing
an explicit opt-in16 policy through the existing numerical interface, immutable
binding and own restart contract. Preserve one/four behavior exactly and first
measure a bounded native short-window benefit with O0/O2 owner/refusal and own
restart checks. No new complete trajectory is selected until that source is
qualified and a material composed benefit is verified. No whole scientific,
full surface-energy, runtime-parity or additional project-coverage claim follows
from this supporting contract experiment.
