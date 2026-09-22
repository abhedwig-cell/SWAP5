# GC root-zone-memory authority reconciliation

Date: 2026-09-22  
Branch: `work/gc-dummy-swap-rootzone-memory`  
Status: RESEARCH-ONLY AUTHORITY RECONCILIATION  
Production changes: none

## Bound authorities

This workstream starts from the fixed-interface research branch snapshot
`work/f-gc-dummy-swap-shared-storage@dbf877e9815a57f1d5047d008dcc69b92d65dfa2`.

The common canonical denominator observed by the two parent research programmes is
`integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`.

The root-zone management evidence is read from
`work/ribasim-dummy-01@89415abb40bc4305154c32782b2e86a54ba13474`.
Only qualified bounded conclusions are imported. No Ribasim production behaviour
is inferred.

Relevant fixed-interface authorities:

- `docs/research/GC_FIXED_INTERFACE_COUPLING_THEORY.md`
- `integration/research/GC_DUMMY_SWAP_TESTBANK_STATUS.json`
- DSW11: same interface/shared head can coexist with different internal memory
- DSW15: forcing order becomes observable when internal memory is present
- DSW17: internal transfers cancel exactly from the complete ledger
- DSW19: deterministic convergence does not establish physical correctness
- DSW20: accepted multi-window continuation needs explicit physical state and ledger
- NH01-NH05 synthesis: `H_c` is the hydraulic head on the fixed geometric plane;
  internal SWAP states may affect the next finite-window response without becoming
  additional MODFLOW state variables
- `docs/research/GC_FIXED_INTERFACE_MINIMUM_COUPLING_INFORMATION.md`: a trial
  affine response needs an origin, value/intercept, tangent, window identity,
  sign/unit contract, committed-state provenance and validity; the accepted
  interface ledger is a distinct product.

Relevant Ribasim-dummy authorities:

- RIBASIM-DUMMY-12 qualification head
  `06f72519ecc037ce2517986e0a74296d9c63b7b8`: physical root-zone storage is the
  persistent demand-memory state; management shortage is diagnostic, not a
  persistent physical debt.
- RIBASIM-DUMMY-13 qualification head
  `31dd1b061a5c0d2e6f09c3f1ff77a4f274013588`: declared internal transfers are
  booked once in each component and cancel from the combined ledger.
- RIBASIM-DUMMY-14 qualification head
  `bd1e259330525f741aca750c18e9e7c63382fd4f`: future demand follows accepted
  root storage after forcing; equal current shortage can lead to different next
  demand.
- RIBASIM-DUMMY-15 qualification head
  `f2473fd31edcc226adc52451e385d4e13a11d247`: management priority may alter
  recipient state and future demand while a separately defined physical endpoint
  remains unchanged in the bounded one-Basin oracle.

## Reconciled state taxonomy

The new analytical ladder uses six distinct categories and does not merge them.

1. **Physical state**: water-bearing state owned by the analytical SWAP surrogate,
   initially root storage `W_r` and lower-SWAP storage/head `h_l`.
2. **Interface state**: the single hydraulic head `H_c` at the fixed geometric
   SWAP-MODFLOW plane.
3. **Condensed response**: a finite-window mapping from trial `H_c`, immutable
   committed SWAP origin state, forcing and window duration to integrated
   interface exchange `E_c`.
4. **Coupler-visible state/information**: `H_c` plus only the response
   information needed to solve the current coupling window. Internal states do
   not become coupler states merely because they affect the response.
5. **Diagnostic state**: residuals, shortages, iteration counts and other
   observations with no independent physical persistence.
6. **Management state**: decisions/requests derived at declared decision times.
   In the later management phase, irrigation request is derived from committed
   root storage rather than carried as hydrological debt.

## Preserved interface contract

The coupling plane remains fixed at elevation `z_c`.

At that plane:

```text
H_c^SWAP = H_c^MODFLOW = H_c
```

and, with positive exchange downward from SWAP to MODFLOW,

```text
q_c,SWAP,out + q_c,MODFLOW,out = 0.
```

The new lower-SWAP state is an **interior SWAP state above the coupling plane**.
Any conductance between that state and `H_c` belongs to the SWAP surrogate.
It is not a resistance between two competing interface heads.

The root zone is never coupled directly to MODFLOW head. It communicates through
the lower-SWAP state.

## New research hypothesis

A fixed-interface head may remain a sufficient *physical interface variable*
while being insufficient as a full descriptor of the internal SWAP state.

For the first linear two-state model, the stronger prospective hypothesis is:

> Given one immutable committed two-state SWAP origin, constant forcing over a
> coupling window and a scalar trial interface head, the exact integrated
> interface response is affine in that trial head. Therefore one scalar response
> tangent plus one intercept can be exactly sufficient for the current window,
> even though `H_c` alone is not sufficient to reconstruct the internal state.

This statement is restricted to the linear time-invariant first model. It does
not preregister scalar sufficiency for nonlinear or real-SWAP regimes.

## Storage ownership and ledger boundary

For unit horizontal area the first model owns two disjoint SWAP inventories:

- root-zone inventory `W_r`;
- lower-SWAP inventory with change `S_l (h_l1-h_l0)`.

MODFLOW inventory is separate.

The vertical root-to-lower transfer `E_v` is internal to SWAP. The fixed-plane
exchange `E_c` is internal to the complete SWAP+MODFLOW system.

For one window:

```text
Delta W_r                 = F_r - E_v
Delta W_l                 = E_v - E_c + F_l
Delta W_MODFLOW           = F_M + E_c
------------------------------------------------
Delta(W_r+W_l+W_MODFLOW)  = F_r + F_l + F_M
```

where every `F` is an external integrated source minus sink for its declared
control volume. No interface or internal vertical transfer survives the total
ledger.

## Explicit nonclaims

This reconciliation does not establish real SWAP/MODFLOW storage non-overlap,
production drainage ownership, production irrigation scheduling, Richards
physics, Ribasim allocation equivalence, or production admission.
