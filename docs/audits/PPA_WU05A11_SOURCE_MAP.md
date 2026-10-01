# PPA-WU05-A11 source map — exact 4.3.1 perched groundwater carrier

Date: 2026-10-01

Status: `EXACT_SOURCE_MAP / IMPLEMENTED_PENDING_QUALIFICATION`

Baseline: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

Implementation checkpoint: `2ad9cbda64a53707730990dd436588a47b86b5b2`

## Exact source recovery

The user supplied `SWAP_4.3.1.zip` directly in this workunit.

The outer distribution differs from the earlier A1 retained-copy hash:

- uploaded bytes: 8,958,994;
- uploaded outer SHA-256: `76a79498423ee612a7861efb564b10c4360a4f648396eefcf8e9011919a66039`.

That outer packaging difference does **not** affect the source oracle used here.

The nested source archive is byte-exact with A1 authority:

- path: `SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP`;
- bytes: 411,215;
- SHA-256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

This exactly equals the A1-pinned official source-archive identity.

Relevant members:

- `SWAP/macropore.f90`: 88,138 bytes, SHA-256
  `1cb5a2ce30610c05a4da5655bff217d6f52052d57d99efe8af7928f1d2187d0b`;
- `SWAP/macrorate.f90`: 111,863 bytes, SHA-256
  `537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7`;
- `SWAP/calcgwl.f90`: 13,602 bytes, SHA-256
  `d7649f02bf6cd629cc7eceb1c761a6c38d6f0adf0d0c072c7aaab3af4562f5eb`.

A1 already established that `macrorate.f90` is unchanged in B1.11 and that SWAP-001
only changes the unrelated non-conformable assignment in `macropore.f90`. The perched
carrier logic used by A11 is therefore exact source authority.

## CALCGWL perched-zone construction

After the ordinary groundwater table has been identified, CALCGWL searches upward from
the main groundwater zone for the first compartment with nonnegative pressure head.

If none exists, there is no perched groundwater.

If one exists, the bottom elevation of the perched saturated region is reconstructed from
the zero-head crossing beneath that saturated compartment. The containing bottom node is
stored as `BPeGwl`.

From that bottom, CALCGWL searches upward. When negative pressure head is encountered,
the helper `watertable` accumulates:

`TotUndSatVol += max(0, ThetaS - Theta) * dz`.

The unsaturated interval is treated as a real separator when:

- the top of the profile is reached; or
- `TotUndSatVol > CritUndSatVol - 1e-8`.

If a saturated compartment is encountered before the critical under-saturated volume is
exceeded, the search continues upward and the thin under-saturated interval remains part
of the same perched saturated system.

The perched water level is calculated with the same zero-pressure-head interpolation used
for the ordinary water table.

## MACROSTATE carrier mapping

Exact `macropore.f90` then maps CALCGWL state into MACRORATE indices.

When `NPeGwl > 0`:

- `ICpBtPerZon = BPeGwl`;
- `ICpTpPerZon = NPeGwl + 1`;
- if `PeGwl < Z(NPeGwl)-0.5*DZ(NPeGwl)`,
  `ICpSatPeGwl = ICpTpPerZon`;
- otherwise `ICpSatPeGwl = -1`;
- special surface case: if `NPeGwl == 1` and `PeGwl > Z(1)`,
  `ICpTpPerZon = 1`.

When no perched groundwater exists:

- `ICpBtPerZon = -1`;
- `ICpTpPerZon = ICpTpSatZon`.

## MACRORATE use

Exact B1.11 MACRORATE uses the carrier in two separate places.

### Unsaturated absorption

The lower active absorption limit is:

`min(ICpBtDm, ICpTpSatZon-1)`.

Within that range, compartments are evaluated only when they lie outside:

`[ICpTpPerZon, ICpBtPerZon]`.

Thus the perched saturated/percolation interval is excluded from unsaturated sorptivity/Darcy absorption.

### Saturated interflow into macropores

The perched zone is passed to SATFLOW as:

- top: `ICpTpPerZon`;
- bottom: `ICpBtPerZon`;
- partial saturated-level compartment: `ICpSatPeGwl`;
- matrix reference level: `PeGwl`.

This produces `QInIntSatDmCp`.

The ordinary saturated groundwater zone is passed separately and produces
`QInMtxSatDmCp`.

Both are internal matrix-to-macropore transfers.

## Typed A11 representation

A11 preserves that decomposition with no new persistent state.

New immutable/request configuration:

- explicit `perched_detection_enabled`;
- `critical_under_saturated_volume_cm`.

New derived runtime view:

- active flag;
- top compartment;
- bottom compartment;
- partial-top flag;
- perched water level;
- perched-zone bottom level.

The view is recomputed from current trial matrix state and immutable configuration.

The existing A6 contracts are reused:

- `sorptivity_rate_request_t%perched_*`;
- `interflow_sat` SATFLOW request;
- `QInIntSat` internal-exchange ownership.

The saturated-exchange request gains one explicit boolean to distinguish a partially
saturated top compartment from a fully saturated top compartment. Its default is true so
the pre-A11 main-groundwater behavior is preserved.

## Source-oracle qualification fixture

The A11 fixture contains a 0.01 cm under-saturated-volume gap.

With:

- `CritUndSatVol = 0.005 cm`, the gap separates the perched bodies and the active
  perched zone is compartment 4 only;
- `CritUndSatVol = 0.02 cm`, the gap is bridged and the active perched zone spans
  compartments 3 through 4.

The expected water levels are generated directly from the exact CALCGWL interpolation
relations and are asserted numerically in the focused test.

## Preservation boundary

Perched detection is opt-in.

All A8/A9/A10 configurations that do not explicitly enable A11 retain their previous
neutral perched template and therefore their admitted behavior.

No continuation-state field, restart schema, mass tolerance, solver policy or rapid-drain
formula is changed.
