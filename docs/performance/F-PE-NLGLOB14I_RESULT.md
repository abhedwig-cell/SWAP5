# F-PE-NLGLOB14I result — dry-phase saturated-set migration attribution

Date: 2026-09-29

Status:

`NLGLOB14I_MIXED_SATURATED_SET_MIGRATION`

Canonical base at preregistration:

`integration/f-ci-canonical@c963cacfc86e3f0df5f318ac6a6ffce23bf92225`

Canonical authority rechecked before result persistence:

`integration/f-ci-canonical@19478ed94d3161fcd2b95a91bab6100a228d6c75`

The intervening canonical delta admits the completed NLGLOB14H and related research documentation. It does not change the frozen NLGLOB14I fixtures, state diagnostics, saturation indicators, temporal policy or physical mass contract.

Qualification authority:

- workflow run: `36566195803`;
- job: `109398591216`;
- conclusion: SUCCESS.

## Coverage

PASS.

All 8 frozen O05/TG forcing-reversal fixtures:

- enter persistent saturated mode exactly once;
- execute the full 0.012 d horizon;
- remain finite;
- preserve physical mass;
- retain consistent head- and moisture-based saturation indicators.

Process failures:

`0`.

## Observed saturated-set structure

In all 8 fixtures:

- the saturated nodes always form one contiguous lower block ending at node 16;
- the initial saturated-node count is exactly 1;
- the final saturated-node count is exactly 14;
- the top node is unsaturated at the final state;
- no noncontiguous saturated pattern occurs;
- no saturation-indicator inconsistency occurs;
- profile storage decreases over the dry phase.

Thus the saturated set does not retreat under the frozen drying fixture.

It expands upward from the lower boundary while the profile as a whole loses water.

The same qualitative pattern occurs for:

- HEAD and RUNOFF entry routes;
- all four dt levels.

## Frozen classification

The preregistered retreat class requires a decrease in saturated-node count.

Observed count decreases:

`0 / 8`.

The persistent-block class requires unchanged saturated-node count.

Observed unchanged-count fixtures:

`0 / 8`.

Therefore the frozen aggregate classification is:

`NLGLOB14I_MIXED_SATURATED_SET_MIGRATION`.

The word "mixed" reflects the preregistered classifier. The observed pattern itself is highly consistent: contiguous lower-block expansion under net profile drying.

## Scientific interpretation

The release problem is not a simple retreat of a pre-existing saturated region.

Under the current persistent saturated-mode formulation and forcing-reversal fixture:

1. the surface dries and returns to flux control;
2. total profile storage decreases;
3. the lower profile becomes progressively more saturated;
4. the saturated lower block expands upward;
5. the original bottom event node remains within that saturated block.

This means the absence of release is not explained by tracking the wrong node alone.

The next bounded question is the internal water redistribution that feeds the expanding lower saturated block while net water is removed from the profile.

A release criterion must not be designed until that redistribution is understood.

## Consequence

Open a separately preregistered successor:

`F-PE-NLGLOB14J — dry-phase lower-block expansion mass-redistribution attribution`.

The successor should remain observational and quantify, for the same eight fixtures:

- storage change above the moving saturated-block edge;
- storage change within the saturated lower block;
- vertical flux crossing the moving block edge;
- top evaporative removal;
- bottom flux;
- whether lower-block storage gain is supplied by downward redistribution from drying upper nodes;
- whether the moving block edge is consistent with local mass conservation.

No release switch or threshold is authorized by NLGLOB14I.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
