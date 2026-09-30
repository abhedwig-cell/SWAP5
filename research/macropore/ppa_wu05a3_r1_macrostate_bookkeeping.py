def refined_icgwl(current_water, current_volume, ictop=1):
    n = len(current_volume)
    total = sum(current_water)
    ic = n
    vlhlp = current_volume[ic - 1]
    wet = [0.0] * n
    while vlhlp < total - 1.0e-12 and ic > ictop:
        wet[ic - 1] = 1.0
        ic -= 1
        vlhlp += current_volume[ic - 1]

    top_water = ic
    frac = 0.0 if current_volume[ic - 1] <= 1.0e-8 else 1.0 - (vlhlp - total) / current_volume[ic - 1]
    wet[ic - 1] = max(0.0, min(1.0, frac))

    icgwl = top_water
    if icgwl > ictop and wet[icgwl - 1] >= 1.0 - 1.0e-12:
        icgwl -= 1
    return icgwl


def reconstruct_qtop(previous_water, current_water, previous_volume, current_volume,
                     q_exchange, top_inflow, dt=0.1, ictop=1):
    n = len(current_water)
    icgwl = refined_icgwl(current_water, current_volume, ictop)

    qtop = [None] * (n + 2)  # one-based; n+1 is bottom boundary
    qtop[1] = top_inflow
    qtop[n + 1] = 0.0

    # Exact MACROSTATE standard-route top-down unsaturated recurrence.
    for ic in range(1, icgwl + 1):
        if ic > 1:
            qtop[ic] = (
                qtop[ic - 1]
                - q_exchange[ic - 2]
                - (current_water[ic - 2] - previous_water[ic - 2]) / dt
            )

    # Exact MACROSTATE bottom-up saturated recurrence, fixed domain bottom.
    if icgwl < n:
        for ic in range(n, icgwl, -1):
            qtop[ic] = (
                qtop[ic + 1]
                + q_exchange[ic - 1]
                + (current_volume[ic - 1] - previous_volume[ic - 1]) / dt
            )

    residual = []
    for ic in range(1, n + 1):
        if qtop[ic] is None or qtop[ic + 1] is None:
            residual.append(None)
        else:
            residual.append(
                qtop[ic]
                - qtop[ic + 1]
                - q_exchange[ic - 1]
                - (current_water[ic - 1] - previous_water[ic - 1]) / dt
            )
    return icgwl, qtop, residual


def globally_closed_top_inflow(previous_water, current_water, q_exchange, dt=0.1):
    return sum(q_exchange) + sum(b - a for a, b in zip(previous_water, current_water)) / dt


if __name__ == "__main__":
    volume = [0.18, 0.21, 0.24, 0.27]
    q_exchange = [0.01, 0.02, 0.03, 0.04]
    dt = 0.1

    # Stationary interface: compartment 3 remains partially filled.
    p0 = [0.0, 0.0, 0.10, 0.27]
    p1 = [0.0, 0.0, 0.15, 0.27]
    qin = globally_closed_top_inflow(p0, p1, q_exchange, dt)
    _, _, r = reconstruct_qtop(p0, p1, volume, volume, q_exchange, qin, dt)
    assert max(abs(x) for x in r if x is not None) < 1.0e-12

    # Interface moves upward: compartment 3 becomes fully saturated and
    # compartment 2 becomes the new partial/interface compartment.
    p0 = [0.0, 0.0, 0.20, 0.27]
    p1 = [0.0, 0.01, 0.24, 0.27]
    qin = globally_closed_top_inflow(p0, p1, q_exchange, dt)
    _, _, r = reconstruct_qtop(p0, p1, volume, volume, q_exchange, qin, dt)

    assert abs(sum(x for x in r if x is not None)) < 1.0e-12
    assert abs(r[1] - 0.4) < 1.0e-12
    assert abs(r[2] + 0.4) < 1.0e-12

    print("PPA_WU05A3_R1_MACROSTATE_BOOKKEEPING_LOCAL=PASS")
