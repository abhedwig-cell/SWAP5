# PPA-WU05-A11 closeout — canonical bounded RFM unponded activation service

Date: 2026-10-01

Status: CLOSED_CANONICAL_ADMITTED

Decision:

    CANONICALLY_ADMITTED_BOUNDED_RFM_UNPONDED_ACTIVATION_SERVICE

## Canonical evidence

- baseline: `ebea588070f7a44dbaea78169f2548c745061c48`
- qualified postimage: `bf3e8424eccf271d943e03bfe16c76f97ff0bc08`
- focused qualification run: `36859780186` — SUCCESS
- admission PR: #930
- canonical merge: `a9aa16681a4c4b89b7dea0af2d601744b8b9e08b`

## Admitted capability

Canonical production source now contains a reusable deterministic RFM
unponded/source-controlled activation service.

It accepts explicit:

    sigma_B
    K_surface
    S_surface
    source rate
    event age
    ponding depth

and returns:

    b50
    matrix rate
    preferential rate
    preferential fraction

with exact source partition closure.

## Scientific boundary

This admission does not imply that sigma_B has been identified universally.

In particular:

    no default sigma_B is admitted
    no event-specific fitting is admitted
    no ponded/head-controlled use is admitted

Positive ponding fails closed.

The service is therefore production-grade code for a bounded physical operator,
not yet a fully admitted alternative macropore runtime.

## Architecture preservation

A11 does not change:

- current A8/A9/A10 macropore execution;
- top-input ownership;
- event-age ownership;
- committed/candidate state;
- restart payload;
- f_MB;
- p;
- tracer/solute transport;
- depth routing.

No existing runtime file was changed by A11.

## Post-merge preservation

The relevant dependency surface at the canonical merge is byte-identical to the
qualified postimage.

Blob identities:

    source:
      9e4533801862146495f430089b2c489e3a22a21a

    test:
      afe75079aa4f68aaea512c8ef3a72630c215032d

    runner:
      33c43f8af7a5cfe3219340dcd8f2bc2753a6385a

These are identical between the qualified exact head and canonical merge.
Under the repository evidence-inheritance rule, the focused qualification is
therefore preserved without an additional CI replay.

## Lifecycle

    implemented
      -> persisted
      -> tested
      -> qualified
      -> canonically admitted
      -> closed

## Next safe slice

PPA-WU05-A12 should bind:

    committed process hydraulic view
      -> constitutive K_surface
      -> qualified surface sorptivity
      -> A11 activation request

while preserving these boundaries:

- no top-input ownership change yet;
- no event-age hidden state;
- no default sigma_B;
- ponding remains fail closed.

Only after that binding is qualified should a later workunit consider changing
actual FMR source partition ownership.
