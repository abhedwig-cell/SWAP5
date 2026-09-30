# F-PE-NLGLOB14Z32 closeout — stable n=13 interface-equation attribution

Date: 2026-09-30

Final status:

`QUALIFIED_Z32_MIXED_INTERFACE_MECHANISM`

Qualification authority:

- workflow run `36764856243`;
- HEAD job `110056341910`;
- RUNOFF job `110056341456`;
- both jobs SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z32 closes the static same-origin n=13 equation-attribution route.

All 12 frozen stable observations reproduce full versus reduced candidates to roundoff.

No material discrepancy is found in:

- guard-node storage;
- reconstructed tail storage;
- reconstructed tail pressure heads;
- face 12/13 trapezoidal forcing;
- nominal interval ledger.

The only recurrent full-minus-reduced difference is an order-1e-14 cm/d saturated-tail face-13/14 flux produced by floating cancellation in the full representation and often exact zero in the analytic reduced reconstruction.

Using the preregistered 64-epsilon rule with O05 Ksat = 17.418504 cm/d gives a flux roundoff scale of about 2.48e-13 cm/d, so the observed difference is not materially significant.

## Scientific conclusion

The hypothesis that Z31R long-horizon drift is caused by a simple local n=13 interface-equation defect is falsified at the frozen same-origin points.

Z31R and Z32 together imply:

- independently driven trajectories can slowly separate;
- replay from the same accepted origin collapses that difference back to roundoff;
- the mechanism is therefore trajectory-history / error-propagation behavior rather than a missing static storage or flux term.

Do not patch the interface equation based on Z32.

## Strategic implication

The adaptive moving-interface manager remains a promising route:

- protocol-correct adaptive driving reaches 540 d in both fine fixtures;
- no physical hard blocker occurs;
- both fixtures reach the same final tail;
- deterministic nonlinear algebra work is reduced by about 20%;
- the remaining long-horizon differences are extremely small in absolute hydrological terms, though they exceeded the deliberately strict scientific-reference envelope used in Z30.

The next phase should therefore stop searching for a local algebra bug unless new evidence demands it.

Instead, separate two questions explicitly:

1. **scientific-reference mode:** characterize trajectory-history amplification and convergence;
2. **practical SWAP Heritage manager:** define and test a physically meaningful error envelope against the achieved performance benefit.

This separation must be preregistered; it may not retroactively change Z30/Z31 results.

## Direct successor

Open:

`F-PE-NLGLOB14Z33 — trajectory-history amplification and practical-envelope bridge`.

The successor should characterize independent full/reduced divergence in the stable n=13 regime and provide the evidence needed to decide whether the current reduced manager is suitable for broader production-shaped qualification.

Do not introduce:

- fitted corrections;
- mass redistribution;
- tolerance changes to historical workunits;
- anti-chatter logic.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z32

BRANCH: `research/f-pe-nlglob14z32-n13-interface-attribution`

RESULT POSTIMAGE BEFORE CLOSEOUT: `5c00b861fd0e451d9e57799449ef752c9d9a980e`

QUALIFICATION STATUS: `QUALIFIED_Z32_MIXED_INTERFACE_MECHANISM`

NEXT SAFE STEP: Z33 trajectory-history amplification / practical-envelope bridge.

## Production boundary

No production source/default change.

`LEGACY_NUMERICS` remains production default.
