# F-MQ21 — F-SI06 history isolation and F-VQ12 ownership non-conflict admission

## Purpose

F-MQ21 admits two newly qualified downstream boundaries into the MultiSWAP qualification model without changing production source:

1. F-SI06 removes hidden `SAVE` ownership from `HeadCalc`, makes warning/reporting history explicit, keeps admitted common-reference history call-local, and preserves focused serial real-HeadCalc identity.
2. F-VQ12 qualifies source-bound contractual non-conflict between the F-KT05 reusable checkpoint carrier and the F-SI05 production workspace seam.

## Exact evidence

- F-MQ20 parent: `06b45a139f649dbd92437d922fadfea9a00d660a`
- F-SI06 qualification head: `d0f0cc0817f2e2b8ca55dd90752cfda2f7b0e6e8`
- F-SI06 tested checkpoint: `dfed799dbc0930bdf5218e713934ea0f148e3872`
- F-SI06 final postimage: `2fa63c41a4d7248ab7f4b5af46f72caddfda4f29`
- F-VQ12 qualification head: `7cd06ba606429c891dab7f355a85b58ca56a3bca`
- oracle: B1.10

## Admitted claims

F-MQ21 admits the following as production/source-bound prerequisites:

- no hidden saved worker/history singleton in HeadCalc;
- explicit warning/reporting history ownership;
- call-local history on the admitted common reference route;
- focused serial A/B/A real-HeadCalc identity;
- unchanged common workspace 1/2/4/8-thread isolation regression;
- F-KT05 checkpoint ownership and F-SI05 workspace ownership are contractually non-conflicting.

## Fail-closed boundary

F-SI06 deliberately does **not** qualify full real-HeadCalc parallel reentrancy. The current legacy adapter still translates request/candidate state through shared mutable module globals. F-MQ21 therefore treats `BLOCKED_SHARED_LEGACY_GLOBAL_TRANSLATION` as a required qualification outcome, not as an ignored limitation.

Likewise F-VQ12 does not qualify one composed F-KT05 + F-SI05 executable production runtime, production B1.10 reference execution, complete full-SWAP unrounded mass accounting, or production MultiSWAP.

## Matrix effect

No 35-row matrix promotion is made. F-SI06's serial focused A/B/A evidence is below the P02/P03/P18 multi-column/worker minima, and the parallel real-HeadCalc route is explicitly blocked. Coverage therefore remains:

- synthetic executable: 27/35;
- complete real physics: 0/35;
- production runtime: 0/35.

## Architecture invariants

This admission directly reinforces invariants 3–8, 13, 16, 21–23, 25–27, 29 and 30. In particular, reporting-only history is kept outside committed physical state, solver scratch remains worker/job-owned, and F-KT transaction authority remains separate from F-SI solver ownership.
