from __future__ import annotations

from dataclasses import dataclass
from itertools import product
import math
from typing import Optional


@dataclass(frozen=True)
class AffineStorage:
    """Transparent storage law with an affine dV/dH relation.

    tangent(H) = storage_at_reference + storage_slope_per_m * (H-reference_head)

    For unit horizontal area, volume is expressed as metres of water and
    dV/dH is dimensionless.
    """

    storage_at_reference: float
    reference_head_m: float = 0.0
    storage_slope_per_m: float = 0.0

    def tangent(self, head_m: float) -> float:
        return self.storage_at_reference + self.storage_slope_per_m * (
            head_m - self.reference_head_m
        )

    def change(self, head0_m: float, head1_m: float) -> float:
        x = head1_m - head0_m
        return self.tangent(head0_m) * x + 0.5 * self.storage_slope_per_m * x * x


@dataclass(frozen=True)
class LinearHeadSink:
    """Physical external sink q = slope * max(0, H-threshold)."""

    name: str
    threshold_head_m: float
    slope_per_day: float

    def rate_m_per_day(self, head_m: float) -> float:
        return self.slope_per_day * max(0.0, head_m - self.threshold_head_m)


@dataclass(frozen=True)
class LinearMemory:
    """One transparent internal water-memory reservoir.

    The end-of-window state is implicit Euler relaxation toward an optional
    head-dependent target:

      m1 = (m0 + input + k*dt*gamma*(H1-Href)) / (1+k*dt)

    Water transferred from memory to the shared groundwater store is

      transfer = m0 + input - m1.

    gamma=0 gives the DSW15/DSW20 delayed-release surrogate.
    """

    release_rate_per_day: float = 0.0
    head_coupling_m_per_m: float = 0.0
    reference_head_m: float = 0.0

    def end_state(
        self,
        memory0_m: float,
        memory_input_m: float,
        head1_m: float,
        dt_day: float,
    ) -> float:
        kdt = self.release_rate_per_day * dt_day
        return (
            memory0_m
            + memory_input_m
            + kdt
            * self.head_coupling_m_per_m
            * (head1_m - self.reference_head_m)
        ) / (1.0 + kdt)

    def transfer_to_groundwater_m(
        self,
        memory0_m: float,
        memory_input_m: float,
        head1_m: float,
        dt_day: float,
    ) -> float:
        return memory0_m + memory_input_m - self.end_state(
            memory0_m, memory_input_m, head1_m, dt_day
        )


@dataclass(frozen=True)
class AnalyticSwapState:
    head_m: float
    memory_m: float = 0.0


@dataclass(frozen=True)
class AnalyticSwapForcing:
    """Window-integrated external forcing for the analytic column."""

    atmospheric_input_m: float = 0.0
    lateral_groundwater_input_m: float = 0.0
    memory_input_m: float = 0.0
    external_boundary_head_m: Optional[float] = None
    boundary_conductance_per_day: float = 0.0


@dataclass(frozen=True)
class AnalyticSwapResult:
    state: AnalyticSwapState
    storage_change_m: float
    memory_change_m: float
    memory_transfer_to_groundwater_m: float
    boundary_exchange_into_column_m: float
    sink_volumes_m: tuple[tuple[str, float], ...]
    external_net_input_m: float
    complete_mass_error_m: float

    def sink_volume(self, name: str) -> float:
        for sink_name, value in self.sink_volumes_m:
            if sink_name == name:
                return value
        return 0.0


@dataclass(frozen=True)
class AnalyticSwapColumn:
    """Small research-only analytic SWAP surrogate.

    It is deliberately not a Richards model. It keeps the water-balance
    objects explicit: storage, internal memory transfer, external forcing,
    physical head-dependent sinks and an optional fixed-head resistance link.
    """

    storage: AffineStorage
    memory: LinearMemory = LinearMemory()
    sinks: tuple[LinearHeadSink, ...] = ()

    def solve_window(
        self,
        state0: AnalyticSwapState,
        forcing: AnalyticSwapForcing,
        dt_day: float,
    ) -> AnalyticSwapResult:
        self._validate(state0, forcing, dt_day)

        candidates: list[float] = []
        for active_mask in product((False, True), repeat=len(self.sinks)):
            a, b, c = self._polynomial_coefficients(
                state0, forcing, dt_day, active_mask
            )
            for x in self._real_roots(a, b, c):
                head1 = state0.head_m + x
                if not math.isfinite(head1):
                    continue
                if not self._branch_consistent(head1, active_mask):
                    continue
                if self.storage.tangent(head1) <= 0.0:
                    continue
                residual = self.balance_residual_m(
                    head1, state0, forcing, dt_day
                )
                scale = max(
                    1.0,
                    abs(forcing.atmospheric_input_m),
                    abs(forcing.lateral_groundwater_input_m),
                    abs(forcing.memory_input_m),
                )
                if abs(residual) <= 2.0e-12 * scale:
                    candidates.append(head1)

        if not candidates:
            raise ValueError("analytic SWAP balance has no admissible real root")

        # Prefer the continuous local branch when an affine-storage law has a
        # remote second quadratic root.
        head1 = min(candidates, key=lambda h: abs(h - state0.head_m))

        memory1 = self.memory.end_state(
            state0.memory_m,
            forcing.memory_input_m,
            head1,
            dt_day,
        )
        memory_transfer = (
            state0.memory_m + forcing.memory_input_m - memory1
        )
        storage_change = self.storage.change(state0.head_m, head1)
        boundary_exchange = self._boundary_exchange_m(
            head1, forcing, dt_day
        )
        sink_volumes = tuple(
            (sink.name, sink.rate_m_per_day(head1) * dt_day)
            for sink in self.sinks
        )
        sink_total = sum(value for _, value in sink_volumes)
        external_net = (
            forcing.atmospheric_input_m
            + forcing.lateral_groundwater_input_m
            + forcing.memory_input_m
            + boundary_exchange
            - sink_total
        )
        memory_change = memory1 - state0.memory_m
        mass_error = storage_change + memory_change - external_net

        return AnalyticSwapResult(
            state=AnalyticSwapState(head_m=head1, memory_m=memory1),
            storage_change_m=storage_change,
            memory_change_m=memory_change,
            memory_transfer_to_groundwater_m=memory_transfer,
            boundary_exchange_into_column_m=boundary_exchange,
            sink_volumes_m=sink_volumes,
            external_net_input_m=external_net,
            complete_mass_error_m=mass_error,
        )

    def balance_residual_m(
        self,
        head1_m: float,
        state0: AnalyticSwapState,
        forcing: AnalyticSwapForcing,
        dt_day: float,
    ) -> float:
        storage_change = self.storage.change(state0.head_m, head1_m)
        memory_transfer = self.memory.transfer_to_groundwater_m(
            state0.memory_m,
            forcing.memory_input_m,
            head1_m,
            dt_day,
        )
        boundary_exchange = self._boundary_exchange_m(
            head1_m, forcing, dt_day
        )
        sinks = sum(
            sink.rate_m_per_day(head1_m) * dt_day for sink in self.sinks
        )
        direct_input = (
            forcing.atmospheric_input_m + forcing.lateral_groundwater_input_m
        )
        return (
            storage_change
            - direct_input
            - memory_transfer
            - boundary_exchange
            + sinks
        )

    def _polynomial_coefficients(
        self,
        state0: AnalyticSwapState,
        forcing: AnalyticSwapForcing,
        dt_day: float,
        active_mask: tuple[bool, ...],
    ) -> tuple[float, float, float]:
        h0 = state0.head_m
        a = 0.5 * self.storage.storage_slope_per_m
        b = self.storage.tangent(h0)
        c = -(
            forcing.atmospheric_input_m
            + forcing.lateral_groundwater_input_m
        )

        kdt = self.memory.release_rate_per_day * dt_day
        if kdt > 0.0:
            fraction = kdt / (1.0 + kdt)
            gamma = self.memory.head_coupling_m_per_m
            h_ref = self.memory.reference_head_m
            # residual contains -memory_transfer
            b += fraction * gamma
            c -= fraction * (
                state0.memory_m
                + forcing.memory_input_m
                - gamma * (h0 - h_ref)
            )
        else:
            # With no release, new memory input stays internal and does not
            # enter the groundwater balance in this window.
            pass

        if forcing.external_boundary_head_m is not None:
            c_link = forcing.boundary_conductance_per_day * dt_day
            b += c_link
            c -= c_link * (forcing.external_boundary_head_m - h0)

        for active, sink in zip(active_mask, self.sinks, strict=True):
            if not active:
                continue
            k = sink.slope_per_day * dt_day
            b += k
            c += k * (h0 - sink.threshold_head_m)

        return a, b, c

    @staticmethod
    def _real_roots(a: float, b: float, c: float) -> tuple[float, ...]:
        scale = max(1.0, abs(a), abs(b), abs(c))
        eps = 64.0 * math.ulp(1.0) * scale
        if abs(a) <= eps:
            if abs(b) <= eps:
                if abs(c) <= eps:
                    return (0.0,)
                return ()
            return (-c / b,)

        disc = b * b - 4.0 * a * c
        if disc < -eps:
            return ()
        disc = max(0.0, disc)
        root = math.sqrt(disc)

        # Stable quadratic evaluation.
        q = -0.5 * (b + math.copysign(root, b))
        if q == 0.0:
            return (-b / (2.0 * a),)
        x1 = q / a
        x2 = c / q
        if x1 == x2:
            return (x1,)
        return (x1, x2)

    def _branch_consistent(
        self, head_m: float, active_mask: tuple[bool, ...]
    ) -> bool:
        tol = 1.0e-12 * max(1.0, abs(head_m))
        for active, sink in zip(active_mask, self.sinks, strict=True):
            if active and head_m < sink.threshold_head_m - tol:
                return False
            if not active and head_m > sink.threshold_head_m + tol:
                return False
        return True

    @staticmethod
    def _boundary_exchange_m(
        head1_m: float,
        forcing: AnalyticSwapForcing,
        dt_day: float,
    ) -> float:
        if forcing.external_boundary_head_m is None:
            return 0.0
        return (
            forcing.boundary_conductance_per_day
            * (forcing.external_boundary_head_m - head1_m)
            * dt_day
        )

    def _validate(
        self,
        state0: AnalyticSwapState,
        forcing: AnalyticSwapForcing,
        dt_day: float,
    ) -> None:
        values = [
            state0.head_m,
            state0.memory_m,
            forcing.atmospheric_input_m,
            forcing.lateral_groundwater_input_m,
            forcing.memory_input_m,
            forcing.boundary_conductance_per_day,
            dt_day,
            self.storage.storage_at_reference,
            self.storage.reference_head_m,
            self.storage.storage_slope_per_m,
            self.memory.release_rate_per_day,
            self.memory.head_coupling_m_per_m,
            self.memory.reference_head_m,
        ]
        if forcing.external_boundary_head_m is not None:
            values.append(forcing.external_boundary_head_m)
        for sink in self.sinks:
            values.extend(
                [sink.threshold_head_m, sink.slope_per_day]
            )
        if not all(math.isfinite(value) for value in values):
            raise ValueError("analytic SWAP configuration must be finite")
        if dt_day <= 0.0:
            raise ValueError("dt_day must be positive")
        if state0.memory_m < 0.0:
            raise ValueError("memory storage cannot be negative")
        if self.memory.release_rate_per_day < 0.0:
            raise ValueError("memory release rate cannot be negative")
        if forcing.boundary_conductance_per_day < 0.0:
            raise ValueError("boundary conductance cannot be negative")
        if forcing.external_boundary_head_m is None and (
            forcing.boundary_conductance_per_day != 0.0
        ):
            raise ValueError(
                "boundary conductance requires external_boundary_head_m"
            )
        if self.storage.tangent(state0.head_m) <= 0.0:
            raise ValueError("storage tangent must be positive at origin")
        for sink in self.sinks:
            if sink.slope_per_day < 0.0:
                raise ValueError("sink slope cannot be negative")


@dataclass(frozen=True)
class FiniteResistancePairResult:
    swap_head_m: float
    groundwater_head_m: float
    exchange_swap_to_groundwater_m: float
    swap_storage_change_m: float
    groundwater_storage_change_m: float
    complete_mass_error_m: float


def solve_finite_resistance_pair(
    *,
    swap_head0_m: float,
    groundwater_head0_m: float,
    swap_storage: float,
    groundwater_storage: float,
    swap_external_input_m: float,
    groundwater_external_input_m: float,
    conductance_per_day: float,
    dt_day: float,
) -> FiniteResistancePairResult:
    """Exact implicit two-storage q-link.

    Positive exchange is from the SWAP-side store to the groundwater-side
    store: q = C * (h_swap-h_groundwater).
    """

    values = (
        swap_head0_m,
        groundwater_head0_m,
        swap_storage,
        groundwater_storage,
        swap_external_input_m,
        groundwater_external_input_m,
        conductance_per_day,
        dt_day,
    )
    if not all(math.isfinite(value) for value in values):
        raise ValueError("finite-resistance inputs must be finite")
    if swap_storage <= 0.0 or groundwater_storage <= 0.0:
        raise ValueError("both physical storages must be positive")
    if conductance_per_day < 0.0 or dt_day <= 0.0:
        raise ValueError("invalid conductance or timestep")

    cdt = conductance_per_day * dt_day
    a11 = swap_storage + cdt
    a12 = -cdt
    a21 = -cdt
    a22 = groundwater_storage + cdt
    b1 = swap_storage * swap_head0_m + swap_external_input_m
    b2 = (
        groundwater_storage * groundwater_head0_m
        + groundwater_external_input_m
    )
    det = a11 * a22 - a12 * a21
    if det <= 0.0 or not math.isfinite(det):
        raise ValueError("singular finite-resistance balance")

    h_swap = (b1 * a22 - a12 * b2) / det
    h_gw = (a11 * b2 - b1 * a21) / det
    exchange = cdt * (h_swap - h_gw)
    d_swap = swap_storage * (h_swap - swap_head0_m)
    d_gw = groundwater_storage * (
        h_gw - groundwater_head0_m
    )
    complete_error = (
        d_swap
        + d_gw
        - swap_external_input_m
        - groundwater_external_input_m
    )

    return FiniteResistancePairResult(
        swap_head_m=h_swap,
        groundwater_head_m=h_gw,
        exchange_swap_to_groundwater_m=exchange,
        swap_storage_change_m=d_swap,
        groundwater_storage_change_m=d_gw,
        complete_mass_error_m=complete_error,
    )


def shared_head_from_partition(
    *,
    initial_head_m: float,
    swap_storage: float,
    groundwater_storage: float,
    total_external_input_m: float,
) -> float:
    """Exact one-state shared-head solution for disjoint storage shares."""

    total_storage = swap_storage + groundwater_storage
    if not all(
        math.isfinite(value)
        for value in (
            initial_head_m,
            swap_storage,
            groundwater_storage,
            total_external_input_m,
        )
    ):
        raise ValueError("shared-head inputs must be finite")
    if total_storage <= 0.0:
        raise ValueError("total shared-head storage must be positive")
    return initial_head_m + total_external_input_m / total_storage
