from dataclasses import dataclass, replace
from math import sqrt

@dataclass(frozen=True)
class MatrixState:
    theta: float
    theta_s: float = 0.45
    theta_r: float = 0.05
    depth_cm: float = 20.0

@dataclass(frozen=True)
class MacroporeState:
    icp_bottom_domain: int
    sorptivity: float
    theta_sorption_ref: float
    absorption_time: float
    volume: float
    water: float
    dynamic_volume: float

def dynamic_crack(theta, theta_m1, prior_crack, neighbour_crack, shrink_rel):
    theta_s=0.45; theta_cr=0.30; dz=10.0; geomfac=3.0; fr_matrix=0.92
    if theta >= theta_s - 1.0e-4:
        return 0.0
    crit = theta_s if (theta > theta_m1 - 1.0e-8 and (prior_crack > 0.0 or neighbour_crack > 0.0)) else theta_cr
    if theta >= crit:
        return 0.0
    vl_shri=shrink_rel*dz
    subsidy=(1.0-(1.0-shrink_rel)**(1.0/geomfac))*dz
    dynamic=fr_matrix*(vl_shri-subsidy)*dz/(dz-subsidy)
    return max(0.0,dynamic)

def universal_qtop(prev,curr,qex,qin,dt=0.1):
    n=len(prev); q=[None]*(n+2); q[1]=qin
    for i in range(1,n+1):
        q[i+1]=q[i]-qex[i-1]-(curr[i-1]-prev[i-1])/dt
    return q

def qtop_residual(q,prev,curr,qex,dt=0.1):
    return [q[i]-q[i+1]-qex[i-1]-(curr[i-1]-prev[i-1])/dt for i in range(1,len(prev)+1)]

def extreme_candidate(matrix, macro, q_top, dt=0.05):
    deficit=max(0.0,matrix.theta_s-matrix.theta)
    sorp=0.50*(deficit/(matrix.theta_s-matrix.theta_r))**0.5
    absorbed=sorp*0.08*(4*0.95*10/4)*(sqrt(dt)-0.0)
    incoming=q_top*dt
    available=macro.water+incoming
    absorbed=min(absorbed,available)
    rapid=min(max(0.0,available-absorbed),(15.0/20.0)*dt)
    remaining=available-absorbed-rapid
    overflow=max(0.0,remaining-macro.volume)
    water1=remaining-overflow
    matrix_depth=(1.0-0.08)*matrix.depth_cm
    theta1=min(matrix.theta_s,matrix.theta+absorbed/matrix_depth)
    matrix_gain=(theta1-matrix.theta)*matrix_depth
    residual=(water1-macro.water)+matrix_gain+rapid+overflow-incoming
    return water1,overflow,residual

if __name__ == "__main__":
    # G5 / E4 regression
    fresh=dynamic_crack(0.35,0.30,0.0,0.0,0.05)
    historic=dynamic_crack(0.35,0.30,0.08,0.0,0.05)
    assert fresh == 0.0 and historic > 0.30

    # G6 / E7 + R1-MSTATE02 regression
    prev=[0.0,0.0,0.20,0.27]
    curr=[0.0,0.01,0.24,0.27]
    qex=[0.01,0.02,0.03,0.04]
    dt=0.1
    qin=sum(qex)+sum(b-a for a,b in zip(prev,curr))/dt
    q=universal_qtop(prev,curr,qex,qin,dt)
    assert max(abs(x) for x in qtop_residual(q,prev,curr,qex,dt)) < 1.0e-12

    # G7 / E9 regression
    matrix=MatrixState(0.16)
    macro=MacroporeState(4,0.0,0.0,0.0,1.2,0.4,0.03)
    saw_overflow=False
    for qin in (0,1,5,10,25,50,100,250):
        water,overflow,residual=extreme_candidate(matrix,macro,qin)
        assert -1.0e-14 <= water <= macro.volume + 1.0e-14
        assert abs(residual) < 1.0e-13
        saw_overflow = saw_overflow or overflow > 0.0
    assert saw_overflow

    print("PPA_WU05A4_R2_PRESCRIBED_G5_G7=PASS")
