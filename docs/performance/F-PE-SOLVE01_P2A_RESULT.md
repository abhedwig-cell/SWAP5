# F-PE-SOLVE01 P2A result — N:1 SWAP scale mechanics

Date: 2026-09-27

Status: `PASS_SCALE_CAPABLE`

PR:
`#654 — F-PE-SOLVE01: bounded discarded-trial Richards solve elimination`

Workflow run:
`36301100126 — F-PE-SOLVE01 EF upper bound`

Job:
`p2a-n1-scale`

## Scope

P2A isolates SWAP-side N:1 scaling using the production-shaped ownership pattern:

- one shared serialized Reference backend;
- participant registry;
- application context;
- per-tile ledgers;
- N real SWAP participants contributing to one groundwater-cell aggregate;
- exact final validation and exact per-tile commit.

The qualified BALTOL02 balance floor is replayed only inside the research harness.

Both E0 and E4 use the same research-only temporal envelope.

## Results

### N = 1

- E0 repeated-corrector time: `0.313851468 s`;
- E4 repeated-corrector time: `0.117535064 s`;
- runtime ratio: `0.374492637`;
- speedup: `62.550736%`;
- E0 exact tile trials: `3201`;
- E4 exact tile trials: `1201`;
- solve reduction: `62.480475%`.

### N = 100

- E0 repeated-corrector time: `1.570646083 s`;
- E4 repeated-corrector time: `0.591875996 s`;
- runtime ratio: `0.376836006`;
- speedup: `62.316399%`;
- E0 exact tile trials: `16100`;
- E4 exact tile trials: `6100`;
- solve reduction: `62.111801%`.

### N = 1,000

- E0 repeated-corrector time: `3.181581565 s`;
- E4 repeated-corrector time: `1.199105499 s`;
- runtime ratio: `0.376889756`;
- speedup: `62.311024%`;
- E0 exact tile trials: `33000`;
- E4 exact tile trials: `13000`;
- solve reduction: `60.606061%`.

Equivalent N=1,000 speedup factor:

`1 / 0.376889756 ~= 2.65x`.

## Authority

For N = 1, 100 and 1,000:

- final aggregate q is identical between E0 and E4;
- final committed SWAP state is identical;
- every tile commits exactly once;
- every tile ledger commits exactly once;
- no approximate candidate state is published.

## Scaling interpretation

The E4 runtime ratio is effectively flat across N:

- N=1: 0.3745;
- N=100: 0.3768;
- N=1,000: 0.3769.

There is therefore no evidence in this range that registry/application-context scaling erodes the solve-elimination benefit.

The observed runtime gain tracks the reduction in full Richards trial work closely.

P2A therefore supports the claim that discarded-trial solve elimination remains a large SWAP-side performance lever at MultiSWAP-relevant participant counts.

## Gate disposition

P2A gates:

- N=1,000 completion: PASS;
- >=50% exact tile-trial reduction: PASS;
- >=30% repeated-corrector wall-clock gain: PASS;
- exact final aggregate authority: PASS;
- exact per-tile commit ownership: PASS;
- no approximate publication: PASS.

Decision:

`ADVANCE_FINAL_HETEROGENEOUS_LIVE_P2`

P2A is not itself a production admission or a live-MODFLOW scale claim.

P1 remains the live-corrector robustness authority.

The next step must combine:

- heterogeneous difficult SWAP profiles;
- live MODFLOW-generated correctors;
- E0 versus E4;
- application-level end-to-end timing.
