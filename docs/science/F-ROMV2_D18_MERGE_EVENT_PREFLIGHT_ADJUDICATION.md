# F-ROMV2 D18 merge-event preflight adjudication

**Decision:** **D18_FMC_SLUG_GW_MERGE_EVENT_PREFLIGHT_NO_GO**

D18 was intentionally staged so the falling-slug/groundwater-front contact event had to occur in an FMC-only preflight before any new R16/R2 trajectory could be generated.

The transition was frozen from the admitted D17 `C75_G25` state after 16 pulse steps. The subsequent top flux was set exactly to (K(\theta_i)), so the entire surface supply satisfied the already frozen gray-bin throughflow demand and no water remained to maintain the connected surface fronts. Those fronts therefore detached into the admitted D16-style falling-slug representation.

The primary source states that falling slugs advance by Eq. 19 with invariant length and, when they encounter a groundwater front, are merged into that front so that the groundwater front rises by the merged slug length. D18 preregistered exactly that new transition while retaining D13 groundwater-front dynamics and the existing finite-volume ledger.

## Immutable execution

- run: **35458926533**
- job: **105939131681**
- head: `1b3c4157bbae4b33d7b37b9ea82134fc6ca50144`
- artifact: **10589491335**
- artifact digest: `sha256:2094394dbd0a4c2a262dba12757968b5fbd5770cb4a70fce752deac4b6261ffd`
- preflight-result SHA-256: `1a735dd21040de81cbf0b887848c9453a5679fdd4f8b4bf10dd3d944cdf721bb`

No SWAP trajectory evidence was consumed.

## Result

The D17 C75_G25 state was reproduced with:

- storage: **51.4205987 cm**;
- minimum surface-groundwater separation: **14.0186902 cm**.

The frozen transition was then executed for all **512 x 10 s** steps.

No merge occurred.

The minimum pre-merge gap reached only **13.1593074 cm**.

Maximum absolute finite-volume ledger residual over the search was approximately **1.04e-14 cm**, well below the **1e-12 cm** hard gate.

Thus D18 is not an integrity failure. It is an event-reachability no-go.

## What D18 does not establish

D18 does **not** show that the published falling-slug/groundwater-front merge rule is wrong or hydrologically inaccurate.

The merge rule was never exercised.

D18 also does not invalidate D16 falling-slug translation, D13 groundwater-front dynamics or D17 simultaneous separated-front candidacy.

It establishes only that the specific natural successor path

`D17 C75_G25 -> q_top=K(theta_i) -> 512 transition steps`

does not reach the contact event.

## Governance consequence

The preregistration prohibits extending the horizon or retuning C75, G25, the transition top flux, bin count, process step or equations after observing the result.

Therefore D18 closes before Stage 2 and no matched R16/R2 comparator is authorized inside D18.

If contact/merge remains scientifically useful, the next workunit must define a genuinely distinct event construction before exposure. It should preferably avoid adding an unqualified generalized falling-slug relaxation operator and should keep the merge semantics bound to the primary FMC source.

Application acceptance remains unqualified.

Formal performance remains unqualified.

Production ROM remains unauthorized.
