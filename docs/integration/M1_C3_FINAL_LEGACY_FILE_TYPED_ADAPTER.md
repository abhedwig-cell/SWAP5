# M1-C3 — final legacy-file to typed SoilWater adapter contract

## Purpose

This bounded M1-C3 workunit closes only criterion 3 of **M1 - Typed External Boundary**:

> legacy file runs still reproduce reference results through adapters.

The production subject is the existing legacy-file application route at the already-admitted SoilWater Task2 service seam. File parsing, crop/interception/irrigation/drainage application processing and historical output remain adapter-side. The SoilWater computation itself crosses the current typed soil_water_solver_t boundary.

This workunit does not create a second SWAP application runtime and does not replace the generic FMR or groundwater application services.

## Pinned authority

- live canonical preimage: bcfd670503f0fbc9e4b05fe4f3b772aa6d8e1c40
- exact SWAP 4.3.1 distribution SHA-256: 2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360
- exact B1.11 manifest SHA-256: 24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2
- exact Hupsel swap.swp SHA-256: a54d110efa0cf003b23537109a3aea83f17f941fa875a5de6aefd65291405b5b
- exact Hupsel 283.met SHA-256: 1de5ba86caded630f8c5b828648e8bda091115acd243891fe7d8b3551bc5add6

The existing admitted authorities reused by this workunit are:

- F-SI35 / F-KT15: mandatory typed SoilWater Task2 service seam;
- F-SI39: opt-in B1.11 near-saturated KSATEXM conductivity extension;
- F-APP02 / F-CI95: legacy SWBOTB=6 means typed prescribed qbot=0;
- F-APP03 through F-APP08: admitted active Hupsel application-process routes;
- the admitted root-sink provider and explicit source/sink service;
- admitted drainage and dynamic-surface boundary services;
- M1-C4: output serialization is read-only with respect to physical state.

## Architecture binding

The bounded route is:

    legacy SWAP files
        ↓
    legacy readers / application processes
        ↓
    process-ready in-memory variables
        ↓
    M1-C3 adapter binding
        ↓
    typed SoilWater request/providers
        ↓
    soil_water_solver_t / Reference Richards service
        ↓
    accepted legacy continuation and output

The legacy reader layer may continue to own file names, parser order and historical application-file semantics. None of those concepts may enter the typed solver request or kernel-facing interfaces.

The adapter may translate only already-admitted semantics:

1. legacy drainage and subsurface-irrigation arrays to the existing source/sink provider;
2. legacy root-extraction array to the separate admitted root-sink provider;
3. SWBOTB=6 to typed bottom mode 2 with exactly qbot=0;
4. the B1.11 KSATEXM extension only for the bounded B1.11 legacy-application profile;
5. current process-ready surface quantities to the admitted dynamic top-boundary provider.

No application-process equation is reimplemented in this adapter.

## Bounded application profile

The new profile is deliberately narrower than the generic Task2 route. It requires the already observed Hupsel/B1.11 execution envelope:

- Full Richards (SWSOLVE=1);
- no macropore flow;
- no frost;
- drainage method 1;
- fixed ponding threshold;
- no runon;
- legacy zero-flux bottom selector SWBOTB=6;
- explicit conductivity (SWKIMPL=0);
- analytical hydraulic functions (SWSOPHY=0);
- at least one active B1.11 KSATEXM declaration cofgen(10,:) > cofgen(3,:).

The profile does not broaden arbitrary legacy files into production. Anything outside this envelope continues to follow its pre-existing route. Unsupported state within the bounded profile must fail closed rather than silently inventing a mapping.

## Lifecycle and ownership

Initialization and daily/application processing remain owned by the existing legacy-file adapter route. Each SoilWater attempt:

1. snapshots the existing legacy SoilWater state through the already-admitted Task2 seam;
2. materializes typed geometry, state, source/sink, root-sink, surface and bottom-boundary inputs;
3. invokes the current typed Reference Richards service;
4. returns either a converged candidate or the existing retry request;
5. exposes only accepted physical outputs back to the legacy continuation;
6. reaches SoilWater(3) only after the existing retry loop accepts the physical step.

The adapter does not own a second retry policy, timestep policy, committed-state store, mass ledger or solver.

## Qualification contract

Admission requires all of the following:

1. verify the exact uploaded distribution hash before any run;
2. reconstruct B1.11 and verify 63 members, 1,886,519 source bytes and the frozen manifest hash;
3. reproduce the exact legacy Hupsel reference run to normal completion;
4. run the whole Hupsel trajectory with the bounded typed Task2 profile and no compatibility fallback for that profile;
5. observe exactly 32,518 accepted physical intervals and account separately for retry attempts;
6. require the historical active-route census: 3,505 SWINTER0/SWCF0, 14,062 SWINTER1/SWCF1 and 14,951 SWINTER3/SWCF2 intervals;
7. retain the already-qualified six exact transactional snapshot identities;
8. compare result.bal and result.blc after removing only the nondeterministic Generated at: line; any remaining difference must be classified, not ignored;
9. prove that the generic non-M1 Task2 route retains its previous default KSATEXM, root-sink and bottom-boundary behavior;
10. run current affected preservation/unit gates and an independent no-file/parser-leak oracle.

A signed-zero-only textual difference is not pre-authorized as PASS. It must either be removed through an already-admitted serialization rule without changing physics or explicitly remain a blocker.

## Non-goals

This workunit does not authorize:

- new SoilWater physics;
- a new legacy parser or new file grammar;
- tolerance retuning;
- solver-policy changes;
- RossFast substitution;
- a second transaction lifecycle;
- Python ownership of SWAP state;
- groundwater topology or iMOD Coupler integration;
- heterogeneous N:1 transferability;
- SCALE or ROM work.

## Relation to F-GC50

Closing M1-C3 proves the legacy-file application can reach the typed production computational boundary. It does **not by itself** create the F-GC49D application-context factory required by F-GC50 blocker B2. Any groundwater bootstrap built afterwards must be a separate bounded capability that consumes the admitted typed/FMR ownership model rather than treating this adapter as a groundwater context factory.
