# External irrigation availability and joint continuation

Workstream: MC-IRR01. Existing capability: `SW431-IRR-AVAIL`.
Status: implemented; complete scientific qualification and canonical admission pending.
Recovery authority: `integration/audits/MC_IRR01_STATUS.json`,
`availability_completion_20261016`. Baseline: `341ba378`.

## Fixed source contract

The authenticated B1.11 `irrigation.f90` TASK4 scales `gird` by the supplied
availability fraction, and scales event duration only when configured `IRR_RATE`
is positive. It never scales `qssdi`. Consequently zero configured rate with
SSDI retains the selected daily gift even for fraction zero. This existing source
semantics is preserved; external availability is not replaced by a new water
allocation model. Fractions must be finite and in [0,1].

The existing allocation owner validates positive source identity, nonnegative
revision and a half-open selection-valid time window. It freezes the provider
receipt with the selected accepted event. Changed, missing or expired provider
input during that event cannot reselect or rescale it. A subsequent event requires
a fresh valid provider. Rejected trials and stale replays cannot publish or repeat
water, event, crop or receipt state.

## Existing owners and native representation

The existing weather/bootstrap, current-root/material and allocated irrigation
owners perform preparation and accepted publication. The existing
`mod_crop_soil_n_joint_restart_file` adapter retains tag `S5WI0001`, its payload
bytes, CRC, source/configuration binding and trusted owner reconstruction. Its
profile checks now accept the already admitted managed selectors 2/3/4/6/7/8,
including the existing root-free sensor profile, rather than requiring TCS6.
No second codec, calendar, physical ledger or provider owner is introduced.

Root-free sensor admission is an emerged one-day profile. Its separate crop owner
still rejects next-day active growth without the rooted profile. Native
continuation is tested inside that existing day. Fresh subsequent-event allocation
and actual daily growth are tested over consecutive rooted weather days. This
change does not broaden crop, hydraulic, salt or selector admission merely because
those components can supply an input to the availability modifier.

## Qualification selection

The small production TASK4 owner is compared bitwise with the authenticated
literal branch at 101 fractions for both application kinds and zero/positive
configured rates: 404 source vectors per O0/O2. Existing nonfinite controls remain.

The targeted physical matrix uses actual authenticated weather, Richards state,
current crop/root evolution and accepted mass assertions. Rooted selectors 2/3/4/7/8
exercise DCS1/DCS2, zero/positive configured rates, provider fractions
0/0.25/0.5/1, provider expiry, rejected inputs and actual repeated event selection.
Root-free pressure/water-content sensors cover independent rain/ET and one/three
SSDI nodes. Continuous, opaque and native fresh-process tails must have exact
complete endpoints. Original TCS6 native endpoints must remain byte-identical.
Checksum-correct invalid provider, state, source and configuration records must
reject without partial publication.

The admitted 295-provider O0/O2 build supplies only source-, compiler-, artifact-
and ABI-verified unchanged objects. The two changed executable profile guards and
all selected drivers are compiled fresh. The drainage module's inherited unused
insertions retain the existing exact projection authority. Raw executions, donor
identity, failed history and admission negatives are sealed before integration.
No broad moving F-CI, RossFast, highest low-air or hosted Actions is selected.
