# MC-NUT01 accepted thermal continuation

Status: qualified owner contract; canonical admission follows PR #1246's final
merge receipt. Baseline:
`cd64c5044a29643a068c6151720f76b2e70f570d`.

The new explicit thermal application consumes one complete accepted Full Richards
water-flux trace and the locally committed endpoint heat profile. It derives the
daily N reaction temperature from the F-KT-certified grid, at the soil-N inventory
depth. Callers cannot substitute a prescribed temperature. Existing prescribed
environment and BASE applications retain their contracts.

Source authority is `SWAP/management_soil.f90` in the preserved B111 archive,
SHA256 `0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b`,
lines 361–374. Preserve the original ordered strict `<` depth selection, cm-to-m
conversion and weighted temperature accumulation. An exact-boundary layer is
excluded. A skipped thick layer does not terminate selection. Empty selection is
rejected instead of dividing by zero. Moisture/inventory depth semantics are not
changed by this temperature reduction.

The reduction's arithmetic envelope is explicit: 1–100000 layers, positive
thickness at most 1e6 cm, positive depth at most 1e4 m, finite temperatures with
absolute value at most 1000 C. These guards bound arithmetic before reduction;
they are not qualification of those physical extremes. The actual heat owner
retains its own tighter state contract, and the derived daily N environment
retains its admitted -20 to 60 C range. Inputs outside the envelope reject.

The water/heat candidate is accepted only on a local clone; material additions,
crop growth, reactions, transport and delayed senescence use their existing owners.
Publish water, heat, crop, soil N and pending residues together only after all
existing balance checks and endpoint matching succeed. Failure leaves every
committed owner unchanged. Diagnostics are observations, not committed authority.

Opaque continuation preserves the original certified committed owner. Native
continuation introduces distinct thermal tags, persists heat and the original
parameter/grid certificate, and reconstructs through the trusted F-KT boundary
against explicitly supplied immutable parameters. Old native tags and bytes stay
unchanged. Never certify a decoded state using a fresh caller-derived grid alone.
No solver scratch or duplicate last-temperature state is persisted.

Backend interface amendment: the existing water-trace admission explicitly
rejects heat without the mobile-salt layout. Add an optional explicit
`trace_accepted_soil_n_heat` request, default absent/false, for the restricted heat
layout with no salt and no frost. It requires the ordinary accepted water trace
request as well. This opens only observation of the existing accepted hydraulic
substeps; it changes no Richards or heat equation, numerical policy or acceptance
tolerance. All other optional-state exclusions remain intact. Existing callers
retain their original admission result. The new thermal N application is the
requesting owner. Targeted BASE byte preservation and new physical thermal trace
tests cover this change; broader owner preservation needs explicit reconciliation.

Affected invariants: 2, 3, 4, 7, 13, 21, 23, 25, 29, 30. F-KT remains the sole
water/heat commit owner; crop and N ownership and WOFOST81 fixation remain intact.
Pond/source integration remains open; aquifer remains rejected. Harvest/reset,
rotation, generic legacy/default activation and broader temperature domains remain
outside this unit.

Test selection before execution: first the small production reduction driver at
O0/O2 against a mechanically extracted original loop, then certified-state and
actual thermal Richards/crop/N composition. Preserve literal eight-pool/mineral,
supply, whole-N, pending-residue, rejection/retry/replay assertions; opaque and
fresh-process native continuation must agree. Test old BASE native compatibility
because the codec changes. Measure compile/link/native/validation separately.
The accepted-state closure necessarily includes the real backend; its initial
cost is UNKNOWN (prior joint owner approximately 5 minutes total). No full F-CI
or long low-air stress is selected by this contract: they do not discriminate this
new temperature reduction or its atomic restart. Admission requires explicit
reconciliation of the applicable owner guards, rather than fabricated inherited
PASS. Until that reconciliation completes this unit remains unadmitted.
