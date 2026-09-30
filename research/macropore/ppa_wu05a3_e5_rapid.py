from math import sqrt

def rapid_drain(z_water, z_drain=-80.0, z_bottom=-100.0, pond=0.0, dt=0.1,
                dipo=4.0, dz=10.0, vl=0.5, satfr=1.0,
                areaexp=3.0, kd_ref=None, res_ref=20.0,
                water_storage=0.5, vol_under_drain=0.0, fr_redu_q=1.0):
    """One-compartment B1.11 RAPIDDRAIN reduction, macrorate.f90:1895-1924."""
    width = dipo * (1.0 - sqrt(1.0 - vl/dz))
    kd = ((width**areaexp)/dipo) * dz
    kd *= satfr
    if kd_ref is None:
        kd_ref = kd

    drainable = max(0.0, water_storage-vol_under_drain)
    dh = z_water-max(z_drain,z_bottom)
    if z_water > -1.0e-7:
        dh += pond
    dh = max(dh,0.0)

    if kd > 1.0e-10:
        facres = min(kd_ref/kd,1.1)
        res = res_ref*facres
        amount = fr_redu_q*(dh/res)*dt
    else:
        res = float("inf")
        amount = 0.0

    amount = min(amount,drainable)
    return amount/dt, amount, kd, res, dh

if __name__ == "__main__":
    levels=[-90,-81,-80,-79.9,-79,-75,-60]
    rows=[(z,*rapid_drain(z)) for z in levels]

    assert rows[0][1] == 0.0
    assert rows[1][1] == 0.0
    assert rows[2][1] == 0.0
    assert 0.0 < rows[3][1] < rows[4][1] < rows[5][1] < rows[6][1]

    ratio = rows[4][1]/rows[3][1]
    assert 9.9 < ratio < 10.1

    _, amount, *_ = rapid_drain(-20, water_storage=0.03)
    assert abs(amount-0.03) < 1.0e-15

    print("PPA_WU05A3_E5_RAPID_DRAIN_LOCAL=PASS")
