#!/usr/bin/env python3
import math
import random
import subprocess
import sys

XGAUSS = (0.1127017, 0.5, 0.8872983)
WGAUSS = (0.2777778, 0.4444444, 0.2777778)
SCV = 0.2


def assim8(a_lnb, a_ref, a_slp, co2amax, tmpf, eff, kn, lai, nlv, kdif, sinb, pardir, pardif):
    refh = (1.0 - math.sqrt(1.0 - SCV)) / (1.0 + math.sqrt(1.0 - SCV))
    refs = refh * 2.0 / (1.0 + 1.6 * sinb)
    kdirbl = (0.5 / sinb) * kdif / (0.8 * math.sqrt(1.0 - SCV))
    kdirt = kdirbl * math.sqrt(1.0 - SCV)
    fgros = 0.0
    for x, w in zip(XGAUSS, WGAUSS):
        laic = lai * x
        if lai >= 0.01:
            sln = nlv * kn * math.exp(-kn * laic) / (1.0 - math.exp(-kn * lai))
        else:
            sln = nlv / lai
        amax = co2amax * tmpf * min(a_ref, max(0.0, a_slp * (sln - a_lnb)))
        visdf = (1.0 - refs) * pardif * kdif * math.exp(-kdif * laic)
        vist = (1.0 - refs) * pardir * kdirt * math.exp(-kdirt * laic)
        visd = (1.0 - SCV) * pardir * kdirbl * math.exp(-kdirbl * laic)
        visshd = visdf + vist - visd
        fgrsh = amax * (1.0 - math.exp(-visshd * eff / max(2.0, amax)))
        vispp = (1.0 - SCV) * pardir / sinb
        if vispp <= 0.0:
            fgrsun = fgrsh
        else:
            fgrsun = amax * (1.0 - (amax - fgrsh) *
                             (1.0 - math.exp(-vispp * eff / max(2.0, amax))) / (eff * vispp))
        fslla = math.exp(-kdirbl * laic)
        fgros += (fslla * fgrsun + (1.0 - fslla) * fgrsh) * w
    return fgros * lai


def totass8(v):
    (a_lnb, a_ref, a_slp, dayl, co2amax, tmpf, eff, kn, lai, nlv,
     kdif, avrad, difpp, dsinbe, sinld, cosld) = v
    dtga = 0.0
    if lai > 0.0 and dayl > 0.0:
        for x, w in zip(XGAUSS, WGAUSS):
            hour = 12.0 + 0.5 * dayl * x
            sinb = max(0.0, sinld + cosld * math.cos(2.0 * math.pi * (hour + 12.0) / 24.0))
            # Cases are generated so all integration points have positive solar height.
            assert sinb > 0.0
            par = 0.5 * avrad * sinb * (1.0 + 0.4 * sinb) / dsinbe
            pardif = min(par, sinb * difpp)
            pardir = par - pardif
            dtga += assim8(a_lnb, a_ref, a_slp, co2amax, tmpf, eff, kn, lai, nlv,
                           kdif, sinb, pardir, pardif) * w
        dtga *= dayl
    return dtga


def cases():
    c = []
    # Explicit WOFOST 8.1 winter-wheat-like and edge cases.
    base = [0.0, 35.83, 3.24, 12.0, 1.0, 1.0, 0.45, 0.4, 4.0, 140.0,
            0.6, 18e6, 120.0, 30000.0, 0.6, 0.4]
    c.append(tuple(base))
    x = base.copy(); x[3] = 0.0; c.append(tuple(x))
    x = base.copy(); x[8] = 0.0; c.append(tuple(x))
    x = base.copy(); x[8] = 0.005; x[9] = 0.02; c.append(tuple(x))
    x = base.copy(); x[9] = 0.0; c.append(tuple(x))
    x = base.copy(); x[9] = 500.0; c.append(tuple(x))

    rng = random.Random(810031)
    for _ in range(1200):
        a_lnb = rng.uniform(0.0, 0.5)
        a_ref = rng.uniform(5.0, 60.0)
        a_slp = rng.uniform(0.5, 8.0)
        dayl = rng.uniform(2.0, 16.0)
        co2amax = rng.uniform(0.7, 1.8)
        tmpf = rng.uniform(0.05, 1.0)
        eff = rng.uniform(0.2, 0.8)
        kn = rng.uniform(0.1, 1.2)
        lai = 10.0 ** rng.uniform(-3.0, math.log10(8.0))
        nlv = rng.uniform(0.0, 350.0)
        kdif = rng.uniform(0.3, 1.0)
        avrad = rng.uniform(2e6, 3e7)
        difpp = rng.uniform(20.0, 300.0)
        dsinbe = rng.uniform(12000.0, 60000.0)
        # Keep SINB positive at all three Gaussian points while still varying geometry.
        cosld = rng.uniform(0.05, 0.35)
        sinld = rng.uniform(cosld + 0.05, 0.9)
        c.append((a_lnb, a_ref, a_slp, dayl, co2amax, tmpf, eff, kn, lai, nlv,
                  kdif, avrad, difpp, dsinbe, sinld, cosld))
    return c


def run(exe, c):
    payload = [str(len(c))]
    payload.extend(" ".join(f"{v:.17g}" for v in row) for row in c)
    cp = subprocess.run([exe], input="\n".join(payload)+"\n", text=True,
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    vals = [float(x) for x in cp.stdout.split()]
    if len(vals) != len(c):
        raise AssertionError(f"{exe}: expected {len(c)} outputs, got {len(vals)}")
    return vals


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: check_wofost81_assimilation_oracle.py O0_EXE O2_EXE")
    c = cases()
    expected = [totass8(x) for x in c]
    out0 = run(sys.argv[1], c)
    out2 = run(sys.argv[2], c)
    max_abs = 0.0
    max_rel = 0.0
    for i, (e, a, b) in enumerate(zip(expected, out0, out2)):
        scale = max(1.0, abs(e))
        err = abs(a-e)
        max_abs = max(max_abs, err)
        max_rel = max(max_rel, err/scale)
        if err > 2e-11 + 2e-12*abs(e):
            raise AssertionError(f"oracle mismatch case {i}: expected={e:.17g} fortran={a:.17g}")
        if a != b:
            raise AssertionError(f"O0/O2 mismatch case {i}: {a:.17g} vs {b:.17g}")
    # Scientific behavior checks independent of exact arithmetic parity.
    if expected[1] != 0.0 or expected[2] != 0.0:
        raise AssertionError("DAYL=0 and LAI=0 must produce zero assimilation")
    if not expected[4] < expected[0]:
        raise AssertionError("zero leaf N should reduce assimilation below N-sufficient case")
    print(f"SWAP431_WOF81_03_ORACLE_PASS cases={len(c)} max_abs={max_abs:.3e} max_rel={max_rel:.3e}")

if __name__ == '__main__':
    main()
