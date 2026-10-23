# Exactly one stationary organic receiving pool

Implementation candidate. Admission is established only by ADMISSION.json.
At exactly one of kB,kH zero, use the original linear FOM/B/H equations:
dFi=-ki Fi; dB=sum(ai ki Fi)-(1-a)kB B+a kH H;
dH=sum(bi ki Fi)+b kB B-(1-b)kH H.
The endpoints and interval averages are exp(A dt)x0 and
integral(exp(A t),0,dt)x0/dt. These exist at zero and coincident rates.

Evaluate both matrix functions with a scaled Taylor series (column norm at
most0.125,32 terms), then double the interval by the exact composition
T(2h)=T(h)^2, M(2h)=(M(h)+T(h)M(h))/2. This changes no process equation,
time interval, partition, physical tolerance or accept/commit policy.
Both-zero and positive receiving-rate production paths remain byte exact.
No new persistent state or restart schema. The helper rejects invalid parameters
and is restricted to exactly one zero receiving rate.

Owner: MC-NUT01 organic turnover/dissimilation. Affected invariants:
3,7,13,21,23,25,26,30. C/N balance, active crop uptake, organic immobilisation,
whole-state rollback and native process restart require actual composition proof.
Selected mineral exhaustion, automatic snow/persistent-surface N and general
full historical migration remain open. No whole-row/master promotion.
