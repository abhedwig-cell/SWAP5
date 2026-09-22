from __future__ import annotations

from dataclasses import dataclass
import math

from gc_rootzone_memory import (
    RootZoneMemoryForcing,
    RootZoneMemoryParameters,
    RootZoneMemoryResult,
    RootZoneMemoryState,
)


@dataclass(frozen=True)
class NonlinearRootZoneMemoryOracle:
    parameters: RootZoneMemoryParameters
    beta_per_m: float
    conductance_reference_head_m: float = 8.0

    def __post_init__(self) -> None:
        self.parameters.validate()
        if not math.isfinite(self.beta_per_m):
            raise ValueError("beta must be finite")

    def vertical_conductance_per_day(self, root_head_m: float, lower_head_m: float) -> float:
        mean_head = 0.5 * (root_head_m + lower_head_m)
        return self.parameters.vertical_conductance_per_day * math.exp(
            self.beta_per_m * (mean_head - self.conductance_reference_head_m)
        )

    def solve_prescribed_interface(
        self,
        state0: RootZoneMemoryState,
        forcing: RootZoneMemoryForcing,
        interface_head_m: float,
        dt_day: float,
        substeps: int,
    ) -> RootZoneMemoryResult:
        p = self.parameters
        if substeps <= 0 or not isinstance(substeps, int):
            raise ValueError("substeps must be a positive integer")
        if not math.isfinite(dt_day) or dt_day <= 0.0:
            raise ValueError("dt_day must be finite and positive")
        if not (0.0 <= state0.root_storage_m <= p.root_capacity_m):
            raise ValueError("committed root storage outside capacity")
        values = (
            state0.lower_head_m, forcing.root_input_rate_m_per_day,
            forcing.lower_input_rate_m_per_day, interface_head_m,
        )
        if not all(math.isfinite(x) for x in values):
            raise ValueError("state and forcing must be finite")

        hr = p.root_head_m(state0.root_storage_m)
        hl = state0.lower_head_m
        ev = 0.0
        ec = 0.0
        h = dt_day / substeps

        def rhs(xr: float, xl: float) -> tuple[float, float, float, float]:
            cv = self.vertical_conductance_per_day(xr, xl)
            qv = cv * (xr - xl)
            qc = p.interface_conductance_per_day * (xl - interface_head_m)
            dhr = (forcing.root_input_rate_m_per_day - qv) / p.root_storage_coefficient
            dhl = (forcing.lower_input_rate_m_per_day + qv - qc) / p.lower_storage_coefficient
            return dhr, dhl, qv, qc

        for _ in range(substeps):
            k1 = rhs(hr, hl)
            k2 = rhs(hr + 0.5*h*k1[0], hl + 0.5*h*k1[1])
            k3 = rhs(hr + 0.5*h*k2[0], hl + 0.5*h*k2[1])
            k4 = rhs(hr + h*k3[0], hl + h*k3[1])
            hr += h * (k1[0] + 2*k2[0] + 2*k3[0] + k4[0]) / 6.0
            hl += h * (k1[1] + 2*k2[1] + 2*k3[1] + k4[1]) / 6.0
            ev += h * (k1[2] + 2*k2[2] + 2*k3[2] + k4[2]) / 6.0
            ec += h * (k1[3] + 2*k2[3] + 2*k3[3] + k4[3]) / 6.0
            wr = p.root_storage_m(hr)
            if not (0.0 <= wr <= p.root_capacity_m):
                raise ValueError("root-zone capacity bound crossed within window")

        wr1 = p.root_storage_m(hr)
        dr = wr1 - state0.root_storage_m
        dl = p.lower_storage_coefficient * (hl - state0.lower_head_m)
        fr = forcing.root_input_rate_m_per_day * dt_day
        fl = forcing.lower_input_rate_m_per_day * dt_day
        root_err = dr - (fr - ev)
        lower_err = dl - (fl + ev - ec)
        swap_change = dr + dl
        swap_external = fr + fl
        swap_err = swap_change - (swap_external - ec)
        ec_ledger = swap_external - swap_change
        return RootZoneMemoryResult(
            state=RootZoneMemoryState(wr1, hl),
            root_head_m=hr,
            interface_head_m=interface_head_m,
            vertical_exchange_m=ev,
            interface_exchange_m=ec,
            interface_exchange_from_ledger_m=ec_ledger,
            root_storage_change_m=dr,
            lower_storage_change_m=dl,
            swap_total_storage_change_m=swap_change,
            swap_external_input_m=swap_external,
            root_mass_error_m=root_err,
            lower_mass_error_m=lower_err,
            swap_mass_error_m=swap_err,
            interface_exchange_route_error_m=ec-ec_ledger,
        )
