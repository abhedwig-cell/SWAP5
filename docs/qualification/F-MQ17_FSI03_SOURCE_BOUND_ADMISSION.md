# F-MQ17 — F-SI03 source-bound adapter admission

F-MQ17 is qualification-only and does not modify production source.

## Exact basis

- F-MQ16 parent: `94010b5ee7f52637fd6507156a01724ebf5a7525`
- F-SI03 qualification head: `c14ad3e032dd0285825051d8cf0e7d11ade01cd6`
- F-SI03 tested postimage: `79e3e9052a4f68306b8c826b063497247fd339d6`
- F-SI03 qualification blob: `c51e97a347127acaaf7d5e9db86f15a6200d500d`
- F-SI03 qualification run: `34121073167` (`success`)
- F-VQ09 observed head: `7af5b30ec1707ac064a93f3af84bff403a203a6d`

## Admission

F-MQ17 admits the F-SI03 **source-bound adapter contract only**. This proves that the common soil-water solver contract has an explicit adapter path to the existing B1.10 `HeadCalc` symbol and that the qualified test-double harness covers:

- request/base-state translation;
- candidate-state translation;
- top and bottom flux translation;
- restoration of the explicitly covered legacy fields;
- retry advice without transaction authority;
- deterministic repeated request and ABA ordering;
- workspace poison independence;
- fail-closed rejection of unsupported physics/policy routes;
- F-SI02 common-contract/workspace regression.

## What this does not admit

F-SI03 explicitly did not execute the real `HeadCalc` numerics in its qualification harness. Consequently F-MQ17 does **not** promote:

- real B1.10 physics;
- real `HeadCalc` numerical identity;
- full reference-Richards reentrancy;
- full legacy-side-effect rollback;
- parallel reference-solver execution;
- finite unrounded physical mass identity;
- interface tangents;
- production reference admission;
- production MultiSWAP runtime admission.

F-VQ09 is likewise used only as a harness/asset-contract guard; its real B1.10 temporal characterization and canonical reference admission remain fail-closed.

## MQ effect

The existing 35-row matrix remains `27 synthetic / 0 real physics / 0 production runtime`.

F-MQ17 records stronger source-bound adapter prerequisites for P05, P08 and P19, but does not change their matrix coverage class. P03, P16 and P18 remain blocked on the missing real/reentrant/physical evidence.
