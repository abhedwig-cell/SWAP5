# F-MIG431 lower-boundary migration closeout

Status: CANONICAL_CLOSED

Date: 2026-10-03

## Decision

The SWBOTB lower-boundary migration workstream is closed as a production migration line.

Closure means that the production-relevant lower-boundary routes selected for SWAP5 migration have reached their governed end state, with qualification and canonical admission recorded in their work-unit evidence. It does not claim that every historical selector or implementation variant in the legacy source has been promoted to a SWAP5 production application.

## Canonical admitted routes

- LOW03-A: ordinary implicit Cauchy application, SWBOTB=3 implicit route. Production admission PR #977, merge `6f2b1b73a02d1f6492cc31cfea13964d3020854e`; closeout PR #978.
- LOW05-A: ordinary prescribed-head application. Existing canonical authority remains the governing application/retry/restart evidence.
- LOW08-P0: typed SWBOTB=8 lysimeter-plate solver route. Qualified postimage `7198b2ad4e9208efbe0ad9e312688dca8c178975`, qualification run 37000264871, artifact 11223621131, admission merge `4a743bda053a67e26e559e788e98fddac3b796ff`, closeout merge `d6a9e5a9edfec92d463ad0e30b4b5b6a39e9511c`.
- LOW08-A: ordinary non-groundwater-owned SWBOTB=8 application. Qualified postimage `487b6bc2aac187844e6a25fc2ba38f047b80f36c`, qualification run 37073798161, artifact 11256088839, canonical admission merge `10d80799b04197f775f83686beb6d61304f9850d`, post-admission status closeout `1d3800aa64e799d5fcb92e8ff1df8786729183d7`.

LOW08-A preserves the LOW08-P0 solve-local active set. The temporal certificate reconstructs the mode-8 branch from the immutable solve-entry request/base state. No persistent active-set state, restart field, qbot-value inference, groundwater ownership, or generic kernel-contract extension was introduced.

## Explicit residuals

These items are deliberately not blockers for this closeout:

1. SWBOTB=1 remains parked by decision. No production-admission claim is made for it.
2. Explicit `SwBotb3Impl=0` remains a historical legacy variant and is not promoted as a SWAP5 production application. The admitted SWBOTB=3 production route is the implicit LOW03-A route.
3. Internal selectors `-2` and `9` are not ordinary application selectors and are outside this application-migration closeout.

Any future need for one of these residuals requires a new, separately preregistered work unit with its own production justification. Reopening this closed migration line is not implied.

## Claim ceiling

The closeout claim is: **production-relevant SWBOTB lower-boundary migration closed, with named historical residuals explicitly deferred/out of scope**.

It is not a claim that all historical lower-boundary code paths are production-admitted, nor that every legacy selector should remain indefinitely.
