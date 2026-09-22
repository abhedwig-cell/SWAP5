from __future__ import annotations

from dataclasses import dataclass
import math


@dataclass(frozen=True)
class RootZoneMemoryParameters:
    root_storage_coefficient: float
    lower_storage_coefficient: float
    vertical_conductance_per_day: float
    interface_conductance_per_day: float
    root_reference_storage_m: float
    root_reference_head_m: float
    root_capacity_m: float

    def validate(self) -> None:
        values = (
            self.root_storage_coefficient,
            self.lower_storage_coefficient,
            self.vertical_conductance_per_day,
            self.interface_conductance_per_day,
            self.root_reference_storage_m,
            self.root_reference_head_m,
            self.root_capacity_m,
        )
        if not all(math.isfinite(v) for v in values):
            raise ValueError("parameters must be finite")
        if self.root_storage_coefficient <= 0.0:
            raise ValueError("root storage coefficient must be positive")
        if self.lower_storage_coefficient <= 0.0:
            raise ValueError("lower storage coefficient must be positive")
        if self.vertical_conductance_per_day <= 0.0:
            raise ValueError("vertical conductance must be positive")
        if self.interface_conductance_per_day <= 0.0:
            raise ValueError("interface conductance must be positive")
        if self.root_capacity_m <= 0.0:
            raise ValueError("root capacity must be positive")
        if not (0.0 <= self.root_reference_storage_m <= self.root_capacity_m):
            raise ValueError("root reference storage must lie inside capacity")

    def root_head_m(self, root_storage_m: float) -> float:
        return self.root_reference_head_m + (
            root_storage_m - self.root_reference_storage_m
        ) / self.root_storage_coefficient

    def root_storage_m(self, root_head_m: float) -> float:
        return self.root_reference_storage_m + self.root_storage_coefficient * (
            root_head_m - self.root_reference_head_m
        )


@dataclass(frozen=True)
class RootZoneMemoryState:
    root_storage_m: float
    lower_head_m: float


@dataclass(frozen=True)
class RootZoneMemoryForcing:
    root_input_rate_m_per_day: float = 0.0
    lower_input_rate_m_per_day: float = 0.0


@dataclass(frozen=True)
class RootZoneMemoryResult:
    state: RootZoneMemoryState
    root_head_m: float
    interface_head_m: float
    vertical_exchange_m: float
    interface_exchange_m: float
    interface_exchange_from_ledger_m: float
    root_storage_change_m: float
    lower_storage_change_m: float
    swap_total_storage_change_m: float
    swap_external_input_m: float
    root_mass_error_m: float
    lower_mass_error_m: float
    swap_mass_error_m: float
    interface_exchange_route_error_m: float


@dataclass(frozen=True)
class CoupledWindowResult:
    interface_head_m: float
    swap: RootZoneMemoryResult
    groundwater_storage_change_m: float
    groundwater_mass_error_m: float
    complete_mass_error_m: float
    response_origin_head_m: float
    response_origin_exchange_m: float
    response_tangent_m_per_m: float


def _matvec(
    matrix: tuple[tuple[float, float], tuple[float, float]],
    vector: tuple[float, float],
) -> tuple[float, float]:
    return (
        matrix[0][0] * vector[0] + matrix[0][1] * vector[1],
        matrix[1][0] * vector[0] + matrix[1][1] * vector[1],
    )


def _matmul(
    left: tuple[tuple[float, float], tuple[float, float]],
    right: tuple[tuple[float, float], tuple[float, float]],
) -> tuple[tuple[float, float], tuple[float, float]]:
    return (
        (
            left[0][0] * right[0][0] + left[0][1] * right[1][0],
            left[0][0] * right[0][1] + left[0][1] * right[1][1],
        ),
        (
            left[1][0] * right[0][0] + left[1][1] * right[1][0],
            left[1][0] * right[0][1] + left[1][1] * right[1][1],
        ),
    )


def _inverse2(
    matrix: tuple[tuple[float, float], tuple[float, float]],
) -> tuple[tuple[float, float], tuple[float, float]]:
    a, b = matrix[0]
    c, d = matrix[1]
    det = a * d - b * c
    if det == 0.0 or not math.isfinite(det):
        raise ValueError("singular 2x2 matrix")
    inv = 1.0 / det
    return ((d * inv, -b * inv), (-c * inv, a * inv))


def _sub2(
    left: tuple[tuple[float, float], tuple[float, float]],
    right: tuple[tuple[float, float], tuple[float, float]],
) -> tuple[tuple[float, float], tuple[float, float]]:
    return (
        (left[0][0] - right[0][0], left[0][1] - right[0][1]),
        (left[1][0] - right[1][0], left[1][1] - right[1][1]),
    )


def _scale_add(
    alpha: float,
    left: tuple[tuple[float, float], tuple[float, float]],
    beta: float,
    right: tuple[tuple[float, float], tuple[float, float]],
) -> tuple[tuple[float, float], tuple[float, float]]:
    return (
        (
            alpha * left[0][0] + beta * right[0][0],
            alpha * left[0][1] + beta * right[0][1],
        ),
        (
            alpha * left[1][0] + beta * right[1][0],
            alpha * left[1][1] + beta * right[1][1],
        ),
    )


_ID = ((1.0, 0.0), (0.0, 1.0))


@dataclass(frozen=True)
class LinearRootZoneMemoryOracle:
    parameters: RootZoneMemoryParameters

    def __post_init__(self) -> None:
        self.parameters.validate()

    def system_matrix(
        self,
    ) -> tuple[tuple[float, float], tuple[float, float]]:
        p = self.parameters
        sr = p.root_storage_coefficient
        sl = p.lower_storage_coefficient
        cv = p.vertical_conductance_per_day
        cc = p.interface_conductance_per_day
        return (
            (-cv / sr, cv / sr),
            (cv / sl, -(cv + cc) / sl),
        )

    def eigenvalues_per_day(self) -> tuple[float, float]:
        a = self.system_matrix()
        trace_half = 0.5 * (a[0][0] + a[1][1])
        delta = math.sqrt(
            (0.5 * (a[0][0] - a[1][1])) ** 2 + a[0][1] * a[1][0]
        )
        slow = trace_half + delta
        fast = trace_half - delta
        if not (slow < 0.0 and fast < slow):
            raise ValueError("system is not strictly stable")
        return slow, fast

    def time_constants_day(self) -> tuple[float, float]:
        slow, fast = self.eigenvalues_per_day()
        return -1.0 / slow, -1.0 / fast

    def _matrix_exponential(
        self, dt_day: float
    ) -> tuple[tuple[float, float], tuple[float, float]]:
        if dt_day < 0.0 or not math.isfinite(dt_day):
            raise ValueError("matrix exponential requires finite nonnegative time")
        a = self.system_matrix()
        slow, fast = self.eigenvalues_per_day()
        gap = slow - fast
        if gap <= 0.0:
            raise ValueError("invalid eigenvalue ordering")
        # Cayley-Hamilton form uses only exp(negative number), avoiding the
        # exp(trace)*cosh(delta) overflow of an equivalent formula.
        a_minus_fast_i = (
            (a[0][0] - fast, a[0][1]),
            (a[1][0], a[1][1] - fast),
        )
        a_minus_slow_i = (
            (a[0][0] - slow, a[0][1]),
            (a[1][0], a[1][1] - slow),
        )
        return _scale_add(
            math.exp(slow * dt_day) / gap,
            a_minus_fast_i,
            -math.exp(fast * dt_day) / gap,
            a_minus_slow_i,
        )

    def _integral_exponential(
        self, dt_day: float
    ) -> tuple[tuple[float, float], tuple[float, float]]:
        a = self.system_matrix()
        e = self._matrix_exponential(dt_day)
        return _matmul(_inverse2(a), _sub2(e, _ID))

    def _forcing_vector(
        self, forcing: RootZoneMemoryForcing
    ) -> tuple[float, float]:
        p = self.parameters
        return (
            forcing.root_input_rate_m_per_day / p.root_storage_coefficient,
            forcing.lower_input_rate_m_per_day / p.lower_storage_coefficient,
        )

    def steady_offsets_m(
        self, forcing: RootZoneMemoryForcing
    ) -> tuple[float, float]:
        inv = _inverse2(self.system_matrix())
        raw = _matvec(inv, self._forcing_vector(forcing))
        return (-raw[0], -raw[1])

    def response_tangent_m_per_m(self, dt_day: float) -> float:
        self._validate_time(dt_day)
        m = self._integral_exponential(dt_day)
        lower_integral_sensitivity = m[1][0] + m[1][1]
        return (
            -self.parameters.interface_conductance_per_day
            * lower_integral_sensitivity
        )

    def solve_prescribed_interface(
        self,
        state0: RootZoneMemoryState,
        forcing: RootZoneMemoryForcing,
        interface_head_m: float,
        dt_day: float,
    ) -> RootZoneMemoryResult:
        self._validate_state_and_forcing(state0, forcing, interface_head_m, dt_day)

        p = self.parameters
        root_head0 = p.root_head_m(state0.root_storage_m)
        y0 = (root_head0 - interface_head_m, state0.lower_head_m - interface_head_m)
        ystar = self.steady_offsets_m(forcing)
        delta0 = (y0[0] - ystar[0], y0[1] - ystar[1])

        e = self._matrix_exponential(dt_day)
        evolved = _matvec(e, delta0)
        y1 = (ystar[0] + evolved[0], ystar[1] + evolved[1])

        root_head1 = interface_head_m + y1[0]
        lower_head1 = interface_head_m + y1[1]
        root_storage1 = p.root_storage_m(root_head1)

        self._validate_capacity_path(
            state0=state0,
            forcing=forcing,
            interface_head_m=interface_head_m,
            dt_day=dt_day,
            y0=y0,
            ystar=ystar,
        )

        m = self._integral_exponential(dt_day)
        integrated_delta = _matvec(m, delta0)
        integrated_y = (
            ystar[0] * dt_day + integrated_delta[0],
            ystar[1] * dt_day + integrated_delta[1],
        )
        vertical_exchange = p.vertical_conductance_per_day * (
            integrated_y[0] - integrated_y[1]
        )
        interface_exchange = p.interface_conductance_per_day * integrated_y[1]

        root_change = root_storage1 - state0.root_storage_m
        lower_change = p.lower_storage_coefficient * (
            lower_head1 - state0.lower_head_m
        )
        root_external = forcing.root_input_rate_m_per_day * dt_day
        lower_external = forcing.lower_input_rate_m_per_day * dt_day
        root_error = root_change - (root_external - vertical_exchange)
        lower_error = lower_change - (
            lower_external + vertical_exchange - interface_exchange
        )
        swap_change = root_change + lower_change
        swap_external = root_external + lower_external
        swap_error = swap_change - (swap_external - interface_exchange)
        interface_from_ledger = swap_external - swap_change
        route_error = interface_exchange - interface_from_ledger

        return RootZoneMemoryResult(
            state=RootZoneMemoryState(
                root_storage_m=root_storage1,
                lower_head_m=lower_head1,
            ),
            root_head_m=root_head1,
            interface_head_m=interface_head_m,
            vertical_exchange_m=vertical_exchange,
            interface_exchange_m=interface_exchange,
            interface_exchange_from_ledger_m=interface_from_ledger,
            root_storage_change_m=root_change,
            lower_storage_change_m=lower_change,
            swap_total_storage_change_m=swap_change,
            swap_external_input_m=swap_external,
            root_mass_error_m=root_error,
            lower_mass_error_m=lower_error,
            swap_mass_error_m=swap_error,
            interface_exchange_route_error_m=route_error,
        )

    def solve_coupled_modflow_storage_window(
        self,
        state0: RootZoneMemoryState,
        forcing: RootZoneMemoryForcing,
        dt_day: float,
        groundwater_head0_m: float,
        groundwater_storage_coefficient: float,
        groundwater_external_input_m: float = 0.0,
        response_origin_head_m: float | None = None,
    ) -> CoupledWindowResult:
        if (
            not math.isfinite(groundwater_head0_m)
            or not math.isfinite(groundwater_storage_coefficient)
            or not math.isfinite(groundwater_external_input_m)
        ):
            raise ValueError("groundwater inputs must be finite")
        if groundwater_storage_coefficient <= 0.0:
            raise ValueError("groundwater storage coefficient must be positive")
        origin = (
            groundwater_head0_m
            if response_origin_head_m is None
            else response_origin_head_m
        )
        origin_result = self.solve_prescribed_interface(
            state0, forcing, origin, dt_day
        )
        tangent = self.response_tangent_m_per_m(dt_day)

        denominator = groundwater_storage_coefficient - tangent
        if denominator <= 0.0 or not math.isfinite(denominator):
            raise ValueError("singular coupled finite-window residual")
        head = (
            groundwater_storage_coefficient * groundwater_head0_m
            + groundwater_external_input_m
            + origin_result.interface_exchange_m
            - tangent * origin
        ) / denominator

        accepted = self.solve_prescribed_interface(state0, forcing, head, dt_day)
        groundwater_change = groundwater_storage_coefficient * (
            head - groundwater_head0_m
        )
        groundwater_error = groundwater_change - (
            groundwater_external_input_m + accepted.interface_exchange_m
        )
        complete_error = (
            accepted.swap_total_storage_change_m
            + groundwater_change
            - accepted.swap_external_input_m
            - groundwater_external_input_m
        )
        return CoupledWindowResult(
            interface_head_m=head,
            swap=accepted,
            groundwater_storage_change_m=groundwater_change,
            groundwater_mass_error_m=groundwater_error,
            complete_mass_error_m=complete_error,
            response_origin_head_m=origin,
            response_origin_exchange_m=origin_result.interface_exchange_m,
            response_tangent_m_per_m=tangent,
        )

    def _validate_capacity_path(
        self,
        *,
        state0: RootZoneMemoryState,
        forcing: RootZoneMemoryForcing,
        interface_head_m: float,
        dt_day: float,
        y0: tuple[float, float],
        ystar: tuple[float, float],
    ) -> None:
        p = self.parameters
        slow, fast = self.eigenvalues_per_day()
        delta0 = (y0[0] - ystar[0], y0[1] - ystar[1])
        deriv0 = _matvec(self.system_matrix(), delta0)[0]
        coeff_slow = (deriv0 - fast * delta0[0]) / (slow - fast)
        coeff_fast = delta0[0] - coeff_slow

        candidate_times = [0.0, dt_day]
        numerator = -coeff_fast * fast
        denominator = coeff_slow * slow
        if numerator > 0.0 and denominator > 0.0:
            ratio = numerator / denominator
            tcrit = math.log(ratio) / (slow - fast)
            if 0.0 < tcrit < dt_day:
                candidate_times.append(tcrit)

        for t in candidate_times:
            root_offset = (
                ystar[0]
                + coeff_slow * math.exp(slow * t)
                + coeff_fast * math.exp(fast * t)
            )
            root_head = interface_head_m + root_offset
            root_storage = p.root_storage_m(root_head)
            tol = 32.0 * math.ulp(max(1.0, abs(p.root_capacity_m)))
            if root_storage < -tol or root_storage > p.root_capacity_m + tol:
                raise ValueError("root-zone capacity bound crossed within window")

    def _validate_state_and_forcing(
        self,
        state0: RootZoneMemoryState,
        forcing: RootZoneMemoryForcing,
        interface_head_m: float,
        dt_day: float,
    ) -> None:
        self._validate_time(dt_day)
        values = (
            state0.root_storage_m,
            state0.lower_head_m,
            forcing.root_input_rate_m_per_day,
            forcing.lower_input_rate_m_per_day,
            interface_head_m,
        )
        if not all(math.isfinite(v) for v in values):
            raise ValueError("state and forcing must be finite")
        if not (0.0 <= state0.root_storage_m <= self.parameters.root_capacity_m):
            raise ValueError("committed root storage outside capacity")

    @staticmethod
    def _validate_time(dt_day: float) -> None:
        if not math.isfinite(dt_day) or dt_day <= 0.0:
            raise ValueError("dt_day must be finite and positive")
