#!/usr/bin/env python3
"""Research-only harness for SWAP5 reduced macropore parameterization.

F-MACRO-ALT05..07:
- continuous connectivity compression of IC-domain endpoint depths;
- lognormal matrix-infiltrability activation partition;
- no production SWAP physics mutation.

Standard-library only by design.
"""

from __future__ import annotations

import json
import math
from dataclasses import asdict, dataclass


@dataclass
class ConnectivityFit:
    scale_cm: float
    shape: float
    rms_survival_error: float
    max_survival_error: float


def normal_cdf(x: float) -> float:
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


def lognormal_activation(rain_rate: float, median_infiltrability: float, sigma_ln: float) -> tuple[float, float]:
    """Return matrix and preferential partition for B~lognormal.

    Matrix uptake is E[min(rain_rate, B)].
    Preferential input is the complement.
    """
    if rain_rate <= 0.0:
        return 0.0, 0.0
    if median_infiltrability <= 0.0 or sigma_ln <= 0.0:
        raise ValueError("median_infiltrability and sigma_ln must be positive")

    mu = math.log(median_infiltrability)
    log_r = math.log(rain_rate)
    z_trunc = (log_r - mu - sigma_ln * sigma_ln) / sigma_ln
    z_tail = (log_r - mu) / sigma_ln

    truncated_mean = math.exp(mu + 0.5 * sigma_ln * sigma_ln) * normal_cdf(z_trunc)
    matrix = truncated_mean + rain_rate * (1.0 - normal_cdf(z_tail))
    matrix = min(rain_rate, max(0.0, matrix))
    return matrix, rain_rate - matrix


def empirical_survival(endpoint_depths_cm: list[float], depth_cm: float) -> float:
    if not endpoint_depths_cm:
        return 0.0
    return sum(d >= depth_cm for d in endpoint_depths_cm) / len(endpoint_depths_cm)


def weibull_survival(depth_cm: float, scale_cm: float, shape: float) -> float:
    if depth_cm <= 0.0:
        return 1.0
    return math.exp(-((depth_cm / scale_cm) ** shape))


def fit_weibull_survival(endpoint_depths_cm: list[float]) -> ConnectivityFit:
    """Coarse deterministic grid fit; sufficient for a research compression screen."""
    if not endpoint_depths_cm:
        raise ValueError("endpoint_depths_cm cannot be empty")

    max_depth = max(endpoint_depths_cm)
    grid = [max_depth * i / 180.0 for i in range(181)]
    empirical = [empirical_survival(endpoint_depths_cm, z) for z in grid]

    best = None
    for scale_i in range(200, 1001, 2):  # 20.0 .. 100.0 cm
        scale = scale_i / 10.0
        for shape_i in range(5, 401, 2):  # 0.05 .. 4.00
            shape = shape_i / 100.0
            errors = [
                weibull_survival(z, scale, shape) - s
                for z, s in zip(grid, empirical)
            ]
            mse = sum(e * e for e in errors) / len(errors)
            if best is None or mse < best[0]:
                best = (mse, scale, shape, max(abs(e) for e in errors))

    assert best is not None
    mse, scale, shape, max_error = best
    return ConnectivityFit(
        scale_cm=scale,
        shape=shape,
        rms_survival_error=math.sqrt(mse),
        max_survival_error=max_error,
    )


def main() -> None:
    # SWAP manual example: four IC subdomains plus Ah subdomain.
    endpoint_depths_cm = [85.0, 54.2, 35.6, 26.9, 25.0]
    fit = fit_weibull_survival(endpoint_depths_cm)

    activation = []
    for rain_rate in [1.0, 4.0, 8.0, 15.0, 30.0, 60.0]:
        matrix, preferential = lognormal_activation(
            rain_rate=rain_rate,
            median_infiltrability=8.0,
            sigma_ln=0.65,
        )
        activation.append(
            {
                "rain_rate": rain_rate,
                "matrix": matrix,
                "preferential": preferential,
                "preferential_fraction": preferential / rain_rate,
            }
        )

    result = {
        "schema": "swap5.macropore_alt05_07_harness.v1",
        "status": "RESEARCH_ONLY",
        "connectivity_example": {
            "source": "SWAP manual Figure 6.7 example endpoint depths",
            "endpoint_depths_cm": endpoint_depths_cm,
            "weibull_fit": asdict(fit),
            "interpretation": (
                "A two-parameter continuous survival function approximates the "
                "legacy discrete endpoint distribution. This demonstrates compression "
                "feasibility, not production equivalence."
            ),
        },
        "activation_example": {
            "median_matrix_infiltrability": 8.0,
            "sigma_ln": 0.65,
            "units": "arbitrary consistent flux units",
            "rows": activation,
            "interpretation": (
                "Preferential partition rises continuously with source intensity "
                "without a fixed bypass fraction or hard activation threshold."
            ),
        },
    }
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
