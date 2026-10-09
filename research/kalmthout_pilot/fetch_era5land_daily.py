#!/usr/bin/env python3
import csv, json, math, sys, urllib.parse, urllib.request
from datetime import date
from pathlib import Path

DOMAIN=json.loads((Path(__file__).resolve().parent/"domain.json").read_text())
LAT=float(DOMAIN["representative_cell"]["latitude"])
LON=float(DOMAIN["representative_cell"]["longitude"])
ELEVATION_M=25.0
START="2024-01-01"
END="2026-10-01"
WET_THRESHOLD_MM_H=0.05

params={
    "latitude":LAT,"longitude":LON,
    "start_date":START,"end_date":END,
    "hourly":"temperature_2m,dew_point_2m,precipitation,shortwave_radiation,wind_speed_10m",
    "models":"era5","timezone":"UTC","wind_speed_unit":"ms"
}
url="https://archive-api.open-meteo.com/v1/archive?"+urllib.parse.urlencode(params)
print("KALMTHOUT_METEO_SOURCE_URL",url,file=sys.stderr)
with urllib.request.urlopen(url, timeout=120) as r:
    payload=json.load(r)
h=payload.get("hourly",{})
required=["time","temperature_2m","dew_point_2m","precipitation","shortwave_radiation","wind_speed_10m"]
for k in required:
    if k not in h:
        raise SystemExit(f"missing hourly field {k}: {payload}")
n=len(h["time"])
if any(len(h[k])!=n for k in required):
    raise SystemExit("hourly arrays have inconsistent lengths")

def sat_vp_kpa(t):
    return 0.6108*math.exp(17.27*t/(t+237.3))

def ra_mj_m2_day(day_of_year, lat_deg):
    phi=math.radians(lat_deg)
    dr=1+0.033*math.cos(2*math.pi*day_of_year/365)
    delta=0.409*math.sin(2*math.pi*day_of_year/365-1.39)
    x=-math.tan(phi)*math.tan(delta)
    x=max(-1,min(1,x))
    ws=math.acos(x)
    return (24*60/math.pi)*0.0820*dr*(ws*math.sin(phi)*math.sin(delta)+math.cos(phi)*math.cos(delta)*math.sin(ws))

def fao56_et0(tmin,tmax,tmean,ea,rs,u2,doy):
    es=(sat_vp_kpa(tmin)+sat_vp_kpa(tmax))/2
    delta=4098*sat_vp_kpa(tmean)/((tmean+237.3)**2)
    p=101.3*((293-0.0065*ELEVATION_M)/293)**5.26
    gamma=0.000665*p
    ra=ra_mj_m2_day(doy,LAT)
    rso=(0.75+2e-5*ELEVATION_M)*ra
    rns=(1-0.23)*rs
    sigma=4.903e-9
    rs_rso=min(1.0,rs/rso) if rso>0 else 0.0
    rnl=sigma*(((tmax+273.16)**4+(tmin+273.16)**4)/2)*(0.34-0.14*math.sqrt(max(ea,0)))*(1.35*rs_rso-0.35)
    rn=rns-rnl
    num=0.408*delta*rn + gamma*(900/(tmean+273))*u2*max(es-ea,0)
    den=delta + gamma*(1+0.34*u2)
    return max(0.0,num/den) if den>0 else 0.0

days={}
for i,tstamp in enumerate(h["time"]):
    d=tstamp[:10]
    vals={k:h[k][i] for k in required if k!="time"}
    if any(v is None for v in vals.values()):
        continue
    days.setdefault(d,[]).append(vals)

expected=(date.fromisoformat(END)-date.fromisoformat(START)).days+1
if len(days)!=expected:
    missing=[]
    cur=date.fromisoformat(START)
    for j in range(expected):
        ds=date.fromordinal(cur.toordinal()+j).isoformat()
        if ds not in days or len(days[ds])!=24:
            missing.append((ds,len(days.get(ds,[]))))
    raise SystemExit(f"incomplete ERA5 period: expected {expected} complete days, got {len(days)}; first missing={missing[:10]}")

# Derive daily ET0, but preserve ERA5 precipitation at its native hourly
# resolution for the SWAP atmospheric boundary. ET0 is a daily rate and is
# therefore repeated as a rate for each hourly forcing interval.
daily_et0={}
for ds,rows in days.items():
    temp=[r["temperature_2m"] for r in rows]
    dew=[r["dew_point_2m"] for r in rows]
    sw=[max(0.0,r["shortwave_radiation"]) for r in rows]
    w10=[max(0.0,r["wind_speed_10m"]) for r in rows]
    tmin=min(temp); tmax=max(temp); tmean=sum(temp)/24
    ea=sum(sat_vp_kpa(v) for v in dew)/24
    rad=sum(sw)*0.0036
    factor=4.87/math.log(67.8*10.0-5.42)
    u2=(sum(w10)/24)*factor
    doy=date.fromisoformat(ds).timetuple().tm_yday
    daily_et0[ds]=fao56_et0(tmin,tmax,tmean,ea,rad,u2,doy)

writer=csv.writer(sys.stdout)
writer.writerow(["time","precip_mm_hour","temp_c","dew_c","shortwave_mj_m2_hour","wind10_m_s","et0_mm_day"])
for ds in sorted(days):
    for hour,row in enumerate(days[ds]):
        tstamp=f"{ds}T{hour:02d}:00"
        precip=max(0.0,row["precipitation"])
        rad=max(0.0,row["shortwave_radiation"])*0.0036
        writer.writerow([tstamp,f"{precip:.6f}",f"{row['temperature_2m']:.6f}",
                         f"{row['dew_point_2m']:.6f}",f"{rad:.6f}",
                         f"{max(0.0,row['wind_speed_10m']):.6f}",f"{daily_et0[ds]:.6f}"])
