def globally_closed_top_inflow(previous_water, current_water, q_exchange, dt=0.1, bottom_flux=0.0):
    return bottom_flux + sum(q_exchange) + sum(b - a for a, b in zip(previous_water, current_water)) / dt


def universal_conservative_reconstruction(previous_water, current_water, q_exchange, top_inflow, dt=0.1):
    n = len(previous_water)
    qtop = [None] * (n + 2)
    qtop[1] = top_inflow
    for ic in range(1, n + 1):
        qtop[ic + 1] = (
            qtop[ic]
            - q_exchange[ic - 1]
            - (current_water[ic - 1] - previous_water[ic - 1]) / dt
        )
    return qtop


def historical_standard_reconstruction(previous_water, current_water, previous_volume, current_volume,
                                       q_exchange, top_inflow, icgwl, dt=0.1):
    n = len(previous_water)
    qtop = [None] * (n + 2)
    qtop[1] = top_inflow
    qtop[n + 1] = 0.0

    for ic in range(1, icgwl + 1):
        if ic > 1:
            qtop[ic] = (
                qtop[ic - 1]
                - q_exchange[ic - 2]
                - (current_water[ic - 2] - previous_water[ic - 2]) / dt
            )

    if icgwl < n:
        for ic in range(n, icgwl, -1):
            qtop[ic] = (
                qtop[ic + 1]
                + q_exchange[ic - 1]
                + (current_volume[ic - 1] - previous_volume[ic - 1]) / dt
            )
    return qtop


def residual(qtop, previous_water, current_water, q_exchange, dt=0.1):
    return [
        qtop[i] - qtop[i + 1] - q_exchange[i - 1]
        - (current_water[i - 1] - previous_water[i - 1]) / dt
        for i in range(1, len(previous_water) + 1)
    ]


if __name__ == "__main__":
    volume = [0.18, 0.21, 0.24, 0.27]
    q_exchange = [0.01, 0.02, 0.03, 0.04]
    dt = 0.1

    # Stationary interface.
    p0 = [0.0, 0.0, 0.10, 0.27]
    p1 = [0.0, 0.0, 0.15, 0.27]
    qin = globally_closed_top_inflow(p0, p1, q_exchange, dt)
    hist = historical_standard_reconstruction(p0, p1, volume, volume, q_exchange, qin, icgwl=3, dt=dt)
    uni = universal_conservative_reconstruction(p0, p1, q_exchange, qin, dt)
    assert all(abs(a - b) < 1.0e-12 for a, b in zip(hist[1:6], uni[1:6]))
    assert max(abs(x) for x in residual(uni, p0, p1, q_exchange, dt)) < 1.0e-12

    # Upward moving interface.
    p0 = [0.0, 0.0, 0.20, 0.27]
    p1 = [0.0, 0.01, 0.24, 0.27]
    qin = globally_closed_top_inflow(p0, p1, q_exchange, dt)
    hist = historical_standard_reconstruction(p0, p1, volume, volume, q_exchange, qin, icgwl=2, dt=dt)
    uni = universal_conservative_reconstruction(p0, p1, q_exchange, qin, dt)

    assert max(abs(x) for x in residual(uni, p0, p1, q_exchange, dt)) < 1.0e-12
    assert abs(hist[3] - uni[3]) > 0.39

    print("PPA_WU05A3_R1_MSTATE02_LOCAL=PASS")
