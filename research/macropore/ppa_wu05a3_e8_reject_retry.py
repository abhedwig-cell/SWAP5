from dataclasses import dataclass
from math import sqrt


@dataclass(frozen=True)
class MacroState:
    icp_bottom_domain: int
    sorptivity: tuple[float, ...]
    theta_sorption_ref: tuple[float, ...]
    absorption_time: tuple[float, ...]
    volume_domain_cp: tuple[float, ...]
    water_domain_cp: tuple[float, ...]
    dynamic_volume_cp: tuple[float, ...]


def source_shaped_trial(state: MacroState, dt: float = 0.1) -> MacroState:
    """Synthetic combined trial that intentionally mutates all seven A1 state groups."""
    volume = tuple(v * (1.0 + 0.02 * (i + 1)) for i, v in enumerate(state.volume_domain_cp))
    dynamic = tuple(v + 0.01 * (i + 1) for i, v in enumerate(state.dynamic_volume_cp))
    water = tuple(min(volume[i], state.water_domain_cp[i] + 0.015 * (i + 1))
                  for i in range(len(state.water_domain_cp)))

    sorp = tuple(v + 0.03 * (i + 1) for i, v in enumerate(state.sorptivity))
    tabs = tuple(v + dt for v in state.absorption_time)
    tref = tuple(
        state.theta_sorption_ref[i]
        + sorp[i] * (sqrt(tabs[i]) - sqrt(state.absorption_time[i]))
        for i in range(len(state.theta_sorption_ref))
    )

    return MacroState(
        icp_bottom_domain=max(1, state.icp_bottom_domain - 1),
        sorptivity=sorp,
        theta_sorption_ref=tref,
        absorption_time=tabs,
        volume_domain_cp=volume,
        water_domain_cp=water,
        dynamic_volume_cp=dynamic,
    )


if __name__ == "__main__":
    accepted = MacroState(
        4,
        (0.2, 0.3, 0.4),
        (0.45, 0.46, 0.47),
        (0.1, 0.2, 0.3),
        (0.1, 0.2, 0.3),
        (0.03, 0.10, 0.25),
        (0.01, 0.02, 0.03),
    )

    clean_candidate = source_shaped_trial(accepted)

    rejected_candidate = source_shaped_trial(accepted)
    del rejected_candidate

    retry_candidate = source_shaped_trial(accepted)

    assert retry_candidate == clean_candidate
    assert accepted != clean_candidate

    assert clean_candidate.icp_bottom_domain != accepted.icp_bottom_domain
    assert clean_candidate.sorptivity != accepted.sorptivity
    assert clean_candidate.theta_sorption_ref != accepted.theta_sorption_ref
    assert clean_candidate.absorption_time != accepted.absorption_time
    assert clean_candidate.volume_domain_cp != accepted.volume_domain_cp
    assert clean_candidate.water_domain_cp != accepted.water_domain_cp
    assert clean_candidate.dynamic_volume_cp != accepted.dynamic_volume_cp

    print("PPA_WU05A3_E8_REJECT_RETRY_LOCAL=PASS")
