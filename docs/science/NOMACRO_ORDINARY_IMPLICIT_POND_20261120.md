# Ordinary implicit pond continuity and chain rule

This bounded numerical batch corrects the original ordinary, nonmacropore
SWKIMPL1 pond interface. Neutral qualification is frozen at
`4027e71aa5e8e9af64f1ae94cf64e9018a9b734d`; canonical admission remains pending.
The numeric implementation is `b96f69a397615d24f7af4fc1cdf28bf591957a04`.
The final read-only compiled-source guard is
`614e1c5a5ce383222d6febb9d183aac14bf4a625`.

## Original defects and bounded correction

Actual original mean6/history2/head runs exhausted their 180-second budget after
163 accepted days. Read-only nodal evidence locates a discontinuity at the old
positive-pond threshold of 1e-6 cm. Complete original MOD_top probes independently
show a Darcy flux jump exceeding 1e-5 cm/day. Selecting positive pond at h0>0
removes this jump without changing its pond equation.

The original ordinary Newton row also omits the response of pond height to soil
conductivity. The correction composes the actual soil conductivity partial once
with `(1+s)/(1+dt*G+s)`, where s is the derivative of original runoff amount.
The existing qualified extended pond chain-rule renderer supplies the row
composition. The fixed-head branch remains literal.

The original nonlinear pond root stopped at 1e-6 cm and fails the unchanged
1e-8 derivative finite-difference criterion. Its replacement brackets the same
original runoff equation, uses at most 128 bisections, and terminates at an exact
zero or adjacent floating values. The original exact linear branch remains.
No mass correction, artificial water, new physical state or native format is
introduced. The rejected saturated-capacity experiment remains private evidence.

## Actual evidence and preserved criteria

Windows and Ubuntu, O0 and O2, each provide a weighted mean6/history2/head water
period and a mean4/history2/groundwater CDE period: eight actual 1096-day periods
and 64 exact complete-native cold windows. Windows O0/O2 physical rows agree
exactly. Six representative 35-day compositions per platform/optimization cover
means1..6, history0/1/2, groundwater/head/plate bottoms, and the original daily,
monthly, periodic, explicit-date and per-step output owners.

Independent 80-digit observations check 40 complete-original chain-rule points
and 64 runoff-limit points per platform/optimization. The largest derivative
gap is 1.17e-14. Actual malformed source and policy fixtures provide 320
before-worker refusals, including attacks that forge mutable generated hashes.
Eighteen current read-only-guard cold postimages, four transactional contexts and
six unchanged explicit/extended postimages preserve their relevant bytes.

Daily and whole-period water guards and daily/integrated CDE guards remain
1e-10 in their original units. MAXIT100, MAXBACKTR10, retry factors, advancing
clock checks, rejected-state rollback and accepted-state ownership are unchanged.
After the numerical corrections, stable accepted progress justified an explicit
600-second resource budget for the weighted water full period. Original
180-second censors remain raw evidence; the numerical criteria were not changed.
CDE full qualification retains its 180-second resource budget.

## Provenance and proportional reuse

Seven immutable ORDINARY_IMPLICIT_POND raw archives preserve original Windows
and unrepacked GitHub artifact bytes, compiler/input/native identities, original
failed or censored phases and the rejected diagnostic. Frozen independent readers
are `69f03573043fcd5bf6fe6c9b323bcccb176c485a`.

The initial Ubuntu jobs fail at an unsupported fourth fixture after successful
full water and three short configurations. Their qualified observations are
decoded from original artifacts; no whole-job PASS is asserted. The successful
followup runs only the three missing short configurations, full CDE and relevant
component/source controls. It does not repeat full water.

Unchanged explicit and extended implementations reuse the actual clean canonical
d785e2c3c registered observation after exact source, old reader, old raw checksum
and current affected-postimage checks. Prior ordinary postimages remain historical
observations and are replaced by this new ordinary qualification. Old scientific
assertions and raw archives remain literal.

## Remaining scope

The existing examined-Ksat, unsupported soil and AGE dry-moment refusals remain.
Groundwater/history CDE with non-daily reset cadence is still refused before
compilation and is the next existing-process composition batch. This qualification
does not close the whole historical family. Global remaining counts stay UNKNOWN;
functional closure is PARTIAL, whole scientific equivalence NOT_QUALIFIED and
fixed RC3 unchanged.
