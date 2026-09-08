from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp08_physics_informed_correction as core


class LogDarcianRatioTable:
    """Immutable homogeneous correction table around the MFP secant closure.

    For a homogeneous face

        q_MFP = K_sec * (1-g)
        q_D   = K_DAR * (1-g)

    so the table stores

        R = log(K_DAR / K_sec) = log(q_D/q_MFP)

    away from the hydrostatic removable singularity. Runtime uses

        q = q_MFP * exp(R_interp).

    This preserves flow direction and positive effective conductivity. The
    equal-head gravity identity is imposed exactly with R=0 at g=0. The
    hydrostatic identity is imposed exactly by returning q=0 at g=1.
    """

    def __init__(self, code, length, x_axis=core.X_AXIS, g_axis=core.G_AXIS):
        self.code = int(code)
        self.length = float(length)
        self.x_axis = list(x_axis)
        self.g_axis = list(g_axis)
        self.values = []
        for x in self.x_axis:
            h_u = -10.0 ** x
            row = []
            for g in self.g_axis:
                row.append(self._log_ratio(h_u, g))
            self.values.append(row)

    def _raw_log_ratio(self, h_u, g):
        h_l = h_u + g * self.length
        qd = core.direct_homogeneous(self.code, h_u, h_l, self.length)
        qm = core.mfp_homogeneous(self.code, h_u, h_l, self.length)
        if qm == 0.0:
            raise ZeroDivisionError((h_u, g, qd, qm))
        ratio = qd / qm
        if not math.isfinite(ratio) or ratio <= 0.0:
            raise RuntimeError(("nonpositive Darcian/MFP conductivity ratio", self.code,
                                self.length, h_u, g, qd, qm, ratio))
        return math.log(ratio)

    def _log_ratio(self, h_u, g):
        if abs(g) < 1.0e-14:
            return 0.0
        if abs(g - 1.0) < 1.0e-14:
            eps = 2.0e-3
            return 0.5 * (self._raw_log_ratio(h_u, g - eps) +
                          self._raw_log_ratio(h_u, g + eps))
        return self._raw_log_ratio(h_u, g)

    def log_ratio(self, h_u, g):
        if h_u >= 0.0:
            raise ValueError(("upper_head_not_unsaturated", h_u))
        x = math.log10(-h_u)
        i0, i1 = core.bracket(self.x_axis, x)
        j0, j1 = core.bracket(self.g_axis, g)
        x0, x1 = self.x_axis[i0], self.x_axis[i1]
        g0, g1 = self.g_axis[j0], self.g_axis[j1]
        tx = 0.0 if x1 == x0 else (x - x0) / (x1 - x0)
        tg = 0.0 if g1 == g0 else (g - g0) / (g1 - g0)
        r00 = self.values[i0][j0]
        r10 = self.values[i1][j0]
        r11 = self.values[i1][j1]
        r01 = self.values[i0][j1]
        return ((1.0-tx)*(1.0-tg)*r00 + tx*(1.0-tg)*r10 +
                tx*tg*r11 + (1.0-tx)*tg*r01)

    def flux(self, h_u, h_l):
        g = (h_l - h_u) / self.length
        if abs(g) < 1.0e-14:
            return core.MATERIAL_BY_CODE[self.code].conductivity(h_u)
        if abs(g - 1.0) < 1.0e-14:
            return 0.0
        qm = core.mfp_homogeneous(self.code, h_u, h_l, self.length)
        return qm * math.exp(self.log_ratio(h_u, g))


# Replace only the experimental immutable representation. The conservative
# transient update, heterogeneous equal-flux MFP route, coverage behavior and
# qualification cases remain unchanged.
core.FactoredCorrectionTable = LogDarcianRatioTable

# Qualification-process analogue of shared immutable parameter storage.
_SHARED_TABLES = {}


def shared_table(self, code, length):
    key = (int(code), round(float(length), 12))
    if key not in _SHARED_TABLES:
        _SHARED_TABLES[key] = LogDarcianRatioTable(code, length)
    if key not in self.tables:
        self.tables[key] = _SHARED_TABLES[key]
        self.build_count += 1
    return self.tables[key]


core.CorrectionCache.table = shared_table


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_lmfp08_log_ratio.py FULLRICHARDS_OUTPUT EVIDENCE_JSON")

    identities = core.identity_tests()
    face = core.face_validation()
    response = core.response_diagnostics()
    transient = core.transient_matrix(Path(sys.argv[1]))
    structural = identities["pass"] and face["pass"] and response["pass"] and transient["pass"]

    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP08",
        "candidate": "MFP_TIMES_LOG_DARCIAN_CONDUCTIVITY_RATIO_ON_HOMOGENEOUS_FACES",
        "heterogeneous_faces": "current MFP equal-flux interface retained unchanged",
        "representation": {
            "formula": "q=q_MFP*exp(R(log10(-h_upper),g)); R=log(K_DAR/K_sec)",
            "g": "(h_lower-h_upper)/face_distance",
            "x_axis_points": len(core.X_AXIS),
            "g_axis_points": len(core.G_AXIS),
            "values_per_material_geometry_class": len(core.X_AXIS)*len(core.G_AXIS),
            "bytes_per_class_before_metadata": len(core.X_AXIS)*len(core.G_AXIS)*8,
            "equal_head_identity": "R(g=0)=0 and q=K(h) imposed exactly",
            "hydrostatic_identity": "q(g=1)=0 imposed exactly",
            "positive_effective_conductivity": "guaranteed by exp(R)",
            "flow_sign_relative_to_MFP": "preserved by positive multiplicative ratio",
        },
        "rejected_predecessor": {
            "candidate": "q=q_MFP+g*(g-1)*C(log10(-h_upper),g)",
            "evidence_run": 34267579445,
            "reason": "structural gate failed because transient strong-gradient improvement was only 3/5 despite exact identities and strong face-level aggregate improvement",
        },
        "tests": {
            "exact_identities": identities,
            "face_oracle_validation": face,
            "response_diagnostics": response,
            "transient_matrix": transient,
        },
        "structural_pass": structural,
        "interpretation": {
            "production_admission": "none",
            "response_tangent_admission": "none; finite-difference slope diagnostics only",
            "solver_policy": "candidate face law is explicit LayeredMFP model configuration, never an execution-policy fallback",
            "lookup_ownership": "immutable shared hydraulic parameter data by compatible material/geometry class",
        },
    }
    Path(sys.argv[2]).write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if structural else 1)


if __name__ == "__main__":
    main()
