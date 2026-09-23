# TAB-HYD live production-handoff status — 2026-09-23

Status: **research closed for generated K0 representation; production implementation active elsewhere**

This note records live delta after the research closeout. It does not modify production authority.

## Current authorities

- current canonical: `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`;
- research branch: `research/tabulated-hydraulics-characterization`;
- production implementation branch: `work/f-tab02-generated-k0-provider`;
- production branch observed head: `a93eea45b4943c8188eac2f9d7e6ce7da936884e`.

## Research disposition remains unchanged

The research line supports a generated, immutable, raw-head400, MvG-equivalent constitutive provider for the admitted K0 / SWKIMPL=0 route.

It does not admit:

- legacy generic `SWSOPHY=1`;
- arbitrary user-supplied tables;
- SWKIMPL=1 production;
- a portable whole-model speedup percentage.

## Production handoff is now active

The production work unit `F-TAB02` exists and is separately owned.

Live status at the observed production head:

- F-TAB02 A: PASS;
- B: PASS;
- C: PASS;
- D: PASS;
- E: PASS;
- G dedicated qualification: PASS;
- G final closure: waiting on same-postimage sequential A→E→G replay;
- F/F0 remains held until G closure.

Research must not duplicate or bypass those production gates.

## Exact whole-Hupsel asset blocker has changed

The historical research closeout recorded the exact SWAP 4.3.1 distribution bytes as unavailable.

That statement is now stale for live handoff purposes.

The production work unit reports that the exact authorized asset has been materialized and verified:

- archive name: `SWAP_4.3.1.zip`;
- SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`;
- size: `8,959,314 bytes`.

The final whole-Hupsel gate is therefore no longer externally blocked on asset availability. Its current blocker is production-internal sequencing: close F-TAB02-G, then qualify the preregistered F-TAB02-F0 provider-selection/lifetime seam, then execute the exact M1-C3 whole-Hupsel gate.

## Production performance versus research performance

Research-only typed raw-head provider evidence showed larger local reductions, including about 19% provider-only cost and roughly 28–39% in a small four-node Reference-Richards fixture.

The current production implementation has independently reproduced the **sign** of the acceleration with smaller and more realistic bounded percentages.

F-TAB02-E owner run `35824004715`:

- 30-node provider: `-4.36%`;
- Reference-Richards profiles: `-12.08%` to `-17.10%`;
- serialized runtime profiles: `-4.72%` to `-9.18%`.

Confirmation run `35824244178`:

- 30-node provider: `-5.66%`;
- Reference-Richards profiles: `-15.43%` to `-17.80%`;
- serialized runtime profiles: `-5.87%` to `-8.10%`.

Interpretation:

- the acceleration survives migration into production-style ownership and validation;
- the exact research percentages are not portable;
- production evidence, not the research microbenchmark, controls eventual performance claims.

## F-SI39 / KSATEXM handoff

The research KX05/KX06 pattern has a production analogue under F-TAB02-G.

The dedicated production G rerun passed:

- constitutive branch gates;
- three-regime Reference-Richards gates;
- upper/lower serialized gates;
- neighboring unsupported profile fail-closed checks.

Final G authority is still held pending sequential same-postimage replay.

## Independent scale gate still in research

A 40-node typed Reference-Richards scaling experiment remains a research-only supplemental characterization.

The first execution failed before model evaluation because of scaffold defects. Those defects were repaired by:

- declaring the implied-do index in the generated 40-node grid stub;
- writing the scenario name into the 40-node case header;
- compiling the actual 40-node program rather than the earlier four-node integration program;
- using provider-consistent initial water contents;
- adding explicit fidelity, mass and nonlinear-iteration gates.

Current rerun: `35882147418`.

This scale gate is **supplemental**. It does not reopen the already closed K0 research handoff and it does not supersede F-TAB02-E production qualification.

## K1

K1 remains outside the production handoff.

The broader K1 route is reference-runtime blocked on difficult analytical cases and is not needed for F-TAB02 K0 admission.

## Next safe research action

1. Read scale40 rerun `35882147418`.
2. If scientifically green, record scaling characterization only.
3. If scientifically red, diagnose scaling limits without reopening the qualified K0 representation automatically.
4. Do not implement production changes from this branch.
5. Track F-TAB02 only as an external consumer of the closed research authority.
