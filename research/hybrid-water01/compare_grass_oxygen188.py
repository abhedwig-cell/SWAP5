"""Run both oxygen kernels on shared accepted day-188 states and B0 forcing."""
import argparse
import json
import math
from pathlib import Path
import re
import shutil

from audit_grass_oxygen188 import records, NODE_COUNT
from replay_grass_oxygen188 import (
    ROOT, INPUTS, LEGACY_USE, LEGACY_BEFORE, LEGACY_AFTER, execute, inject, link, sha,
)

HERE = Path(__file__).resolve().parent
WINDOW_START = 187 + 38.4/1440


def native_objects(bundle):
    build = json.loads((bundle/"BUILD.json").read_text())
    assert sha(bundle/build["executable"]) == build["executable_sha256"]
    sources = {Path(p).stem.lower(): Path(p) for p in build["source_sha256"]}
    objects = dict(zip(sources, map(Path, build["object_sha256"]), strict=True))
    todo = ["mod_bartholomeus_factor_provider"]
    selected = {}
    while todo:
        name = todo.pop()
        if name in selected:
            continue
        source, obj = sources[name], objects[name]
        assert sha(source) == build["source_sha256"][str(source)]
        assert sha(obj) == build["object_sha256"][str(obj)]
        selected[name] = obj
        uses = re.findall(r"(?im)^\s*use\s+(\w+)", source.read_text())
        todo.extend(m.lower() for m in uses if m.lower() in sources)
    return sorted(selected.values()), build


def summarize(out, native_rows, original_day_gap):
    tags = {}
    for line in (out/"stdout").read_text(errors="replace").splitlines():
        fields = line.split()
        if fields and fields[0].startswith(("PAIR_", "LEGACY_")):
            tags.setdefault(fields[0], []).append(list(map(float, fields[1:])))
    forcing, = tags["PAIR_FORCING"]
    n = int(forcing[0])
    b0 = {}
    for row, state in zip(tags["LEGACY_ROOT"], tags["LEGACY_NODES"], strict=True):
        time, dt, _, _, drought, oxygen, _, deepest = row
        assert drought == 0
        b0[time-29220] = (dt, oxygen, deepest, state[3*NODE_COUNT:3*NODE_COUNT+n])
    assert len(b0) == len(tags["LEGACY_ROOT"])
    weights = next(iter(b0.values()))[3]
    assert all(sample[3] == weights for sample in b0.values())
    native = {row[0]: row for row in native_rows if row[1] > WINDOW_START}
    assert [row[0] for row in tags["PAIR_NATIVE"]] == list(native)
    assert [row[0] for row in tags["PAIR_B0"]] == [t for t in b0 if t >= WINDOW_START-1e-8]

    result = {}
    for grid in ("B0", "NATIVE"):
        pairs = tags["PAIR_"+grid]
        assert all(len(row) == 1+2*n and all(0 <= f <= 1 for f in row[1:]) for row in pairs)
        onset = [next(row[0] for row in pairs if min(row[offset:offset+n]) < 1) for offset in (1, 1+n)]
        worst = max((abs(a-b), row[0], i, a, b)
                    for row in pairs
                    for i, (a, b) in enumerate(zip(row[1:1+n], row[1+n:]), 1))
        integrals = [[], []]
        for row in pairs:
            clock = row[0]
            dt = b0[clock][0] if grid == "B0" else native[clock][1]-max(clock, WINDOW_START)
            rates = [math.fsum(w*(1-f) for w, f in zip(weights, row[offset:offset+n]))
                     for offset in (1, 1+n)]
            if grid == "B0":
                assert row[n] == b0[clock][2]
                assert abs(rates[0]-b0[clock][1]) <= 1e-10
            for integral, rate in zip(integrals, rates):
                integral.append(dt*rate)
        b0_cm, native_cm = map(math.fsum, integrals)
        result[grid] = {
            "intervals": len(pairs),
            "first_reduction_minute": {k: (t-187)*1440 for k, t in zip(("B0_kernel", "SWAP5_kernel"), onset)},
            "worst_nodal_factor_gap": {
                "absolute": worst[0], "minute": (worst[1]-187)*1440, "node": worst[2],
                "B0_kernel": worst[3], "SWAP5_kernel": worst[4],
            },
            "oxygen_loss_with_B0_nodal_demand_cm": {"B0_kernel": b0_cm, "SWAP5_kernel": native_cm},
            "oxygen_loss_delta_cm": native_cm-b0_cm,
            "fraction_of_original_absolute_day_gap": abs((native_cm-b0_cm)/original_day_gap),
        }

    actual = next(row for row in native_rows if row[5] > 0)
    same_state = next(row for row in tags["PAIR_NATIVE"] if row[0] == actual[0])
    result["native_actual_onset"] = {
        "minute": (actual[0]-187)*1440,
        "actual_deepest_factor": actual[-1],
        "B0_forcing_B0_kernel_deepest_factor": same_state[n],
        "B0_forcing_SWAP5_kernel_deepest_factor": same_state[-1],
    }
    return {"rooted_nodes": n, "B0_forcing": {
        "root_maintenance": forcing[1], "senescence": forcing[2], "maximum_respiration_factor": forcing[3],
        "air_temperature_c": forcing[4], "specific_root_length": forcing[5], "root_density_kg_m3": forcing[6:],
    }, "comparison": result}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("reference", "bundle", "observation", "output"):
        parser.add_argument("--"+name, type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir()
    ref = args.reference.resolve()/"build"
    previous = json.loads((HERE/"grass-oxygen188-evidence.json").read_text())
    original_trace = args.observation/"native/stdout"
    assert sha(original_trace) == previous["build"]["native"]["stdout_sha256"]
    rows, states, _ = records(original_trace, "native")
    with (out/"native_states.txt").open("w") as f:
        for r, state in zip(rows, states):
            if r[1] > WINDOW_START:
                print(r[0], *state[:3*NODE_COUNT], file=f)

    original = ref/"swap-selected/swap.f90"
    assert sha(original) == previous["build"]["legacy"]["original_source_sha256"]
    text = original.read_text(encoding="cp1252")
    pos = text.index("subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap) ")
    body = inject(text[pos:], "use swap_exchange\n", LEGACY_USE)
    body = inject(body, "logical :: flError\n", "real(8)::obs_start_h(113),obs_start_theta(113),obs_start_temp(113)\n")
    body = inject(body, "      if (swcrop == 1) call RootExtraction(2)", LEGACY_BEFORE, before=True)
    observe = LEGACY_AFTER.replace(
        "         if(abs(obs_clock+dt-29408d0)<1d-8)stop 73",
        """         if(obs_clock>=29407d0+38.4d0/1440d0-1d-8) &
            call oxygen188_pair('B0', obs_clock-29220d0, obs_start_h, obs_start_theta, obs_start_temp, obs_deep)
         if(abs(obs_clock+dt-29408d0)<1d-8)then
            call oxygen188_native_states()
            stop 73
         end if""",
    )
    body = inject(body, "      call integral(3)", observe)
    source = out/"swap.f90"
    pair = HERE/"grass_oxygen188_pair.f90"
    source.write_text(text[:pos]+body+"\n"+pair.read_text(), encoding="cp1252")
    obj, tt = ref/"swap-obj", ref/"ttutil-obj"
    native, build = native_objects(args.bundle.resolve())
    assert build["executable_sha256"] == previous["build"]["native"]["predecessor_exe_sha256"]
    exe, commands = link(out, source, [
        "-O2", "-cpp", "-Dlinux", "-finit-local-zero", "-ffree-line-length-none",
        "-fallow-argument-mismatch", "-I", str(obj), "-I", str(tt), "-I", str(args.bundle.resolve()),
    ], [*sorted(obj.glob("*.o")), *native], obj/"swap.o", tt/"libttutil.a")
    for name in INPUTS:
        shutil.copyfile(ROOT/"reference/swap-4.3.1/projects/2.grassgrowth"/name, out/name)
        assert sha(out/name) == previous["build"]["legacy"]["inputs_sha256"][name]
    execute(exe, out, ["./swap.swp"], 73)
    legacy = args.observation/"legacy/stdout"
    assert sha(legacy) == previous["build"]["legacy"]["stdout_sha256"]
    prefixes = ("LEGACY_ROOT ", "LEGACY_NODES ")
    for prefix in prefixes:
        assert [s for s in (out/"stdout").read_bytes().splitlines() if s.startswith(prefix.encode())] == [
            s for s in legacy.read_bytes().splitlines() if s.startswith(prefix.encode())
        ]
    original_day_gap = previous["native"]["integral_cm"]["oxygen_cm"]-previous["legacy"]["integral_cm"]["oxygen_cm"]
    receipt = {
        "day": 188,
        "window_start_minute": 38.4,
        "original_oxygen_gap_cm": original_day_gap,
        **summarize(out, rows, original_day_gap),
        "legacy_accepted_trace_exact": True,
        "legacy_oxygen_object_sha256": sha(obj/"oxygenstress.o"),
        "native_objects_sha256": {p.name: sha(p) for p in native},
        "observer_executable_sha256": sha(exe),
        "observer_source_sha256": sha(source),
        "stdout_sha256": sha(out/"stdout"),
        "native_states_sha256": sha(out/"native_states.txt"),
    }
    (out/"RESULT.json").write_text(json.dumps({**receipt, "commands": commands}, indent=2)+"\n")
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
