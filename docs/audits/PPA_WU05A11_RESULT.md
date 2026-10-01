# PPA-WU05-A11 result — perched-zone carrier authority reconciliation

Date: 2026-10-01

Status: `BLOCKED_EXACT_4_3_1_CARRIER_PROVENANCE_ACCESS`

Baseline: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

Preregistration commit: `0a36b968b536bf6bae17eaa050eb6f0a3adf9705`

## Reconciliation result

PPA-WU05-A10 is canonically admitted and closed. Its exact technical admission merge is
`190dad36a821f3a43f78f00fccf827c58cacedb6`; post-merge preservation run
`36829313469` completed successfully. Documentation closeout PR #929 merged as
canonical `ebea588070f7a44dbaea78169f2548c745061c48`.

The next bounded capability remains perched/top saturated matrix-zone macropore exchange.

## Existing exact repository authority

Historical A6 authority retained on PR #922 head
`b5b123dcc4450dcc3c76a789ba749205fa8474b5` establishes from the exact B1.11
macrorate oracle that:

- unsaturated absorption ends at `min(ICpBtDm, ICpTpSatZon-1)`;
- the perched partly saturated matrix interval is excluded from unsaturated absorption;
- MACRORATE uses a separate SATFLOW request for perched/top saturated matrix inflow
  `QInIntSatDmCp`;
- the ordinary saturated groundwater zone uses the separate `QInMtxSatDmCp` request;
- both receipts are internal matrix-to-macropore transfers.

Current canonical code retains those source-bound process semantics in:

- `mod_ppa_wu05a6_sorptivity_rate`;
- `mod_ppa_wu05a6_unsat_absorption_rate`;
- `mod_ppa_wu05a6_saturated_exchange_rate`;
- `mod_ppa_wu05a6_saturated_sources`;
- `mod_ppa_wu05a6_rate_bundle`.

The current FMR adapter deliberately suppresses the missing carrier.

## Carrier reconstruction obtained in this workunit

A public historical SWAP source mirror was used only as corroborating locator evidence, not
as the B1.11 oracle. Its refactored `macrorate.f90` is about 39.7 kB of ASCII text, while
A1 pins the exact B1.11 file at 111,863 bytes and SHA-256
`537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7`.
It therefore cannot establish exact 4.3.1 byte provenance.

The corroborating source nevertheless exposes the full legacy carrier shape:

- `NPeGwl`: deepest unsaturated node associated with perched groundwater search;
- `BPeGwl`: bottom node of the perched saturated/percolation zone;
- `PeGWL`: perched groundwater level;
- `ICpTpPerZon = NPeGwl + 1` when perched groundwater exists;
- `ICpBtPerZon = BPeGwl`;
- `ICpSatPeGWl`: compartment containing the perched water level when the level cuts a compartment;
- no perched groundwater: `ICpBtPerZon=-1` and `ICpTpPerZon=ICpTpSatZon`.

The same source locates the groundwater/perched-groundwater search in the soil-water
water-table logic. The search accumulates under-saturated volume

`sum((ThetaS-Theta)*dz)`

until either the critical under-saturated-volume threshold is reached or saturated matrix
is encountered. Historical/manual semantics identify the default critical amount as
approximately `0.1 cm`.

This is sufficient to identify the expected FMR data dependency:
current matrix `water_content`, immutable `theta_s`, current pressure head, `z/dz`,
and the same water-level interpolation/search policy as the reference route.

## Why G1 is still not closed

A1 previously recovered a byte-exact `SWAP_4.3.1.zip` of 8,959,314 bytes with
SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`.

This execution located multiple retained Library copies with the same filename and byte
size, including the prior A1 recovery copy. The file service permits metadata access and
even a server-side Library copy, but raw-byte materialization is denied in the current
Project context with:

`This Project file does not have an authorized raw-byte materialization path.`

Therefore the reconstructed water-table/perched carrier cannot yet be promoted from
strong corroboration to exact B1.11/4.3.1 source authority.

## Falsified shortcut

The production rule

`perched = contiguous nodes with pressure_head >= 0`

is explicitly rejected.

The legacy/source-corroborated construction includes a cumulative under-saturated-volume
criterion and water-level interpolation. A sign-only detector can therefore split or merge
zones differently near nearly saturated compartments and would silently change the
physical carrier.

## Implementation consequence

No production code is changed by A11 at this stage.

When exact G1 authority becomes readable, the expected bounded implementation is:

1. derive a non-persistent perched matrix hydraulic view from current matrix state;
2. populate `perched_active/top/bottom` in the existing A6 unsaturated request;
3. populate the existing `interflow_sat` SATFLOW request with perched top, bottom,
   saturated-level compartment and perched reference level;
4. verify whether sorptivity-history update must apply the same perched exclusion before
   changing any history logic;
5. keep the seven-field macropore continuation state unchanged;
6. prove active perched exchange mass cancellation, reject/discard/replay, restart and
   exact A8/A9/A10 preservation.

## Decision

`REAL_BLOCKER_EXACT_4_3_1_PERCHED_CARRIER_BYTES_NOT_AUTHORIZED_FOR_READ`

This is now an access/provenance blocker, not an unresolved physical-concept blocker.

No mass tolerance, physical formula, persistence schema, or accepted A8/A9/A10 behavior
has been changed. No GitHub Actions run is justified while G1 remains open.

The frozen Status-A denominator remains unchanged.
