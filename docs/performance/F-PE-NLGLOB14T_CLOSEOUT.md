# F-PE-NLGLOB14T closeout — transactional split-domain shadow interval

Date: 2026-09-29

Final status:

`QUALIFIED_TRANSACTIONAL_SPLIT_DOMAIN_SHADOW_INTERVAL`

Qualification authority:

- run `36602968350`;
- job `109524717907`;
- conclusion: SUCCESS.

## Closure

NLGLOB14T closes positively.

All 12 preregistered first-retreat fixtures support one finite coupled split-domain shadow interval with:

- TG temporal ownership on nodes 1:3;
- saturated/full-Richards temporal ownership on nodes 4:16;
- one shared 3/4 interface exchange authority;
- conservative recombination;
- exact control-state rollback.

The coupled endpoint solve requires only 2-3 nonlinear iterations per fixture.

Maximum observed residual is about `1.47e-11`, maximum absolute physical mass ledger about `1.47e-10 cm`, and all recorded rollback differences are zero.

## Mechanistic conclusion

The finite-interval problem does not require two independently fitted interface fluxes or an artificial interface head.

A single physical interface exchange can close both temporal subdomains.

The lower saturated block remains saturated over this first interval, so its water-content storage stays constant, but its pressure heads change measurably in every fixture. The lower block is therefore dynamically evolving rather than frozen.

No upper-domain saturation crossing occurs.

## Control comparison

The split endpoint remains close to the persistent-KLAG next accepted endpoint, with head and theta differences shrinking strongly as dt is refined.

This supports local trajectory consistency while preserving the distinction between the two temporal discretizations.

It does not make persistent KLAG the split solver and does not qualify multi-interval accepted split evolution by itself.

## Direct successor

Open a separately preregistered accepted-state moving-interface research workunit.

The successor must:

1. start from the same qualified first-retreat accepted state;
2. accept only qualified split endpoints into a private research accepted state;
3. recompute temporal ownership from the accepted physical saturated set after each accepted interval;
4. keep one shared interface exchange;
5. require monotone retreat under the unchanged dry forcing or classify reverse movement as chatter;
6. record every ownership-face transition;
7. compare matched endpoints with the persistent-KLAG control;
8. preserve transaction rollback on every rejected candidate;
9. remain research-only.

Whole-column TG may become eligible only after the accepted physical state contains no remaining saturated lower block.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14T

BASELINE: `61748c7af9a1aa5bd7faa4bda6a64be756887ab2`

BRANCH: `research/f-pe-nlglob14t-transactional-split-shadow`

QUALIFICATION POSTIMAGE: result/closeout branch after run `36602968350`

STATUS: closed positive research qualification

TEST STATUS: 12/12 coupled split shadow PASS

QUALIFICATION STATUS: `QUALIFIED_TRANSACTIONAL_SPLIT_DOMAIN_SHADOW_INTERVAL`

NEXT SAFE STEP: preregister multi-interval research accepted-state moving-interface evolution.

## Production boundary

No production `src/**` change.

No production numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
