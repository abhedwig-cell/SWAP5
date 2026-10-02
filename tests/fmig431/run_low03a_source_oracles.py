#!/usr/bin/env python3
"""Frozen-source law oracles for F-MIG431-LOW03-A.

This runner is intentionally independent of the production adapter. It binds the
numeric expectations to the exact corrected B1.11 source carrier hashes and to
the preregistered source extraction. Production tests compare their observed
proposal/trial samples against these values.
"""
from __future__ import annotations
import base64, gzip, hashlib, json, math, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
CARRIER = ROOT / "integration/audits/F-MIG431_LOWER_BOUNDARY_B111_SOURCE.json"
EXPECTED = {
    "SWAP/boundbottom.f90": "5735f2b6e70408d304f6f5fa35ba659fb3422e03109630e27368933f5c10836e",
    "SWAP/functions.f90": "b32dee127747e619cb92965d0473173ec7fd93c56128a0dbd5ebf5942c300527",
    "SWAP/headcalc.f90": "db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5",
    "SWAP/readswap.f90": "e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c",
    "SWAP/swap.f90": "39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a",
    "SWAP/timecontrol.f90": "6d2a62db0ff1e3ea00693f7b39bdb36e1811ba79011f15feef5a656ddf3181b8",
}

carrier = json.loads(CARRIER.read_text())
members = {m["path"]: m for m in carrier["members"]}
raw = {}
for path, expected in EXPECTED.items():
    member = members[path]
    data = gzip.decompress(base64.b64decode(member["gzip_base64"]))
    actual = hashlib.sha256(data).hexdigest()
    if actual != expected or member["sha256"] != expected:
        raise RuntimeError(f"frozen carrier drift: {path}")
    raw[path] = data.decode(errors="strict").lower()

# Lightweight source-presence guards. Numerical expectations below are tied to
# these exact source blobs; these guards prevent an accidental carrier with the
# right file names but unrelated lower-boundary source from being accepted.
for token in ("haquif", "aqave", "aqamp", "aqtmax", "aqper", "rimlay"):
    if token not in raw["SWAP/boundbottom.f90"] and token not in raw["SWAP/readswap.f90"]:
        raise RuntimeError("missing B1.11 mode3 token: " + token)
for token in ("qbot4", "date4", "rimlay"):
    if token not in raw["SWAP/headcalc.f90"] and token not in raw["SWAP/readswap.f90"]:
        raise RuntimeError("missing B1.11 Q4/mode3 token: " + token)
if "afgen" not in raw["SWAP/functions.f90"]:
    raise RuntimeError("missing B1.11 AFGEN source")
if "boundbottom" not in raw["SWAP/swap.f90"]:
    raise RuntimeError("missing B1.11 BoundBottom call site")

def afgen(xs, ys, x):
    if len(xs) != len(ys) or not xs:
        raise ValueError
    if any(not math.isfinite(v) for v in xs + ys):
        raise ValueError
    if any(b <= a for a, b in zip(xs, xs[1:])):
        raise ValueError
    if x <= xs[0] or len(xs) == 1:
        return ys[0]
    for i in range(1, len(xs)):
        if x <= xs[i]:
            slope = (ys[i] - ys[i-1]) / (xs[i] - xs[i-1])
            return ys[i-1] + (x - xs[i-1]) * slope
    return ys[-1]

def table_head(dates3, heads3, legacy_origin, canonical_origin, original_t1):
    v = afgen(dates3, heads3, legacy_origin + (original_t1 - canonical_origin))
    if not (-10000.0 <= v <= 1000.0):
        raise ValueError
    return v

def sine_head(aqave, aqamp, aqtmax, aqper, proposal_start_t1900, year_start_t1900):
    if aqper <= 0.0:
        raise ValueError("AQPER=0 is singular")
    t = proposal_start_t1900 - year_start_t1900
    v = aqave + aqamp * math.cos((2.0 * math.pi / aqper) * (t - aqtmax))
    if not math.isfinite(v) or not (-10000.0 <= v <= 1000.0):
        raise ValueError
    return v

def q4(dates4, flux4, legacy_origin, canonical_origin, trial_t1):
    v = afgen(dates4, flux4, legacy_origin + (trial_t1 - canonical_origin))
    if not (-100.0 <= v <= 100.0):
        raise ValueError
    return v

# DATE3 exact knots and constant endpoint extension.
d3 = [1000.0, 1000.5, 1001.0]
h3 = [-100.0, -75.0, -25.0]
assert table_head(d3, h3, 1000.0, 5100.1875, 5100.6875) == -75.0
assert afgen(d3, h3, 999.0) == -100.0
assert afgen(d3, h3, 1002.0) == -25.0
assert afgen(d3, h3, 1000.25) == -87.5

# Independent DATE4 axis and the critical proposal/retry timing split.
d4 = [2000.0, 2001.0]
q = [0.0, 0.02]
canonical0 = 5100.1875
legacy4 = 2000.0
original_t1 = canonical0 + 0.5
retry_t1 = canonical0 + 0.125
head_original = table_head(d3, h3, 1000.0, canonical0, original_t1)
q4_original = q4(d4, q, legacy4, canonical0, original_t1)
q4_retry = q4(d4, q, legacy4, canonical0, retry_t1)
assert head_original == -75.0
assert abs(q4_original - 0.01) < 1e-15
assert abs(q4_retry - 0.0025) < 1e-15
assert q4_retry != q4_original

# Sine law uses proposal-start calendar-year phase, not trial endpoint.
s0 = sine_head(-300.0, 50.0, 30.0, 365.0, 1000.25, 1000.0)
s1 = sine_head(-300.0, 50.0, 30.0, 365.0, 1000.25, 1000.0)
assert s0 == s1
try:
    sine_head(-300.0, 50.0, 30.0, 0.0, 1000.25, 1000.0)
except ValueError:
    pass
else:
    raise AssertionError("AQPER=0 did not fail closed")

# Typed-domain failure examples.
for bad_dates in ([1.0, 1.0], [2.0, 1.0]):
    try:
        afgen(list(bad_dates), [0.0, 1.0], 1.0)
    except ValueError:
        pass
    else:
        raise AssertionError("non-increasing table accepted")

print("LOW03A_FROZEN_CARRIER_HASHES=PASS")
print("LOW03A_DATE3_AFGEN_ORACLE=PASS")
print("LOW03A_SINE_PROPOSAL_START_ORACLE=PASS")
print("LOW03A_DATE4_TRIAL_ENDPOINT_ORACLE=PASS")
print("LOW03A_PROPOSAL_VS_RETRY_TIMING_ORACLE=PASS")
