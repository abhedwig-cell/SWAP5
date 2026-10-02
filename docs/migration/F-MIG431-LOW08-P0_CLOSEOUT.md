# F-MIG431-LOW08-P0 closeout

Final status: **CANONICAL_ADMITTED_CLOSED**.

Qualified exact postimage: `7198b2ad4e9208efbe0ad9e312688dca8c178975`.

Persisted qualification: Actions run `37000264871`, SUCCESS, artifact `11223621131`.

## Qualified law

SWBOTB=8 is the lysimeter-plate active-set lower boundary. The corrected B1.11 selector is evaluated in the first residual evaluation:

`h(N) > hplate - grid_disnod(N+1) + 1e-5 cm`.

Equality is inactive. The bottom distance is the node-to-boundary-face distance, not the ordinary node-to-node distance. For the homogeneous qualification geometry this is `0.5*dz(N)`.

Inactive branch: `qbot=0`.

Active branch: prescribed plate pressure head `hplate`, Darcy bottom-face flux, and the corresponding prescribed-head Jacobian contribution. The selected `flboth` branch is reused through Newton/backtracking and is solve-local only.

## Typed ownership

Mode 8 reuses `boundary%bottom_head` for hplate. No new public field, transaction state or Restart-v1 field is introduced. Typed accepted qbot is published through the existing prescribed-head mass/flux owner; inactive mode remains exactly zero.

## Qualification

O0 and O2 pass the LOW08 direct threshold/regime/mass/replay/fail-closed fixture and preservation fixtures for LOW03 typed mode 3, LOW01-A and LOW02 application behavior.

## Nonclaims

This is solver-route admission only. No ordinary production application/bootstrap profile for SWBOTB=8 is admitted by P0. SWBOTB=1 remains parked and explicit SwBotb3Impl=0 remains open.

Canonical admission: PR #984, normal merge `4a743bda053a67e26e559e788e98fddac3b796ff`.
