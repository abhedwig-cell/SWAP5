# PPA-WU05-A18 Andelst source-backed perched authority

Date: 2026-10-01

Status: `G1_SOURCE_AUTHORITY_RECOVERED`

## Authority

User-supplied official `SWAP_4.3.1.zip`.

Outer archive SHA-256:
`76a79498423ee612a7861efb564b10c4360a4f648396eefcf8e9011919a66039`.

Nested exact `SWAP.ZIP` SHA-256:
`1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

Official bundled case:
`cases/3.macroporeflow`, project `Macropore flow (Andelst)`.

## Local source execution

The shipped Linux binary requires Intel `libimf.so`, unavailable in the current
container. TTUTIL and SWAP were therefore rebuilt locally from the shipped source archives
with gfortran.

Intel `!DEC$` conditionals were preprocessed only to select the standalone non-MultiSWAP,
no-ANIMO, no-SSS route.

The gfortran build exposed legacy out-of-bounds behavior in early MACROSTATE internal-flux
bookkeeping. For diagnostic execution only, local index guards prevented node-zero access.
Those guards are not repository implementation, are not a proposed source repair, and are
not used as physical authority.

The hydraulic authority comes from exact CALCGWL state/topology and the unmodified
official Andelst input/soil/macropore definitions.

## Distinct perched groundwater

The shipped Andelst case does contain a distinct perched body.

Observed finite exact-source carrier state:

- `t1900 = 35797.50171595`;
- `NPeGwl = 27`;
- `BPeGwl = 48`;
- `PeGwl = -26.38080381 cm`;
- `PeGwl_bot = -61.17313674 cm`.

A subsequent observation in the same source-backed interval:

- `t1900 = 35797.50312983`;
- `NPeGwl = 25`;
- `BPeGwl = 48`;
- `PeGwl = -24.37244232 cm`;
- `PeGwl_bot = -61.15970759 cm`.

This is not the ordinary groundwater table duplicated under another name. A substantial
under-saturated separator exists between the upper saturated lens and the deeper saturated
body.

## Full 112-node snapshot

A complete `z/dz/h/theta` state was captured at
`t1900 = 35797.5031298316`.

At the first CALCGWL evaluation of that captured state, the topology was
`NPeGwl=27`, `BPeGwl=48`. That particular first evaluation still carried sentinel
`PeGwl=999`; the finite carrier observations above come from subsequent exact CALCGWL
evaluations in the same official interval. The evidence is deliberately kept separate.

The full state is persisted losslessly in four CSV chunks:

- `PPA_WU05A18_ANDELST_NODES_001_028.csv`;
- `PPA_WU05A18_ANDELST_NODES_029_056.csv`;
- `PPA_WU05A18_ANDELST_NODES_057_084.csv`;
- `PPA_WU05A18_ANDELST_NODES_085_112.csv`.

The captured profile itself shows the topology directly:

- node 27: `h = +0.2924684103 cm`;
- nodes 28-47: under-saturated separator;
- node 48: `h = +0.8030103220 cm`;
- deeper nodes remain saturated.

## Decision

A18 G1 passes:

`EXACT_4_3_1_ANDELST_DISTINCT_PERCHED_AUTHORITY_RECOVERED`.

The A17 blocker is therefore narrowed from “no perched authority exists” to the concrete
next problem: reproduce this exact source-backed 112-node hydraulic state in the SWAP5
explicit Reference-Richards baseline with the macropore callback disabled.

Only after that independent baseline is solver-stable may A17 be replayed.
