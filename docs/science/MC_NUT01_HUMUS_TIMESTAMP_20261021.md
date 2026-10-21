# Historical humus timestamps

Candidate, MC-NUT01, baseline canonical d7b89175 (21 October2026).
The existing HIST-COMPLETE status remains the admission authority.

Original archived TTUTIL RDDECT in rdlex.for accepts a date followed by an
underscore and hour:minute, optionally seconds and fractional seconds. DTARDP/
DTSYS maps this to a double precision ordinal day; fractional seconds first pass
through the original default REAL. SoilManagement selects the humus experiment
using the already established interval-endpoint predicate. A fractional clock
does not split an original daily chemistry calculation at that clock.

This extension supports the existing numeric YYYY-MM-DD and DD-MMM-YYYY dates
with `_HH:MM`, `_HH:MM:SS` and fractional seconds. Date-only input remains exact.
Original hours24..99 normalize into following days; a trailing seconds decimal
point means zero fractional seconds. Both details are retained, and the original
day1 arithmetic order is preserved before conversion to SWAP5 day0. Wider hour
field widths and other date spellings are outside this bounded input extension.
Only tstartHumexp gains this grammar; amendment event dates remain daily. Source
activation and the existing reactive parameter validator accept finite ordinal
fractions within their existing range. Absent/disabled experiment constraints
remain unchanged. No process equation, state, restart schema or solver changes.

Qualification selection: original TTUTIL O0/O2 interpretation including invalid
clocks; actual native input atomicity and physical source-line mapping; original
rateconstant endpoint selection and real reactive-owner fractional-switch/restart
controls; targeted accepted Reference/crop/Soil-N composition across that switch.
Prior full HIST/retained evidence is preserved only by an exact old-domain body
proof and current dependency check, never by relabelling a fixture as a model.
Expected direct feedback below60seconds; full composition build cost is UNKNOWN
until measured. Existing unchanged solver/RossFast/aquifer gates are not selected.

Invariants: historical units/order and parameter identity; accepted-state-only
publication, atomic failure, mass conservation and persistent restart. Remaining
negative active-crop and automatic surface contracts are outside this extension.
