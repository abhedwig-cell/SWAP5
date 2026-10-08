# F-PE-ELASTIC72B — public-access reconnaissance

Date: 2026-09-30

Status: RAW_DATA_ACCESS_REQUIRED

## Public access findings

The current VU NOBV landing zone exposes:
- Grafana;
- Change Requests;
- Research Drive;
- Remote Desktop services.

Grafana redirects to an authenticated login.

Historic NOBV data-management documentation describes:
- Level0 raw sensor data;
- Level1 harmonized naming/time-zone data;
- direct PostgreSQL access by username/password after approval;
- Grafana as the more accessible indirect visualization route.

Therefore no unrestricted public raw download/API has been identified for the
extensometer series required by ELASTIC72B.

## Published Zegveld geometry

Public NOBV reporting identifies a particularly useful saturated peat interval
in Zegveld parcel 16:

Reference parcel:
- approximately 1.20 to 4.49 m below surface.

Pressure-drain parcel:
- approximately 1.21 to 4.71 m below surface.

The 2020-2021 NOBV report states that a large part of the observed seasonal
vertical motion is caused by deformation of these saturated peat intervals and
that the movement is strongly related to groundwater dynamics.

The 2025 HESS paper further establishes that:
- Zegveld contains about 6 m of peat;
- hourly extensometer observations exist;
- every extensometer has multiple anchor levels relative to a stable deep
  reference anchor;
- local high-resolution phreatic groundwater observations are available;
- deformation below approximately 0.80 m is largely reversible during the
  studied period;
- raw data are stored at Deltares/NOBV and can be requested.

## Preferred first target

Primary target:
Zegveld parcel 16 reference extensometer.

Reason:
- thick peat sequence;
- large reversible saturated-layer signal;
- published direct attribution to the ~1.20-4.49 m saturated peat interval;
- low risk that the target signal is dominated by the unsaturated topsoil when
  differential anchors are used.

Secondary target:
Zegveld parcel 16 pressure-drain extensometer, ~1.21-4.71 m interval.

These two paired plots allow a useful first internal replication without
requiring cross-site lithological equivalence.

## Required access route

Preferred:
raw or minimally processed timestamped export supplied by Deltares/NOBV.

Acceptable:
authorized NOBV Grafana/database export, provided the export retains:
- all anchor levels;
- groundwater timestamps;
- units/sign conventions;
- quality flags;
- exact anchor depths;
- no irreversible smoothing that removes subdaily/daily response.

Not sufficient:
- plots digitized from publications;
- annual minima/maxima only;
- daily values without provenance when hourly data exist;
- surface and 0.8 m anchors only if the deeper peat-bounding anchors are omitted.

## Conclusion

The ELASTIC72B blocker is access, not source existence.

Classification:
`NOBV_RAW_DATA_ACCESS_REQUIRED`.

No further GitHub Action is justified until raw data are obtained.
