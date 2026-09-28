#!/usr/bin/env python3
import json
from pathlib import Path

registry=json.loads(Path("docs/performance/F-PE-TIMEARCH03_EVENT_REGISTRY.json").read_text())
patterns={
"CALENDAR_DAY_END":("src/legacy/b1_10_fci11_port/timecontrol_part05.inc","dtEventEOD = 1.0d0 - tcum"),
"OUTPUT_TIME":("src/legacy/b1_10_fci11_port/timecontrol_part05.inc","dtEventPrint = 1.0d0/dble(nprintday)"),
"EXTERNAL_INTERVAL_END":("src/legacy/b1_10_fci11_port/timecontrol_part05.inc","get_dtEvent = min(get_dtEvent, intervalRemaining)"),
"DETAILED_METEO":("src/legacy/b1_10_fci11_port/timecontrol_part06.inc","get_dtEvent = min(get_dtEvent, dtEventRain)"),
"RAIN_EVENT":("src/legacy/b1_10_fci11_port/timecontrol_part06.inc","dtEventRain = raintim(rain_rec) - t1900"),
"SSDI_EVENT":("src/legacy/b1_10_fci11_port/timecontrol_part06.inc","get_dtEvent = min(get_dtEvent, dtEventSSDI)"),
"RUNON_EVENT":("src/legacy/b1_10_fci11_port/timecontrol_part06.inc","get_dtEvent = min(get_dtEvent, dtEventRunon)"),
"INTERCEPTION_EVENT":("src/legacy/b1_10_fci11_port/timecontrol_part05.inc","dt = min(dt, dt_interc_event)"),
"IRRIGATION_EVENT":("src/legacy/b1_10_fci11_port/timecontrol_part05.inc","dt = min(dt, dt_irr_event)"),
"MACROPORE_RECOVERY":("src/legacy/b1_10_fci11_port/timecontrol_part05.inc","dt = dsqrt(dtmin*dtmax)"),
"SOLVER_FAILURE_RECOVERY":("src/legacy/b1_10_fci11_port/timecontrol_part05.inc","dt = dt / fact_dt_fldect"),
"DAYSTART_COMPATIBILITY":("src/legacy/b1_10_fci11_port/timecontrol_part03.inc","dt = max(dt, dsqrt(dtmin*dtmax))"),
"INITIAL_OUTPUT_DTMAX_MUTATION":("src/legacy/b1_10_fci11_port/timecontrol_part02.inc","dtmax = min(dtmax, 1.0d0/dble(nprintday))"),
"INITIAL_METEO_DTMAX_MUTATION":("src/legacy/b1_10_fci11_port/timecontrol_part02.inc","if (swmetdetail == 1) dtmax = min(dtmax, dt_meteo)"),
"INITIAL_DTMIN_MUTATION":("src/legacy/b1_10_fci11_port/timecontrol_part02.inc","dtmin = min(dtmin, 0.1d0*dtmax)"),
"ACCEPTED_STEP_ITERATION_ADAPTATION":("src/legacy/b1_10_fci11_port/timecontrol_part04.inc","if (numbit <= numbit_crit) dt = min(dt*fact_dt_increase,dtMax)")
}
ids=[x["id"] for x in registry["entries"]]
if set(ids)!=set(patterns):
    raise SystemExit("TIMEARCH03 registry/pattern mismatch")
for key,(path,needle) in patterns.items():
    text=Path(path).read_text()
    if needle not in text:
        raise SystemExit(f"TIMEARCH03 missing source pattern {key}: {needle}")
print(f"F_PE_TIMEARCH03_EVENT_REGISTRY_COUNT={len(ids)}")
print("F_PE_TIMEARCH03_EVENT_REGISTRY_GUARD=PASS")
