from dataclasses import dataclass

@dataclass(frozen=True)
class Params:
    theta_s: float = 0.45
    theta_cr: float = 0.30
    dz: float = 10.0
    geomfac: float = 3.0
    fr_matrix: float = 0.92
    subsidy_min: float = 0.0

def dynamic_crack(theta, theta_m1, prior_crack, neighbour_crack, shrink_rel, p: Params):
    """Exact MPVOLUME branch structure from B1.11 macropore.f90 lines 1728-1755."""
    if not (theta < p.theta_s - 1.0e-4):
        return 0.0

    vl_shri_cp = shrink_rel * p.dz
    if theta > theta_m1 - 1.0e-8 and (prior_crack > 0.0 or neighbour_crack > 0.0):
        crit_theta = p.theta_s
    else:
        crit_theta = p.theta_cr

    if theta < crit_theta:
        subsidy = (1.0 - (1.0 - shrink_rel)**(1.0/p.geomfac)) * p.dz
        subsidy = max(subsidy, p.subsidy_min)
        dynamic = p.fr_matrix * (vl_shri_cp - subsidy) * p.dz / (p.dz - subsidy)
        return max(0.0, dynamic)
    return 0.0

if __name__ == "__main__":
    p = Params()
    theta = 0.35
    theta_m1 = 0.30
    shrink_rel = 0.05

    fresh = dynamic_crack(theta, theta_m1, 0.0, 0.0, shrink_rel, p)
    historic = dynamic_crack(theta, theta_m1, 0.08, 0.0, shrink_rel, p)
    neighbour = dynamic_crack(theta, theta_m1, 0.0, 0.08, shrink_rel, p)

    assert fresh == 0.0
    assert historic > 0.0
    assert neighbour > 0.0
    print("PPA_WU05A3_E4_CRACK_HISTORY_LOCAL=PASS")
