from dataclasses import dataclass

@dataclass(frozen=True)
class Geometry:
    volume: tuple[float, ...]
    dz: tuple[float, ...]
    z_bottom: float = -100.0
    ictop: int = 1

def standard_storage(total, g: Geometry):
    n = len(g.volume)
    total = max(0.0, min(sum(g.volume), total))
    water = [0.0] * n
    wet_fraction = [0.0] * n

    ic = n
    vlhlp = g.volume[ic - 1]
    while vlhlp < total - 1.0e-12 and ic > g.ictop:
        wet_fraction[ic - 1] = 1.0
        water[ic - 1] = g.volume[ic - 1]
        ic -= 1
        vlhlp += g.volume[ic - 1]

    top_water = ic
    v = g.volume[ic - 1]
    if v > 1.0e-8:
        frac = 1.0 - (vlhlp - total) / v
        frac = max(0.0, min(1.0, frac))
        wet_fraction[ic - 1] = frac
        water[ic - 1] = v * frac
    else:
        wet_fraction[ic - 1] = 0.0
        top_water = ic + 1

    z = g.z_bottom
    for j in range(n, top_water, -1):
        z += g.dz[j - 1]
    if 1 <= top_water <= n:
        z += wet_fraction[top_water - 1] * g.dz[top_water - 1]

    return tuple(water), tuple(wet_fraction), top_water, z

def legacy_kinematic_icgwl(water, volume, ictop=1):
    n = len(volume)
    icgwl = n + 1
    ic = n
    while icgwl > n and ic >= ictop:
        v = volume[ic - 1]
        ratio = 0.0 if v <= 0.0 else water[ic - 1] / v
        if ratio < 1.0:
            icgwl = ic
        ic -= 1
    if icgwl > n:
        icgwl = 1
    return icgwl

def corrected_candidate(top_water, wet_fraction, ictop=1):
    icgwl = top_water
    if icgwl > ictop and wet_fraction[icgwl - 1] >= 1.0 - 1.0e-12:
        icgwl -= 1
    return icgwl

if __name__ == "__main__":
    g = Geometry(volume=(0.18, 0.21, 0.24, 0.27), dz=(10.0, 10.0, 10.0, 10.0))
    capacity = sum(g.volume)

    previous_z = None
    max_dz = 0.0
    for k in range(10001):
        total = capacity * k / 10000.0
        water, wet, top, z = standard_storage(total, g)
        expected = legacy_kinematic_icgwl(water, g.volume, g.ictop)
        candidate = corrected_candidate(top, wet, g.ictop)

        assert candidate == expected, (k, total, water, wet, top, expected, candidate)
        assert abs(sum(water) - total) < 2.0e-12

        if previous_z is not None:
            assert z >= previous_z - 1.0e-12
            max_dz = max(max_dz, z - previous_z)
        previous_z = z

    assert max_dz < 0.01
    print("PPA_WU05A3_E7_INTERFACE_SWEEP_LOCAL=PASS")
