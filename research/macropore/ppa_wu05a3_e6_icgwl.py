from dataclasses import dataclass

@dataclass(frozen=True)
class Profile:
    volume: tuple[float, ...]
    water: tuple[float, ...]
    ictop: int = 1

def legacy_kinematic_icgwl(profile: Profile) -> int:
    n = len(profile.volume)
    icgwl = n + 1
    ic = n
    while icgwl > n and ic >= profile.ictop:
        v = profile.volume[ic-1]
        w = profile.water[ic-1]
        if v > 0.0 and w/v < 1.0:
            icgwl = ic
        ic -= 1
    if icgwl > n:
        icgwl = 1
    return icgwl

def macrostate_standard_interface_from_total(volume, total_water, ictop=1):
    """Exact B1.11 standard-domain storage/interface reduction, macropore.f90:1369-1385."""
    n = len(volume)
    ic = n
    vlhlp = volume[ic-1]
    while vlhlp < total_water - 1.0e-12 and ic > ictop:
        ic -= 1
        vlhlp += volume[ic-1]
    return ic

if __name__ == "__main__":
    cases = {
        "partial-interface": Profile((.2,.2,.2,.2), (0.0,0.08,.2,.2)),
        "deep-partial":      Profile((.2,.2,.2,.2), (0.0,0.0,.05,.2)),
        "single-partial":    Profile((.2,.2,.2,.2), (0.0,0.0,0.0,.12)),
        "all-full":          Profile((.2,.2,.2,.2), (.2,.2,.2,.2)),
        "all-dry":           Profile((.2,.2,.2,.2), (0.0,0.0,0.0,0.0)),
    }

    for name, p in cases.items():
        a = legacy_kinematic_icgwl(p)
        b = macrostate_standard_interface_from_total(p.volume, sum(p.water), p.ictop)
        assert a == b, (name, a, b)

    print("PPA_WU05A3_E6_INTERFACE_INDEX_LOCAL=PASS")
