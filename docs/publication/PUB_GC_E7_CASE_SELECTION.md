# PUB-GC E7 realistic-case selection and readiness

## Status

**CASE_SELECTED — BLOCKED_EXTERNAL_PREREQUISITE**

Date: 2026-09-18.

Canonical basis for this readiness reconciliation:

`integration/f-ci-canonical@ee3a93ce3f89d3503e4e4e2cd1f24b24ec6b6b93`

## Selected application

Hupselbrook remains the preferred E7 case.

This is not a post-hoc choice based on coupling output. No E7 coupling output has been calculated. Hupsel is selected because the repository already contains independent historical application authority:

- exact SWAP 4.3.1 distribution identity and required hashes are known;
- the official Hupsel case and fixture-member identities are recorded;
- the legacy three-year run and normalized BAL/BLC reference have been rebuilt;
- daily and timestep application traces exist;
- all active Hupsel application routes are now canonically admitted;
- drainage whole-trajectory evidence is exact;
- lower-boundary behaviour is qualified;
- six-snapshot transactional replay is exact after F-SI39.

The latest M1-C3 checkpoint records `32518` accepted historical intervals and identifies only one remaining gate.

## Remaining prerequisite

The required final gate is:

> one final whole-Hupsel file-driven adapter execution against the exact authorized SWAP 4.3.1 distribution.

Frozen distribution authority:

```text
distribution SHA-256:
2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360

nested source SHA-256:
1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151

distribution size:
8,959,314 bytes
```

The file catalog currently contains multiple SWAP 4.3.1 zip copies with the required size, including the previously identified `SWAP_4.3.1(5).zip`. A fresh materialization attempt in the current publication session still returns:

```text
This Project file does not have an authorized raw-byte materialization path.
```

Because the bytes cannot be read, their SHA-256 cannot be reverified in the execution environment and the frozen final M1-C3 qualification cannot honestly be run.

## Why this blocks E7

E7 requires a realistic typed production participant, not merely historical reference output.

Until M1-C3 closes, the manuscript may not claim that the complete Hupsel application is available as one production SWAP5 participant whose lower boundary can simply be replaced by the PUB-GC groundwater coupling contract.

No substitute synthetic case is authorized as “realistic”.

## Prospective E7 period selection

After M1-C3 closure, select the publication periods using standalone Hupsel dynamics only, before coupled results are inspected.

The existing selection principle remains:

1. exclude documented spin-up;
2. partition the authoritative standalone trace into fixed-duration windows;
3. characterize windows from standalone quantities such as storage change, lower-boundary exchange, rainfall/irrigation pulse and groundwater/head excursion;
4. freeze one median-dynamics control window and one high-dynamics window using a preregistered scalar metric;
5. only then construct and run the coupled MODFLOW case.

This prevents selection on a favourable loose-versus-strong coupling difference.

## Relation to E6

E6 is now closed negatively. Two preregistered synthetic stress routes reached component-admission boundaries before a positive strong-feedback live case was available.

That increases the scientific importance of E7 but does not lower its admission standard. The realistic case must use an application whose process and boundary semantics are already authoritative rather than expanding production physics for the paper.

## Next permitted action

When the exact distribution bytes become materializable:

1. verify the frozen distribution SHA-256;
2. execute only the already-defined final whole-Hupsel M1-C3 adapter qualification;
3. admit M1-C3 if and only if that gate passes;
4. then create the E7 period-selection preregistration from the admitted standalone Hupsel trace.

Until then, E7 is externally blocked. No coupling-result selection or synthetic fallback is justified.


## M1-C3 prerequisite closure — 2026-09-18

The previously recorded E7 blocker is closed.

Controlling canonical authority:

- M1-C3 admission PR: **#313**;
- M1-C3 merge commit: `d91c159c3685d8eedc7c94afc38edf827408c1de`;
- exact SWAP 4.3.1 distribution SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`;
- whole-Hupsel typed-adapter accepted intervals: **32,518**;
- normalized `result.bal` identity: PASS;
- normalized `result.blc` identity: PASS;
- moving-preservation run `35370311611`: SUCCESS;
- formal M1 closeout PR: **#316**;
- overall verdict: `M1_CLOSED_CURRENT_CANONICAL`.

The same exact distribution is also available to the present E7 execution context from the existing Library file `/SWAP_4.3.1.zip`; raw-byte verification reproduced the frozen outer and nested-source hashes.

E7 may now proceed under the already frozen standalone-only episode-selection and coupling rules. No new case-selection freedom is created by this closure.
