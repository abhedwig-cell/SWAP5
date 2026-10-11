# PPA-WU05-A22B result — RFM persistent MB wall/deep fate

Date: 2026-10-01
Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE
Baseline: integration/f-ci-canonical@8bfff34e5bf06817f63a571282f70436cd90ede2
Qualified postimage: 8a30765b2f065f4432b340179a010f7a8f0a4fe0
Qualification run: 36873358399 — SUCCESS

Focused gate:

    PPA_WU05A22B_RFM_MB_WALL_DEEP_FATE=PASS

## Result
The ALT34 fixed MB release rate of 1 h^-1 is not required in the bounded production route.

A22B interprets f_MB according to the frozen parameter contract: persistent continuous/deep pathway fraction. MB input is resolved during the interval as:

    MB_input = wall_to_matrix + deep_receipt

using the same reduced Philip/Darcy wall law as the terminating route over caller-owned persistent contact length.

The surviving deep receipt is a distinct RFM external/deep-path receipt. It is not silently added to standard matrix qbot.

## Qualification
The first preregistered numeric fixture accidentally gave Philip capacity slightly above the entire 0.5 cm MB input. Run 36873267169 therefore failed the intended partial-survival assertion. The physical operator was unchanged; only the oracle sorptivity was reduced from 0.1 to 0.02 cm/sqrt(day) to create the intended partial wall/deep split.

The repaired exact-head run 36873358399 passed.

Qualified:
- partial wall exchange with positive deep survival;
- wall-capacity-limited case with zero deep survival;
- exact MB input = wall + deep closure;
- invalid exchange length fails closed.

## Decision

    ALT34_MB_RELEASE_1_PER_H = REMOVED_FROM_PRODUCTION_ROUTE
    RFM_MB_WALL_EXCHANGE_OWNER = QUALIFIED
    RFM_MB_DEEP_RECEIPT_OWNER = QUALIFIED
    STANDARD_MATRIX_QBOT_OWNERSHIP = UNCHANGED
    A21_FAST_DOMAIN_FATE_BLOCKER = RESOLVED_BY_A22A_PLUS_A22B

A later composition workunit must still prove end-to-end candidate/commit whole-column closure before removing the A20 live-runtime guard.
