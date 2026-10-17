# MC-NUT01 source-initialized two-day crop and Soil-N continuation (2026-10-17)

Baseline canonical aa73ca4350eaa715b2ae42655f1073caeffd18cb. PR #1290. Exact tested code HEAD 5f5f4c4ece6631cbdd98d8fb56f7782bdcd7dccb.

The existing real B1.12 Full Richards crop/Soil-N joint driver now has an explicitly selected source-profile path. Both the uninterrupted and fresh-process routes reconstruct the same admitted bounded unified project export, obtain its source-derived reactive chemistry and crop policy/configuration identity, and run actual daily hydrological and chemical owner updates. The write route executes day one and day two; the fresh resume route decodes the saved day-one native joint restart into initially blank water and crop/soil owners and executes day two. The runner checks exact endpoint byte equality at O0 and O2 and continues to execute the incumbent default/B1.11/B1.12 preservation matrix.

Qualification: https://github.com/abhedwig-cell/SWAP5/actions/runs/39050048051, terminal SUCCESS, exact candidate above. Its test runner hard-fails on absent source-native PASS or differing source restart endpoint bytes. The earlier run 39049536205 failed because the test wrongly passed preinitialized destination owners to a fail-closed decoder; the repair clears only native decoder destinations, not mass checks or physics.

Boundary: source profile is the admitted explicitly transformed management/Soil-N export. Native original TTUTIL .snm parsing, wider input envelope, whole historical annual crop rotation and nine broad MC-NUT01 capability closures remain open. This PR adds a new qualification scenario and retains production owner semantics. No full mastercoverage promotion; unrelated full F-CI and low-air not selected by test-only dependency delta.
