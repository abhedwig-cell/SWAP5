from dataclasses import dataclass
from math import sqrt

@dataclass(frozen=True)
class State:
    macro_storage: float
    theta: float
    sorp: float
    theta_ref: float
    tabs: float

@dataclass(frozen=True)
class Params:
    theta_s: float = 0.45
    theta_r: float = 0.05
    dz: float = 10.0
    pp: float = 0.08
    dipo: float = 4.0
    awl: float = 0.95
    sorp_max: float = 0.50
    sorp_alpha: float = 0.5
    macro_capacity: float = 1.2

def absorption_amount(s: State, p: Params, dt: float):
    satdef = max(0.0, p.theta_s - s.theta)
    if satdef < 1e-8:
        return 0.0, s.sorp, s.theta_ref, True
    if s.tabs < 1e-8:
        ref = p.theta_s
        sorp = p.sorp_max * (satdef/(p.theta_s-p.theta_r))**p.sorp_alpha
        active = sorp
    elif (s.theta_ref-s.theta) > 1e-8:
        ref = s.theta_ref
        sorp = s.sorp
        active = p.sorp_max * ((ref-s.theta)/(p.theta_s-p.theta_r))**p.sorp_alpha
    else:
        ref = s.theta_ref
        sorp = s.sorp
        active = 0.0
    amount = active*p.pp*(4*p.awl*p.dz/p.dipo)*(sqrt(s.tabs+dt)-sqrt(s.tabs))
    return max(0.0, amount), sorp, ref, amount/dt <= 1e-7

def step(s: State, p: Params, qtop: float, dt: float):
    amount, sorp, ref, end = absorption_amount(s,p,dt)
    amount = min(amount, s.macro_storage + qtop*dt)
    macro1 = s.macro_storage + qtop*dt - amount
    matrix_capacity_depth = (1.0-p.pp)*p.dz
    theta1 = min(p.theta_s, s.theta + amount/matrix_capacity_depth)
    if end:
        sorp1, ref1, tabs1 = 0.0, 0.0, 0.0
    else:
        ref1 = ref + p.awl*p.pp*(4/p.dipo)*sorp*(sqrt(s.tabs+dt)-sqrt(s.tabs))
        sorp1, tabs1 = sorp, s.tabs + dt
    next_state = State(macro1,theta1,sorp1,ref1,tabs1)
    matrix_gain = (theta1-s.theta)*matrix_capacity_depth
    residual = (macro1-s.macro_storage) + matrix_gain - qtop*dt
    return next_state, amount/dt, residual

if __name__ == "__main__":
    p = Params(); dt = 0.1; qtop = 0.2
    fresh = State(0.7,0.16,0.0,0.0,0.0)
    sorp0 = p.sorp_max*((p.theta_s-fresh.theta)/(p.theta_s-p.theta_r))**p.sorp_alpha
    aged = State(0.7,0.16,sorp0,0.47,0.5)

    fresh1,qfresh,rf = step(fresh,p,qtop,dt)
    aged1,qaged,ra = step(aged,p,qtop,dt)

    assert abs(rf) < 1e-14 and abs(ra) < 1e-14
    assert qfresh > 2.0*qaged
    assert fresh1.theta > aged1.theta
    print("PPA_WU05A3_E3_MEMORY_LOCAL=PASS")
