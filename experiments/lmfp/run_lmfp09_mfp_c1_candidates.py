from __future__ import annotations

import bisect
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_coordinate_envelope as gate_a
import run_lmfp09_homogeneous_face_matrix as b1

H_SCALE = 0.01
NODES = 128
HMIN = -1.0e8
HMAX = 100.0
HEADS = (-0.05, -0.02, -0.015, -0.01, -0.008, -0.006, -0.005, -0.003,
         -0.001, 0.0, 0.001, 0.01)
LENGTHS = (10.0, 20.0)
EPS_LARGE = 1.0e-3
EPS_SMALL = 2.0e-4


def percentile(values, p):
    values = sorted(values)
    if not values:
        return math.nan
    return values[min(len(values)-1, int(p*len(values)))]


def relerr(a, b, floor=1.0e-12):
    return abs(a-b)/max(abs(b), floor)


class HermiteMFPTable:
    """C1 Phi(x) table on the F-LMFP09 asinh coordinate.

    Nodal derivatives start from dPhi/dx = K(h) dh/dx. The limited variant applies
    a global monotonic cubic-Hermite limiter only where required to keep Phi
    monotone. Positive heads remain analytic: Phi=Phi(0)+Ks*h.
    """
    def __init__(self, mat, coordinate, n=NODES, limited=False):
        self.mat = mat
        self.coordinate = coordinate
        self.n = int(n)
        self.limited = bool(limited)
        self.x0 = coordinate.x(0.0)
        self.xs = [coordinate.xmin + (self.x0-coordinate.xmin)*i/(n-1)
                   for i in range(n)]
        self.heads = [coordinate.h(x) for x in self.xs]
        self.heads[-1] = 0.0
        self.phi = [0.0]
        for a,b in zip(self.heads[:-1], self.heads[1:]):
            self.phi.append(self.phi[-1] + gate_a.integrate_k(mat, a, b))
        self.phi0 = self.phi[-1]
        self.ks = mat.conductivity(0.0)
        self.slopes = [mat.conductivity(h) * math.sqrt(h*h + coordinate.hscale**2)
                       for h in self.heads]
        self.initial_slopes = list(self.slopes)
        if self.limited:
            self._limit_monotone()
        self.saturation_endpoint_slope_rel_error = relerr(
            self.slopes[-1], self.ks*coordinate.hscale, 1.0e-300)

    def _limit_monotone(self):
        # Fritsch-Carlson circle limiter applied iteratively to shared nodal slopes.
        # Slopes are only reduced, never sign-flipped.
        for _ in range(8):
            changed = False
            for i in range(self.n-1):
                dx = self.xs[i+1]-self.xs[i]
                delta = (self.phi[i+1]-self.phi[i])/dx
                if not delta > 0.0:
                    raise RuntimeError(("nonpositive_phi_secant", i, delta))
                a = max(0.0, self.slopes[i]/delta)
                b = max(0.0, self.slopes[i+1]/delta)
                s = a*a+b*b
                if s > 9.0:
                    tau = 3.0/math.sqrt(s)
                    ni = tau*a*delta
                    nj = tau*b*delta
                    if ni < self.slopes[i]*(1.0-1.0e-15):
                        self.slopes[i] = ni; changed = True
                    if nj < self.slopes[i+1]*(1.0-1.0e-15):
                        self.slopes[i+1] = nj; changed = True
            if not changed:
                break

    def _segment(self, h):
        x = self.coordinate.x(h)
        i = bisect.bisect_right(self.xs, x)-1
        i = max(0, min(i, self.n-2))
        x0,x1 = self.xs[i],self.xs[i+1]
        t = (x-x0)/(x1-x0)
        return x,i,x0,x1,t

    def _eval_x(self, h):
        x,i,x0,x1,t = self._segment(h)
        dx=x1-x0
        y0,y1=self.phi[i],self.phi[i+1]
        m0,m1=self.slopes[i],self.slopes[i+1]
        h00=2*t**3-3*t**2+1
        h10=t**3-2*t**2+t
        h01=-2*t**3+3*t**2
        h11=t**3-t**2
        y=h00*y0+h10*dx*m0+h01*y1+h11*dx*m1
        dh00=6*t*t-6*t
        dh10=3*t*t-4*t+1
        dh01=-6*t*t+6*t
        dh11=3*t*t-2*t
        dydx=(dh00*y0+dh10*dx*m0+dh01*y1+dh11*dx*m1)/dx
        return y,dydx,i,t

    def value(self,h):
        if h < self.coordinate.hmin or h > self.coordinate.hmax:
            raise ValueError(("head_out_of_range",h,self.coordinate.hmin,self.coordinate.hmax))
        if h >= 0.0:
            return self.phi0+self.ks*h
        return self._eval_x(h)[0]

    def limit_k(self,h):
        if h < self.coordinate.hmin or h > self.coordinate.hmax:
            raise ValueError(("head_out_of_range",h,self.coordinate.hmin,self.coordinate.hmax))
        if h >= 0.0:
            return self.ks
        _,dydx,_,_=self._eval_x(h)
        return dydx*self.coordinate.dxdh(h)

    def secant_k(self,h1,h2):
        scale=max(1.0,abs(h1),abs(h2))
        if abs(h1-h2) <= 1.0e-14*scale:
            return self.limit_k(0.5*(h1+h2))
        return (self.value(h1)-self.value(h2))/(h1-h2)

    def positivity_diagnostic(self):
        minimum=math.inf
        nonpositive=0
        for i in range(self.n-1):
            x0,x1=self.xs[i],self.xs[i+1]
            for j in range(11):
                x=x0+(x1-x0)*j/10.0
                h=self.coordinate.h(x)
                k=self.limit_k(h if h < 0.0 else -1.0e-16)
                minimum=min(minimum,k)
                if not (math.isfinite(k) and k>0.0):
                    nonpositive+=1
        return {"minimum_k":minimum,"nonpositive_samples":nonpositive,
                "pass":nonpositive==0 and minimum>0.0}


def build_reference_pairs():
    pairs=gate_a.probe_pairs()
    out={}
    for fixture in gate_a.FIXTURES:
        rows=[]
        for a,b in pairs:
            integ=gate_a.integrate_k(fixture.material,b,a)
            refk=integ/(a-b)
            rows.append(((a,b),refk))
        out[fixture.name]=rows
    return out


def refinement_ratio(qfun,g0):
    q0=qfun(g0)
    large=max(abs(qfun(g0-EPS_LARGE)-q0),abs(qfun(g0+EPS_LARGE)-q0))
    small=max(abs(qfun(g0-EPS_SMALL)-q0),abs(qfun(g0+EPS_SMALL)-q0))
    return 0.0 if large<1.0e-14 and small<1.0e-14 else small/max(large,1.0e-300)


def evaluate(kind, limited, references):
    coord=gate_a.AsinhCoordinate(H_SCALE,hmin=HMIN,hmax=HMAX)
    tabs={f.name:HermiteMFPTable(f.material,coord,NODES,limited=limited)
          for f in gate_a.FIXTURES}
    sec=[]; deriv=[]; positivity=[]; endpoint=[]
    for f in gate_a.FIXTURES:
        tab=tabs[f.name]
        for (a,b),refk in references[f.name]:
            sec.append(relerr(tab.secant_k(a,b),refk))
        for h in gate_a.near_equal_heads():
            deriv.append(relerr(tab.limit_k(h),f.material.conductivity(h)))
        positivity.append(tab.positivity_diagnostic())
        endpoint.append(tab.saturation_endpoint_slope_rel_error)

    # Attribute near-saturation refinement against the direct steady-Darcy oracle.
    oracle_over=0; table_over=0; spurious=0; rows=[]
    active={f.name:f for f in gate_a.FIXTURES if f.name in ("reference_sand","reference_clay")}
    for name in ("reference_sand","reference_clay"):
        f=active[name]; tab=tabs[name]; mat=f.material
        for length in LENGTHS:
            for h in HEADS:
                for g0 in (0.0,1.0):
                    qo=lambda g:b1.direct_flux(mat,h,h+g*length,length)
                    qm=lambda g:tab.secant_k(h,h+g*length)*(1.0-g)
                    ro=refinement_ratio(qo,g0); rm=refinement_ratio(qm,g0)
                    if ro>0.35: oracle_over+=1
                    if rm>0.35: table_over+=1
                    if ro<=0.35 and rm>0.35: spurious+=1
                    rows.append({"material":name,"length_cm":length,"h_upper_cm":h,
                                 "g_center":g0,"oracle_small_over_large":ro,
                                 "mfp_small_over_large":rm,
                                 "oracle_generic_smooth":ro<=0.35})

    stats={
        "candidate":kind,
        "nodes":NODES,
        "hscale_cm":H_SCALE,
        "mfp_secant_rel_error":{"median":percentile(sec,0.5),"p90":percentile(sec,0.9),
                                "p99":percentile(sec,0.99),"maximum":max(sec)},
        "limit_k_rel_error":{"median":percentile(deriv,0.5),"p90":percentile(deriv,0.9),
                             "maximum":max(deriv)},
        "positivity":{"pass":all(x["pass"] for x in positivity),
                      "minimum_k":min(x["minimum_k"] for x in positivity),
                      "nonpositive_samples":sum(x["nonpositive_samples"] for x in positivity)},
        "saturation_endpoint_slope_max_rel_error":max(endpoint),
        "near_saturation_refinement":{"oracle_rows_over_0p35":oracle_over,
                                      "candidate_rows_over_0p35":table_over,
                                      "spurious_candidate_rows_where_oracle_smooth":spurious,
                                      "rows":rows},
    }
    stats["pass"]=(
        stats["positivity"]["pass"]
        and stats["saturation_endpoint_slope_max_rel_error"] < 1.0e-12
        and stats["mfp_secant_rel_error"]["p90"] < 0.01
        and stats["mfp_secant_rel_error"]["p99"] < 0.08
        and stats["mfp_secant_rel_error"]["maximum"] < 0.25
        and stats["limit_k_rel_error"]["p90"] < 0.10
        and stats["limit_k_rel_error"]["maximum"] < 0.35
        and spurious == 0
    )
    return stats


def main():
    if len(sys.argv)!=2:
        raise SystemExit("usage: run_lmfp09_mfp_c1_candidates.py EVIDENCE_JSON")
    refs=build_reference_pairs()
    candidates=[
        evaluate("EXACT_SLOPE_HERMITE_PHI_X",False,refs),
        evaluate("MONOTONICITY_LIMITED_HERMITE_PHI_X",True,refs),
    ]
    passing=[c for c in candidates if c["pass"]]
    evidence={
        "schema_version":1,
        "work_unit":"F-LMFP09",
        "subgate":"B0_MFP_BASELINE_C1_REPRESENTATION",
        "coordinate":"x=asinh(h/0.01 cm)",
        "head_envelope_cm":[HMIN,HMAX],
        "nodes":NODES,
        "candidates":candidates,
        "passing_candidates":[c["candidate"] for c in passing],
        "selection":passing[0]["candidate"] if passing else None,
        "structural_pass":bool(passing),
        "production_admission":False,
        "interpretation":"C1 MFP baseline must remove representation-induced near-saturation non-smoothness without smoothing away direct-Darcy regime-switch evidence; oracle-nonsmooth rows are diagnostic and do not count as spurious representation failures."
    }
    Path(sys.argv[1]).write_text(json.dumps(evidence,indent=2,sort_keys=True)+"\n")
    print(json.dumps(evidence,indent=2,sort_keys=True))
    raise SystemExit(0 if evidence["structural_pass"] else 1)

if __name__=="__main__":
    main()
