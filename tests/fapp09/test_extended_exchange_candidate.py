from __future__ import annotations
import math
import os
import pathlib
import random
import subprocess
import tempfile
from dataclasses import dataclass

SEED = 2026092321
POND_SWITCH = -0.1
EPS = 0.001

@dataclass
class P:
    z: float = -100.0
    kind: int = 1
    width: float = 50.0
    talud: float = 2.0
    spacing: float = 1000.0
    rdrain: float = 10.0
    rinfi: float = 20.0
    rentry: float = 0.5
    rexit: float = 0.7
    gwlinf: float = -200.0
    highest: bool = False
    mode: int = 0
    rsdeep: float = 10.0
    rsshallow: float = 2.0
    coef: float = 0.5
    exponent: float = 0.7
    pondmx: float = 1000.0

def oracle(p, gwl, wl, pond):
    if not (wl < p.pondmx or gwl < p.pondmx):
        boundary = wl == p.pondmx or gwl == p.pondmx
        return dict(status=0, branch=1, q=0.0, drain=0.0, eff=0.0, deriv=not boundary,
                    dg=0.0, dw=0.0, dp=0.0, cap=0, sign=0, surf=0, power=0)
    threshold = p.z + EPS
    if not (gwl > threshold or wl > threshold):
        boundary = gwl == threshold or wl == threshold
        return dict(status=0, branch=2, q=0.0, drain=0.0, eff=0.0, deriv=not boundary,
                    dg=0.0, dw=0.0, dp=0.0, cap=0, sign=0, surf=0, power=0)
    control_boundary = wl == threshold
    if wl <= threshold:
        drain = p.z
        dlevel = 0.0
        wet = p.width
        dwet = 0.0
    else:
        drain = wl
        dlevel = 1.0
        if p.kind == 2:
            depth = wl - p.z
            root = math.sqrt(depth * depth + (depth / p.talud) ** 2)
            wet = p.width + 2.0 * root
            dwet = 2.0 * depth * (1.0 + 1.0 / p.talud**2) / root
        else:
            wet = 0.0
            dwet = 0.0
    raw = gwl - drain
    pond_boundary = gwl == POND_SWITCH
    if gwl > POND_SWITCH:
        raw += pond
    eff = raw
    de = [1.0, -dlevel, 1.0 if gwl > POND_SWITCH else 0.0]
    cap = raw < 0.0 and gwl < p.gwlinf
    if cap:
        eff = p.gwlinf - drain
        de = [0.0, -dlevel, 0.0]
    branch = 5 if cap else None
    boundary = pond_boundary or control_boundary or (raw < 0.0 and gwl == p.gwlinf)
    if p.highest and p.mode == 2:
        if eff < 0.0:
            return dict(status=4, branch=0, q=0.0, drain=drain, eff=eff, deriv=False,
                        dg=0.0, dw=0.0, dp=0.0, cap=int(cap), sign=0, surf=0, power=0)
        power_boundary = eff == 0.0
        q = p.coef * eff**p.exponent
        if power_boundary:
            return dict(status=0, branch=6, q=q, drain=drain, eff=eff, deriv=False,
                        dg=0.0, dw=0.0, dp=0.0, cap=int(cap), sign=0, surf=0, power=1)
        factor = p.coef * p.exponent * eff ** (p.exponent - 1.0)
        return dict(status=0, branch=6, q=q, drain=drain, eff=eff, deriv=not boundary,
                    dg=factor * de[0], dw=factor * de[1], dp=factor * de[2],
                    cap=int(cap), sign=0, surf=0, power=0)
    surface_boundary = False
    if eff > 0.0:
        branch = 3
        rd = p.rdrain
        re = p.rentry
        drde = 0.0
        if p.highest and p.mode == 1:
            unconstrained = p.rsdeep - eff
            surface_boundary = unconstrained == p.rsshallow
            if unconstrained > p.rsshallow:
                rd = unconstrained
                drde = -1.0
            else:
                rd = p.rsshallow
    else:
        if branch is None:
            branch = 4
        rd = p.rinfi
        re = p.rexit
        drde = 0.0
    sign_boundary = eff == 0.0 if eff <= 0.0 else False
    denominator = rd + (re * p.spacing / wet if p.kind == 2 else 0.0)
    q = eff / denominator
    boundary = boundary or sign_boundary or surface_boundary
    if boundary:
        return dict(status=0, branch=branch, q=q, drain=drain, eff=eff, deriv=False,
                    dg=0.0, dw=0.0, dp=0.0, cap=int(cap), sign=int(sign_boundary),
                    surf=int(surface_boundary), power=0)
    dd = [drde * de[0], drde * de[1], drde * de[2]]
    if p.kind == 2:
        dd[1] += -re * p.spacing * dwet / (wet * wet)
    deriv = [(de[i] * denominator - eff * dd[i]) / denominator**2 for i in range(3)]
    return dict(status=0, branch=branch, q=q, drain=drain, eff=eff, deriv=True,
                dg=deriv[0], dw=deriv[1], dp=deriv[2], cap=int(cap),
                sign=int(sign_boundary), surf=int(surface_boundary), power=0)

def row(p, gwl, wl, pond):
    return [p.z, p.kind, p.width, p.talud, p.spacing, p.rdrain, p.rinfi, p.rentry,
            p.rexit, p.gwlinf, int(p.highest), p.mode, p.rsdeep, p.rsshallow, p.coef,
            p.exponent, p.pondmx, gwl, wl, pond]

def cases():
    rng = random.Random(SEED)
    out = []
    for i in range(800):
        z = -rng.uniform(30.0, 300.0)
        kind = 1 if i % 2 == 0 else 2
        p = P(z=z, kind=kind, width=rng.uniform(0.1, 200.0), talud=rng.uniform(0.1, 5.0),
              spacing=rng.uniform(100.0, 10000.0), rdrain=rng.uniform(2.0, 100.0),
              rinfi=rng.uniform(2.0, 100.0), rentry=rng.uniform(0.0, 5.0),
              rexit=rng.uniform(0.0, 5.0), gwlinf=z - rng.uniform(20.0, 200.0))
        wl = z + rng.uniform(5.0, 80.0)
        if i % 4 < 2:
            gwl = wl + rng.uniform(2.0, 50.0)
        else:
            gwl = max(p.gwlinf + rng.uniform(2.0, 10.0), wl - rng.uniform(2.0, 20.0))
            if gwl >= wl:
                gwl = wl - rng.uniform(2.0, 10.0)
        if gwl > -1.0:
            gwl = -1.0
        out.append((p, gwl, wl, 0.0))
    for i in range(200):
        z = -rng.uniform(30.0, 200.0)
        gwlinf = z - rng.uniform(20.0, 100.0)
        wl = z + rng.uniform(5.0, 40.0)
        gwl = gwlinf - rng.uniform(5.0, 30.0)
        p = P(z=z, kind=1 if i % 2 == 0 else 2, gwlinf=gwlinf,
              width=rng.uniform(1.0, 100.0), talud=rng.uniform(0.2, 4.0),
              spacing=rng.uniform(100.0, 5000.0), rinfi=rng.uniform(2.0, 100.0),
              rexit=rng.uniform(0.0, 3.0))
        out.append((p, gwl, wl, 0.0))
    for i in range(200):
        z = -150.0
        wl = -100.0
        gwl = wl + (3.0 if i % 2 == 0 else 12.0)
        p = P(z=z, kind=1 if i % 3 == 0 else 2, width=40.0, talud=2.0,
              spacing=1200.0, rentry=0.4, rdrain=50.0, rinfi=40.0, rexit=0.5,
              gwlinf=-300.0, highest=True, mode=1, rsdeep=10.0, rsshallow=2.0)
        out.append((p, gwl, wl, 0.0))
    for i in range(200):
        z = -150.0
        wl = -100.0
        gwl = wl + rng.uniform(0.5, 30.0)
        p = P(z=z, kind=1 if i % 2 == 0 else 2, gwlinf=-300.0, highest=True, mode=2,
              coef=rng.uniform(0.01, 10.0), exponent=rng.uniform(0.1, 1.0))
        out.append((p, gwl, wl, 0.0))
    for i in range(100):
        p = P(z=-20.0, kind=1 if i % 2 == 0 else 2, width=20.0, talud=1.5,
              spacing=500.0, rdrain=20.0, rentry=0.3, gwlinf=-100.0)
        out.append((p, rng.uniform(0.2, 2.0), -5.0, rng.uniform(0.01, 3.0)))
    out += [
        (P(z=-100.0, highest=True, mode=2, gwlinf=-200.0), -70.0, -50.0, 0.0),
        (P(z=-100.0, rdrain=10.0, gwlinf=-200.0), -0.1, -50.0, 2.0),
        (P(z=-100.0, rdrain=10.0, gwlinf=-200.0), -100.0 + EPS, -110.0, 0.0),
        (P(z=-100.0, rinfi=20.0, gwlinf=-120.0), -120.0, -50.0, 0.0),
        (P(z=-100.0, highest=True, mode=1, rsdeep=10.0, rsshallow=2.0, gwlinf=-200.0), -92.0, -100.0, 0.0),
        (P(z=-100.0, rdrain=10.0, rinfi=20.0, gwlinf=-200.0), -50.0, -50.0, 0.0),
        (P(z=-100.0, rinfi=20.0, gwlinf=-200.0, pondmx=-20.0), -20.0, -10.0, 0.0),
    ]
    return out

def run(executable, population):
    input_text = str(len(population)) + "\n" + "\n".join(
        " ".join(f"{x:.17g}" if isinstance(x, float) else str(x) for x in row(*case))
        for case in population
    ) + "\n"
    proc = subprocess.run([str(executable)], input=input_text, text=True, capture_output=True, check=True)
    lines = proc.stdout.strip().splitlines()
    assert len(lines) == len(population), (len(lines), len(population), proc.stderr)
    parsed = []
    for line in lines:
        x = line.split()
        assert len(x) == 13, (len(x), line)
        parsed.append(dict(status=int(x[0]), branch=int(x[1]), q=float(x[2]), drain=float(x[3]),
                           eff=float(x[4]), deriv=int(x[5]) == 1, dg=float(x[6]), dw=float(x[7]),
                           dp=float(x[8]), cap=int(x[9]), sign=int(x[10]), surf=int(x[11]),
                           power=int(x[12])))
    return parsed, proc.stdout

def check(actual, expected, index):
    for key in ["status", "branch", "deriv", "cap", "sign", "surf", "power"]:
        assert actual[key] == expected[key], (index, key, actual[key], expected[key])
    for key in ["q", "drain", "eff"]:
        assert abs(actual[key] - expected[key]) <= 1e-12 * max(1.0, abs(expected[key])), (
            index, key, actual[key], expected[key])
    if expected["deriv"]:
        for key in ["dg", "dw", "dp"]:
            assert abs(actual[key] - expected[key]) <= 5e-11 * max(1.0, abs(expected[key])), (
                index, key, actual[key], expected[key])

def main():
    root = pathlib.Path(os.environ.get("SWAP5_ROOT", pathlib.Path(__file__).resolve().parents[2])).resolve()
    population = cases()
    outputs = []
    with tempfile.TemporaryDirectory(prefix="sw-rib-q4a-") as tmp:
        tmp = pathlib.Path(tmp)
        for opt in (0, 2):
            moddir = tmp / f"mod_o{opt}"
            moddir.mkdir()
            executable = tmp / f"candidate_o{opt}"
            sources = [
                root / "src/solver/mod_soil_water_solver_contract.f90",
                root / "src/solver/mod_process_hydraulic_view.f90",
                root / "src/process/mod_drainage_extended_exchange.f90",
                root / "tests/fapp09/q4a_extended_exchange_driver.f90",
            ]
            cmd = ["gfortran", "-std=f2008", "-ffree-line-length-none", "-Wall", "-Wextra",
                   "-fcheck=all", "-fbacktrace", "-ffpe-trap=invalid,zero,overflow",
                   f"-O{opt}", "-J", str(moddir), "-I", str(moddir),
                   *[str(x) for x in sources], "-o", str(executable)]
            subprocess.run(cmd, check=True)
            got, raw = run(executable, population)
            outputs.append(raw)
            for index, (case, actual) in enumerate(zip(population, got)):
                check(actual, oracle(*case), index)
            print(f"SW_RIB_SWM01_Q4A_O{opt}_CASES={len(population)}")
    assert outputs[0] == outputs[1]
    print("SW_RIB_SWM01_Q4A_O0_O2_IDENTITY=PASS")
    print("SW_RIB_SWM01_Q4A_SOURCE_BOUND_VALUE_AND_TANGENT=PASS")
    print("SW_RIB_SWM01_Q4A_NEGATIVE_POWER_INTERFLOW_HELD=PASS")
    print("SW_RIB_SWM01_Q4A_EXTENDED_EXCHANGE_CANDIDATE=PASS")

if __name__ == "__main__":
    main()
