# MC-CROP01 current-window day-end production contract

Status: implemented, qualified and preserved; admission pending, 2026-10-11. Baseline
canonical `1e689fd2c31bac468df01540b314ea128be4554a`; PR1207 remains the
admitted morning-delivery profile until successor admission.

Authenticated B1.11 `SWAP/swap.f90`, SHA256
`39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a`,
lines491/511/514/521/535, orders accepted hydrology, growth, harvest,
integral/output, then reset. Source archive and identities are already owned
by `MC_CROP01_ROOTED_WEATHER_PRODUCTION_STATUS.json`; no new source claim.

The next dependency-ordered production block introduces explicit
`file_weather_dayend` opt-in on the existing rooted application. Only an
already emerged annual crop may complete its current accepted daily window.
The existing F-WOF38/F-KT transaction consumes the opaque current window,
its actual root uptake and its own stored immutable weather record. Ordinary
positive `[day,day+1]` crop transactions remain unchanged. No future weather,
new state owner, hydrological replay, synthetic accepted receipt, reset time
or zero-duration kernel operation is allowed.

After acceptance the existing window is retired exactly once. The next real
morning still authenticates the next source record against the accepted soil
and opens a new hydrological window, but does not repeat completed growth.
An incomplete/unaccepted previous growth day must be completed before the
next meteorological day can replace its record. Pre-emergence and delayed
emergence retain their admitted source task2/task3/previous-flag order.

Joint continuation must cover both pending current-day completion and
accepted end-completed phase. Phase is derived from committed crop time,
accepted soil time and opaque window delivery, not caller assertions or an
independent phase owner. Rejected candidate parameters, duplicate calls,
unready windows and foreign crop authority cannot change committed state.

Owned surface: existing application bootstrap and its opaque joint bundle;
integration regression and exact successor guards. Held fixed: crop physics,
root/heat/hydraulic arithmetic, F-KT executor/time/commit contract, mass and
temporal tolerances, source archive and historical admitted profiles.
Admission owner: MC-CROP01 central application authority under the delegated
workstream; no transfer of independent MC-IRR01 or other owner semantics.

Affected invariants:3/4/7/9/13/21/29/30. Qualification must preserve the old
seven-day morning production trajectory and prove five same-day growth
completions including the last real meteorological day, next-morning
idempotency, exact owner oracles, partial/pending/completed restart, retry,
rollback, soil immutability and full O0/O2 owner/hydrology postimages. Run
affected crop/PPA/cross-owner and full F-CI gates plus complete highest frost
compile-closure preservation on the exact successor before admission.

Harvest/output/reset, calendar/fallow/new-season authority and external disk
restart remain subsequent boundaries; this block cannot close MC-CROP01.
