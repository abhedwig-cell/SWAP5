# GC-RZM06A real-SWAP falsification bridge: qualified H1-H4 result

Date: 2026-09-22  
Preregistration: `562853f7dd1a53c8301b0d4648f474084cfd2734`  
Experiment implementation: `9a5322b27643c43a15c64c39094102112a758ed7`  
CI binding: `199868ff91ebf5faeb0169484f7dadf99585d7f3`  
Qualified workflow: `35725440992`, job `106737853660`  
Production changes: none

## Decision

GC-RZM06A is qualified as a real-SWAP research falsification bridge for H1, H3 and H4. H2 is closed for this preregistered enumeration as `NO_MATCH`; it is neither supported nor falsified because no endpoint pair met the frozen total-water and vertical-distribution criteria.

The result strengthens the central interface interpretation: one physical fixed-plane head H_c can remain the hydraulic interface variable while H_c alone is not a sufficient description of the internal SWAP state needed to predict the next accepted interface response.

It does **not** show that an additional MODFLOW state variable is required.

## H1: same H_c, different accepted state, different next E_c

The response-blind antecedent pair used the same H_c, the same two 0.01 d windows, and the same integrated top forcing:

- origin A: WET → DRY, with native top forcing -1e-5 then +1e-5;
- origin B: DRY → WET, with +1e-5 then -1e-5.

Both origins end at committed time 0.02 d and revision 2. Fresh-process replay is exact.

Their measured profile observables differ only slightly:

| observable | WET→DRY | DRY→WET |
| --- | ---: | ---: |
| profile water, native geometry-based observable | 1.0430631336699183 | 1.043063184727175 |
| root-zone water, native geometry-based observable | 0.1037734552350075 | 0.10377348348932945 |
| distribution moment, native geometry-based observable | -1.5024450029396634 | -1.5024449323768638 |
| internal diagnostic groundwater level | -2.0 | -2.0 |

The identical forcing-free 1e-4 d probe at `H_c = -0.7149999706136307 m` gives:

- `E_A = +6.433698018781797e-11` native whole-window bottom outward exchange;
- `E_B = -9.179923488034092e-11`;
- `|ΔE| = 1.561362150681589e-10`.

The preregistered threshold was `1e-18`. Both probes are whole-window accepted, mass-complete, have zero recorded mass residual, leave the committed origin unchanged, and replay exactly.

**H1 disposition: SUPPORTED.**

The response even changes sign between these two accepted origins. That is strong evidence that H_c alone does not uniquely determine the next real-SWAP whole-window response.

The attribution must remain narrow. H1 does not identify which internal component is sufficient or causal. The water-profile observables differ, and the serialized real-SWAP state may also contain continuation/history information. H2 was intended to isolate vertical distribution more tightly and did not obtain a qualifying pair.

## H2: same total profile water, separated vertical distribution

The preregistered search enumerated all 25 two-interval trajectories from the ordered alphabet W10, D10, W, D, Z at fixed H_c and common endpoint time 0.02 d.

Twenty-three trajectories were accepted. Two failed and remain evidence:

- D10 → W10;
- D10 → Z.

Among the accepted endpoints, 171 pairs satisfy the frozen profile-water criterion `|ΔW_profile| <= 1e-6`. None satisfies the simultaneous frozen distribution criterion `|ΔM1| >= 1e-4`.

The largest M1 separation among water-matched pairs is about `7.0384e-7`, for D→W10 versus Z→D, with `|ΔW_profile| ≈ 9.5532e-7`. The available distribution separation is therefore roughly two orders of magnitude below the preregistered requirement.

No H2 probe response was run, as preregistered.

**H2 disposition: NO_MATCH.**

This is not evidence that vertical distribution does not matter. It says only that this frozen, non-mutating forcing enumeration did not produce the required controlled pair. Thresholds were not relaxed.

## H3: local tangent depends on origin and window

Central differences use `δH = 1e-6 m`. Every plus and minus trial begins in a fresh process that deterministically replays the complete antecedent trajectory. No arbitrary checkpoint clone or hidden candidate reuse is used.

For the 1e-4 d probe:

- WET→DRY: `dE/dH = -0.0034029364881504875` native exchange per metre;
- DRY→WET: `dE/dH = -0.0034029359330389752`;
- state-dependent difference: `5.551115123125783e-10`.

For the 1e-3 d probe:

- WET→DRY: `-0.02788525010899434`;
- DRY→WET: `-0.027885247666503687`;
- state-dependent difference: `2.4424906541753444e-9`.

Both differences exceed the preregistered `1e-12` tangent threshold and replay exactly. The state effect is real under the frozen criterion but very small: about `1.63e-7` and `8.76e-8` relative to the tangent magnitude for the short and long windows respectively. This should not be overstated.

Window dependence is much larger. Converting the integrated-exchange derivative through the existing interface conversion gives approximately:

- short window: `-3.9385839e-6 s^-1` and `-3.9385833e-6 s^-1`;
- long window: `-3.2274595e-6 s^-1` and `-3.2274592e-6 s^-1`.

Thus the window effect is not merely the trivial scaling of an integrated amount with duration.

**H3 disposition: SUPPORTED_STATE_AND_WINDOW_DEPENDENCE.**

## H4: exchange, terminal flux, physical tangent and predictor coefficient remain distinct

For the WET→DRY H1 origin, the 1e-4 d probe records separately:

- whole-window bottom outward exchange: `6.433698018781797e-11`;
- terminal bottom outward flux: `6.433698018781836e-7`;
- interface rate derived from the whole-window amount: `7.446409743960413e-14 m/s`;
- physical local integrated-response derivative: `-0.0034029364881504875` per metre.

The baseline F-GC44 predictor, captured before antecedent state construction, separately reports:

- `u = 3.402936037279093e-5`;
- predictor qbot = `1e-6` in its historical native rate field;
- `hcof = 0.3402936037279093`;
- `rhs = -0.24330990700660954`.

The whole-window exchange reproduces the reported q_swap conversion exactly. The predictor quantities retain baseline-origin provenance and are not relabelled as physical tangents at the two antecedent origins.

At the short window the physical outward-rate derivative is again approximately `-3.93858e-6 s^-1`, while the historical production-facing `+u/dt` has approximately the same magnitude and opposite sign. This is consistent with the earlier F-GC44 sign audit. It remains insufficient by itself for a global production sign-flip claim.

**H4 disposition: SUPPORTED_SEMANTIC_SEPARATION.**

## What RZM06A now establishes

The real serialized-reference carrier falsifies the idea that the fixed-plane interface head can also serve as a complete state descriptor. Two accepted SWAP states at the same H_c, same committed time and same integrated antecedent top forcing produce materially different next accepted bottom exchange.

This does not falsify the one-head physical interface contract. The evidence remains compatible with

`H_c^SWAP = H_c^MODFLOW = H_c`

and, using positive SWAP-to-MODFLOW orientation,

`q_c,SWAP,out + q_c,MODFLOW,out = 0`.

Internal SWAP memory therefore belongs inside the SWAP-side response construction unless later evidence shows that an additional physical cross-model state is actually required.

## Limitations and next question

The main unresolved RZM06A question is H2 attribution. The present forcing-only, no-direct-state-mutation enumeration did not create two states with nearly equal total profile water and the required M1 separation. A follow-up should therefore target *state-pair construction*, not tune the H2 threshold or inspect E_c while searching.

That follow-up can use longer redistribution histories, pulse-and-relax trajectories, or a broader but still prospectively frozen forcing alphabet, while preserving identical endpoint time, H_c, mass gates and response-blind pair selection.

RZM06B/H5 remains separate until a qualified management-forcing route exists.
