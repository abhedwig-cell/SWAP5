# MC-NUT01-R2: simultaneous amendment events

Proposed bounded B1 reference correction, baseline canonical
`3b661766dc59298a7f541c970c2d3a55602d926c`, owner MC-NUT01.
Follow `docs/verification/principles.md`: qualify corrected B1 before B2.
The immutable archive/reference manifest is not edited.

Exact management_soil.f90 SHA256
`0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b`
rejects decreasing dates at lines136..143. Its grouping at lines151..166 uses
`smedate(isme)-smedate(isme-1) < 0.d-3`. A difference between sorted dates cannot
be negative, including identical dates. Thus every event gets a separate group.
Task3 lines347..354 checks only the next group once per day and increments its
cursor once. Two records on the same date leave the second behind on the next
day; later dates can never be reached. This is demonstrated, not assumed.

R2 changes exactly that literal grouping comparison to `< 1.d-3`, matching the
existing task3 trigger tolerance. Retain source order and the rejection of
decreasing dates. Do not sort, clip, shift missed events, or repeat application.
Qualify original failure first, then corrected grouping/trigger, then B2 daily
selection and complete physical N accounting. Include same-day distinct
materials/doses/volatilization followed by later dates, and single-event/no-event
identity. This does not qualify unrestricted fractional-time schedules.

B2 supports dates on one explicit daily grid, sorted nondecreasing, with at most
64 amendments per day and4096 records. It rejects nonfinite/out-of-range dates,
fractional grid dates, invalid doses/fractions, ambiguous timing and
unsorted records. Same-date material records are not duplicates: all apply once
in source order. Native state/restart and crop fixation remain unchanged.
