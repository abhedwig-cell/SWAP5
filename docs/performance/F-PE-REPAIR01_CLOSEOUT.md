# F-PE-REPAIR01 closeout — inactive-root qbot ownership

Date: 2026-09-26

Status: `CLOSED_QUALIFIED_REPAIR`

PR:
`#637 — F-PE-REPAIR01: inactive-root qbot ownership repair`

Branch:
`work/f-pe-repair01-root-sink-qbot-ownership`

Parent:
`F-PE-REPRO01`

## Defect closed

The prescribed-head mode-5 bottom-flux materializer read:

`richards%provider_root_sink`

even when no root-sink provider was associated.

That vector is worker scratch, not authoritative state, on the root-inactive route.

Its undefined contents could contaminate reconstructed qbot and drive the exact corrector into the characteristic status-6 / retry-advised failure.

## Repair

The materializer now distinguishes ownership explicitly:

- associated root-sink provider: sum the provider root-sink vector;
- no associated root-sink provider: root-extraction contribution is exactly zero.

This is the smallest repair consistent with the request semantics.

No general workspace zeroing was introduced.

## Causal evidence

The causal chain is now closed:

1. Valgrind traced uninitialized use to Reference workspace allocation.
2. Full directional workspace poison reproduced the spontaneous failure signature.
3. Scratch-family splitting isolated PROVIDER.
4. Singleton splitting isolated `provider_root_sink`.
5. Original code with ROOT_SINK poison failed 100/100.
6. Test-only conditional inactive-root qrosum with the same poison passed 100/100.
7. Production repair makes ROOT_SINK poison pass 40/40.
8. Root-active repaired versus old-equivalent behavior is bit-identical across 20/20 paired trials.

## Repeatability restoration

Before repair, the fixed-build live experiment produced:

- exact: 12/20 PASS;
- A2C: 16/20 PASS.

After repair:

- exact: 20/20 PASS;
- A2C: 20/20 PASS.

The live coupled reference route is therefore restored as a usable qualification/timing authority for this fixture.

## Preservation

Qualified after repair:

- exact first-corrector: 40/40 PASS;
- inactive-root provider poison matrix: all arms PASS;
- root-active old-equivalent parity: PASS;
- A1 live coupled control: PASS with exact endpoints;
- A2C live coupled control: 6/6 PASS with exact endpoints;
- A2C application sequence: PASS with zero mass/accounting differences.

## Performance interpretation

REPAIR01 is not itself a performance optimization.

However, it removes the reference nondeterminism that blocked PROFILE05.

The post-repair observations again support continuing the practical performance line:

- A1 remains qualified;
- A2C coupled robustness is reproducible in the current qualification set;
- A2C application-shaped speed remains material;
- combined A1+A2C end-to-end measurement may now be resumed in a separate observation workunit.

Do not infer a combined practical-stack speedup from the separate A1 and A2C percentages.

## Repository-wide red gates

Some broad preservation/publication workflows remain red because the stacked development lineage already differs from historical owner surfaces outside REPAIR01.

The repair PR itself changes one production file:

`src/adapter/mod_reference_richards_legacy_binding.f90`

plus its dedicated workflow/test/documentation files.

Unrelated red preservation gates are not repaired or suppressed here.

## Final decision

F-PE-REPAIR01 is closed as a qualified production repair.

The next performance action is to resume the observation-only practical-stack rebaseline on a postimage containing this repair, measuring A1 + A2C together rather than combining earlier percentages.
