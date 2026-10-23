# Zero biomass and humus turnover rates

Bounded implementation with qualification in the owning STATUS.json and actual
canonical admission only in ADMISSION.json. Both receiving-pool rates
must be exactly zero. Other singular/coincident-eigenvalue cases retain their
existing guards. No threshold is relaxed.

Historical OrgMatN coefficients imply dF_i/dt=-k_i F_i,
dB/dt=sum(a_i k_i F_i), dH/dt=sum(b_i k_i F_i) at k_B=k_H=0.
Thus F_i=F_i0 exp(-k_i dt), B=B0+sum(a_i F_i0 (1-exp(-x_i))),
and H analogously. Interval averages replace the accumulated fraction with
1-(1-exp(-x_i))/x_i, whose x=0 limit is zero. Carbon dissimilation comes only
from the non-assimilated fresh-material loss. Receiving pools do not disappear.

A bounded Taylor series avoids cancellation for x<=0.125; the direct exponential
form is used above that bound. The public numerical helper validates finite
nonnegative x and reports invalid inputs. New physical/process/state policy is
not introduced. Nonzero-rate execution and all existing tolerances are retained.

Affected invariants:3,7,13,21,23,25,26,30. Current pool transfer and crop/soil
owners remain authoritative for complete N balance, rejected-trial atomicity and
restart. Actual competing-sink exhaustion and automatic snow/pond N remain open.
No global historical B1 tag, full NUT closure or master promotion is implied.
