# Explicit amendment-table input to the admitted calendar

Work unit MC-NUT01-AMENDMENT-INPUT. Owner MC-NUT01. Baseline canonical
`7c774455bf1d5918b76d6147a23cc159ba427e8b`. One additive producer, one PR.
See the [source audit](MC_NUT01_INPUT_SOURCE_AUDIT_20261015.md) for original
same-file reads, positional material association and the narrower physical domain.

Implement an explicitly invoked management-table export reader, not a generic
TTUTIL or complete legacy `.snm` reader. Its file contains exactly two tables,
material definitions followed by events. This explicit subset can be prepared
from management sections; additional soil-parameter sections are rejected.
No automatic activation or project/default file discovery.

Headers, case insensitive, are `MatNum MatName AppAge OrgMatFrac OrgNFrac
NH4NFrac NO3NFrac` and `smedate iMat Dosagekgha VolatFraction`. Spaces/tabs or
single commas separate fields; names are single/double quoted ASCII, at most25
characters. Empty fields, quote escapes/concatenation, scalar assignments,
repetition and missing-value syntax are unsupported and must fail closed.
Blank lines, column-one `*` comments and unquoted `!` trailing comments are allowed.
The bounded export has at most4096 lines and2047 characters per record; overlong
records must be detected before truncation can turn malformed input into success.
Require1..20 ordered materials with `MatNum` equal to their1-based positions;
allow0..1000 ordered events and at most64 on one day. Preserve same-day order.
No partial table or valid plan may survive any late read/parse error.

Explicit origin and event dates use midnight `yyyy-mm-dd` or `dd-mmm-yyyy`,
English three-letter months, case insensitive, Gregorian years1900..9999.
Convert to integral days since1900-01-01; reject invalid leap/month/day dates,
intraday and unrecognized spellings. The same conversion handles origin and
events. Events before origin fail. Dose remains kg/ha and the existing calendar
alone converts by1e-4. All numeric tokens must be finite with bounded safe
decimal/exponent syntax before conversion; reject overflow and nonfinite input.
Age0..100, fractions0..1, dose0..500000 are the admitted producer intersection.
Existing downstream chemistry remains the authority for physically applicable
organic mixtures and thresholds; input validation does not admit new chemistry.

The result is the existing private immutable calendar. File IO, tokenization and
date conversion own no accepted N/water/crop state, cursor, restart field or clock.
Read errors include an explicit status and line, with no STOP or partial output.
The caller supplies external forcing again on restart. Existing senescence,
reaction, crop, water, publication and restart owners are bytewise unchanged.
Affected invariants3/4/7/9/13/21/23/29/30 remain binding.

First qualify a four-provider production driver at O0/O2 with independent Python
Gregorian/date expectations, syntax/domain/capacity/late-failure and immutable
plan checks. Then freshly compile the actual current day and Richards composition
with the reader; compare manual, typed and file plans using complete native and
opaque endpoint bytes, fresh-process restart, pending senescence, literal original
eight-pool/mineral/supply oracles, rollback, retry and replay. Fixtures are
explicitly derived table exports, not represented as authentic old project files.

Expected tiny compile2s, actual day20s, joint300s from previous measurements.
Record compile/link/native separately; per-physics UNKNOWN. At stable admission,
select one full local moving OFF, expected1677s, because the new external input
boundary now feeds accepted actual Richards days. Do not duplicate Actions.
Highest low-air NOT_SELECTED_POLICY. Preserve all owning raw/source/negative
guards; reject foreign production changes. No capability-count promotion.
Pond/source open; aquifer rejected. Heat/profile, harvest/reset/rotation,
simultaneous companions and full-file/default input remain separate.
