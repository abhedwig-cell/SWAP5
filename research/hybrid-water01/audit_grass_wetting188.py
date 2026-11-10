"""Audit rainfall and accepted hydraulic fluxes at the Grassgrowth wet transition."""
import argparse
import json
import math
from pathlib import Path

import replay_grass_oxygen188 as replay
from audit_grass_oxygen188 import records, NODE_COUNT

HERE = Path(__file__).resolve().parent
MINUTES = (0, 38.4, 68.3, 76.8, 144, 1440)


def observe(out, args):
    replay.NATIVE = replay.NATIVE.replace(
        "     if(day_index==188)then",
        """     if(day_index==188)then
      write(*,'(a,*(1x,es25.17e3))') 'WET',q%t0,q%t1,segment_rain_rate, &
       interception%net_rain_cm_per_day,q%top_flux,q%bottom_flux,q%pond_end_cm""",
    )
    replay.LEGACY_USE += """
use MOD_meteo,only:obs_rain=>graidt,obs_net_rain=>nraidt
use variables,only:obs_top=>qtop,obs_bottom=>qbot,obs_pond=>pond
"""
    replay.LEGACY_AFTER = replay.LEGACY_AFTER.replace(
        "         if(abs(obs_clock+dt-29408d0)<1d-8)stop 73",
        """         write(*,'(a,*(1x,es25.17e3))') 'WET',obs_clock-29220d0,obs_clock-29220d0+dt, &
            obs_rain,obs_net_rain,obs_top,obs_bottom,obs_pond
         if(abs(obs_clock+dt-29408d0)<1d-8)stop 73""",
    )
    return {
        "legacy": replay.legacy(args.reference.resolve()/"build", out/"legacy"),
        "native": replay.native(args.bundle.resolve(), args.control.resolve(), args.archive.resolve(), out/"native"),
    }


def sample(log, model):
    rows, states, _ = records(log, model)
    wet = [list(map(float, line.split()[1:])) for line in log.read_text(errors="replace").splitlines()
           if line.startswith("WET ")]
    assert [(r[0], r[1]) for r in wet] == [(r[0], r[1]) for r in rows]
    result = {}
    for minute in MINUTES:
        end = 187+minute/1440
        valid = [i for i, row in enumerate(rows) if row[0] <= end+1e-9]
        j = valid[-1]
        cumulative = [math.fsum(max(0, min(end, r[1])-r[0])*r[k] for r in wet) for k in range(2, 6)]
        snap = {
            "gross_rain_cm": cumulative[0], "net_rain_cm": cumulative[1],
            "downward_top_flux_cm": -cumulative[2], "upward_bottom_flux_cm": cumulative[3],
        }
        if minute < 1440:
            snap.update({
                "state_start_minute": (rows[j][0]-187)*1440,
                "state_interval_minutes": (rows[j][1]-rows[j][0])*1440,
                "head_cm_by_node": {str(i): states[j][i-1] for i in (1, 6, 22, 30)},
                "theta_by_node": {str(i): states[j][NODE_COUNT+i-1] for i in (1, 6, 22, 30)},
                "root_zone_water_cm": math.fsum(states[j][NODE_COUNT:NODE_COUNT+30]),
                "top_flux_cm_day": wet[j][4], "pond_end_cm": wet[j][6],
            })
        result[str(minute)] = snap
    return {
        "samples": result,
        "interval_count": len(rows),
        "oxygen_loss_cm": math.fsum((r[1]-r[0])*r[5] for r in rows),
        "first_oxygen_minute": (next(r[0] for r in rows if r[5] > 0)-187)*1440,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ("reference", "bundle", "control", "archive", "baseline", "output"):
        parser.add_argument("--"+key, type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir()
    provenance = observe(out, args)
    previous = json.loads((HERE/"grass-oxygen188-evidence.json").read_text())
    data = {}
    for model in ("legacy", "native"):
        log = out/model/"stdout"
        old = args.baseline/model/"stdout"
        assert replay.sha(old) == previous["build"][model]["stdout_sha256"]
        prefixes = tuple(tag.encode() for tag in
                         (("LEGACY_ROOT ", "LEGACY_NODES ") if model == "legacy" else
                          ("NATIVE_ROOT ", "NATIVE_NODES ", "NATIVE_HEAD ")))
        assert [line for line in log.read_bytes().splitlines() if line.startswith(prefixes)] == [
            line for line in old.read_bytes().splitlines() if line.startswith(prefixes)
        ]
        data[model] = sample(log, model)
        provenance[model]["stdout_sha256"] = replay.sha(log)
        del provenance[model]["commands"]
    # Cap B0 only after the original day-187 endpoint, before evaluating the
    # first day-188 root/hydraulic step. Keep all convergence settings intact.
    replay.LEGACY_USE += "use variables,only:obs_dtmax=>dtmax\n"
    replay.LEGACY_BEFORE = replay.LEGACY_BEFORE.replace(
        "         obs_start_h=",
        "         obs_dtmax=min(obs_dtmax,0.5d0/1440d0)\n         dt=min(dt,obs_dtmax)\n         obs_start_h=",
    )
    capped = out/"legacy_cap"
    cap = replay.legacy(args.reference.resolve()/"build", capped)
    old = records(out/"legacy/stdout", "legacy")
    new = records(capped/"stdout", "legacy")
    assert old[1][0][:3*NODE_COUNT] == new[1][0][:3*NODE_COUNT]
    assert max(r[1]-r[0] for r in new[0])*1440 <= 0.5+1e-8
    data["legacy_cap"] = sample(capped/"stdout", "legacy")
    cap["stdout_sha256"] = replay.sha(capped/"stdout")
    del cap["commands"]
    provenance["legacy_cap"] = cap
    result = {
        "day": 188, "accepted_control_traces_identical": True,
        "legacy_cap_minutes": 0.5, "legacy_cap_initial_nodal_state_exact": True,
        "provenance": provenance, "runs": data,
    }
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
