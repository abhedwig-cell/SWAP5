from dataclasses import dataclass

@dataclass
class Domain:
    pp: float
    top_area: float
    capacity: float
    accepted_vertical: float = 0.0
    accepted_lateral: float = 0.0

def partition_and_redistribute(vertical_total, lateral_total, domains):
    total_area = sum(d.top_area for d in domains)
    potential_v = [vertical_total*d.top_area/total_area for d in domains]
    potential_l = [lateral_total*d.top_area/total_area for d in domains]

    excess = 0.0
    satdef = []
    satdef_rel = []

    for i,d in enumerate(domains):
        potential = potential_v[i] + potential_l[i]
        accepted = min(potential,d.capacity)
        frac = accepted/potential if potential > 0 else 1.0
        d.accepted_vertical = potential_v[i]*frac
        d.accepted_lateral = potential_l[i]*frac
        excess += potential-accepted
        deficit = max(0.0,d.capacity-accepted)
        satdef.append(deficit)
        satdef_rel.append(deficit/max(d.capacity,1e-30))

    order = sorted(range(len(domains)),key=lambda i:satdef_rel[i])
    pp_total = 1.0
    for i in order:
        d = domains[i]
        potential = potential_v[i] + potential_l[i]
        if satdef[i] > 1e-12 and potential > 1e-12 and excess > 1e-12:
            pp = d.pp/pp_total if pp_total > 1e-30 else 0.0
            transferred = min(pp*excess,satdef[i])
            factor = transferred/potential
            d.accepted_vertical += factor*potential_v[i]
            d.accepted_lateral += factor*potential_l[i]
            excess -= transferred
            satdef[i] -= transferred
        pp_total -= d.pp

    accepted_v = sum(d.accepted_vertical for d in domains)
    accepted_l = sum(d.accepted_lateral for d in domains)
    returned = max(0.0,excess)
    return accepted_v,accepted_l,returned

if __name__ == "__main__":
    cases = [
        (0.3,0.2,[0.1,0.15,0.4]),
        (0.0,0.5,[0.05,0.5,0.1]),
        (0.5,0.0,[0.02,0.02,0.02]),
        (0.1,0.4,[0.5,0.5,0.5]),
    ]
    pp=[0.2,0.3,0.5]
    area=[0.2,0.3,0.5]

    for vertical,lateral,capacity in cases:
        domains=[Domain(p,a,c) for p,a,c in zip(pp,area,capacity)]
        accepted_v,accepted_l,returned=partition_and_redistribute(vertical,lateral,domains)
        residual=accepted_v+accepted_l+returned-(vertical+lateral)
        assert abs(residual) < 1e-14
        assert returned >= 0.0
        assert accepted_v >= 0.0 and accepted_l >= 0.0

    limited=[Domain(p,a,c) for p,a,c in zip(pp,area,[0.02,0.02,0.02])]
    av,al,returned=partition_and_redistribute(0.5,0.0,limited)
    assert abs(returned-0.44) < 1e-14
    assert abs(av-0.06) < 1e-14
    assert al == 0.0

    print("PPA_WU05A5_P1_P2_LOCAL=PASS")
