# Groundwater coupling storage-ownership contract

Date: 2026-09-21
Status: RESEARCH CONTRACT, production read-only

## Why this contract is needed

The current SWAP5-MODFLOW6 coupling stack has strong algebraic and transactional
contracts for:

- response construction;
- MODFLOW HCOF/RHS publication;
- corrector reanchoring;
- coupled residual closure;
- candidate acceptance;
- exactly-once interface-mass publication.

What it does not yet declare is a physical storage-ownership contract between a
SWAP column and the MODFLOW STO package.

That omission matters only after the physical domains are declared.

The same pair of coefficients can be:

- physically correct for two distinct storage volumes;
- physically correct as a partition of one shared storage volume;
- physically wrong because one coextensive storage volume is counted twice.

Therefore storage ownership is a physical-domain question before it is a
matrix-coefficient question.

## 1. Required vocabulary

Use these separate concepts.

### Interface hydraulic head

A hydraulic head prescribed at the SWAP lower interface and represented by a
MODFLOW cell head.

This is the current F-GC production interpretation established by MAP11 for the
F-GC45 fixture.

It does not, by itself, imply that SWAP and MODFLOW own the same phreatic
storage volume.

### Shared phreatic head

One physical water-table state that both components use as the same phreatic
state.

A shared phreatic state may still coexist with SWAP-owned internal memory.

### Physical storage volume

The real water volume associated with a head change in a declared control
volume.

### Numerical response slope

A derivative used to accelerate or represent a local coupling response.

It may have storage-like units without owning a physical storage volume.

## 2. Coupling mode A: distinct-domain boundary coupling

Physical declaration:

- SWAP owns a soil-column control volume;
- MODFLOW owns a groundwater control volume;
- the two domains meet at an interface;
- interface exchange is a physical transfer between the domains;
- each domain may own its own storage.

Schematic:

```
SWAP storage  | interface | MODFLOW storage
      q_swap outward -> groundwater
```

Requirements:

- no storage-partition identity between SWAP storage and MODFLOW Sy/Ss is
  implied merely because an interface head is shared;
- accepted interface exchange must be counted once as loss from one domain and
  gain to the other;
- a local response coefficient such as `u_A` is not automatically a second
  physical storage in MODFLOW.

MAP11 classifies the current F-GC45 fixture in this direction.

## 3. Coupling mode B: coextensive shared-phreatic storage

Physical declaration:

- SWAP and MODFLOW refer to the same phreatic storage volume;
- there is one physical head;
- a head change corresponds to one physical water-volume change.

Then storage ownership must satisfy:

```
S_total(H) = S_MODFLOW(H) + S_SWAP(H)
```

locally, or in integrated form:

```
Delta V_physical
  = Delta V_MODFLOW_owned
  + Delta V_SWAP_owned.
```

There may be no overlap and no gap.

Allowed endpoint examples:

```
MODFLOW owns all shared storage:
S_MODFLOW = S_total
S_SWAP    = 0
```

or:

```
SWAP owns all shared storage:
S_MODFLOW = 0
S_SWAP    = S_total
```

or any explicit partition between them.

DSW23 is the geometric oracle for this contract using the transparent
1 m2 by 10 m column with uniform drainable porosity 0.20.

## 4. Duplicate ownership

If the physical declaration is one coextensive storage volume but both models
claim the full storage response:

```
S_MODFLOW = S_total
S_SWAP    = S_total,
```

the numerical subsystem bookkeeping can still close.

That does not make the physical formulation correct.

For a 10 mm input into the DSW23 column:

```
physical storage = 0.20
expected dh       = 0.010 / 0.20 = 0.050 m
```

Duplicate ownership gives:

```
effective numerical storage = 0.40
dh                           = 0.025 m.
```

Both bookkeeping owners then record 5 mm equivalent storage gain, so the
algebraic ledger sums to the 10 mm input. But the one declared physical volume
has risen only 25 mm and therefore contains only 5 mm of extra drainable water.

The error is a domain-ownership error, not a solver-residual error.

## 5. Missing ownership

The converse is also possible.

If neither component owns a physical storage contribution that is present in
the declared shared volume, the coupled head response is too large or the
system may become algebraically underdetermined.

Therefore the ownership rule is:

```
no overlap
and
no gap.
```

## 6. Coupling mode C: response-only SWAP term

A SWAP-side term may represent only process/boundary exchange while MODFLOW STO
owns the complete shared groundwater storage.

Then the SWAP coupling term must exclude the storage already owned by MODFLOW.

For a transparent linear shared-storage system this is the alpha=0 endpoint of
DSW23.

This mode is not implied by current production `u_A`; whether a real SWAP
response contains storage, process response, or both must be derived for the
declared physical domain and time window.

## 7. Finite-window response is not static Sy

MAP03 and MAP10 show that real-SWAP `u_A` can match the local finite-window
whole-column storage derivative in simple drainage-free fixtures.

MAP10 also shows that `u_A` changes strongly with coupling-window duration.

Therefore:

```
u_A != universal static specific yield
```

unless a separate derivation establishes that identity for a specified limit
or regime.

This distinction is central to ownership design:

- physical storage ownership concerns one declared physical volume;
- `u_A` is a finite-window response object with provenance.

## 8. Product-driver declaration required

Any future production driver that supports SWAP-MODFLOW coupling should declare
at least:

1. coupling mode:
   - distinct-domain boundary;
   - coextensive shared-phreatic;
   - another explicitly derived mode;

2. physical control volumes owned by SWAP and MODFLOW;

3. storage ownership:
   - which MODFLOW Sy/Ss terms belong to the coupled physical volume;
   - which SWAP storage response belongs to that same volume;
   - proof that the sum has no overlap or gap;

4. accepted physical exchange object and sign convention;

5. which response derivatives are physical and which are iteration policy;

6. independent mass and residual gates.

## 9. Current production classification

From current source-bound evidence:

- F-GC33/F-GC40 define the affine response representation;
- F-GC39/F-GC49D define iteration and transaction ownership;
- MAP11 shows the F-GC45 production fixture is a shared-interface-head boundary
  coupling, not a demonstrated coextensive shared-phreatic storage model;
- the audited production contract does not yet declare a general physical
  storage partition relative to MODFLOW STO.

Therefore:

- do not claim current production storage is double counted;
- do not claim it is proven not to be double counted in every product
  configuration;
- require explicit domain/storage ownership before admitting a coextensive
  shared-phreatic product configuration.

## 10. Research closure path

Before any production storage reformulation:

1. qualify DSW23;
2. close the pending DSW22 real-response-versus-inventory test;
3. close MAP08/MAP09 process-domain investigations;
4. define a prospective product-level coextensive configuration if that mode is
   actually intended;
5. derive the physical balance and storage partition for that configuration;
6. qualify it with independent volume, interface-mass and coupled-residual
   gates.

Until then this document is a research contract only.
