#!/usr/bin/env python3
import math

DZ = [0.5, 0.5, 1.0, 1.0]
CAP = 0.001
K = 0.01
EIG1 = 0.25619777153614321838009463228648061698
EIG2 = 1.5788967897778011939109549498314371066
L1 = 2.5619777153614321838009463228648061698
L2 = 15.788967897778011939109549498314371066
V1 = [0.6752098721931038, 0.5887162399055651, 0.4268087132525549, 0.1555537453920313]
V2 = [-0.85993755826055324873547636713317468951,
      -0.18106123318707904408753054543225232895,
       0.64075359180253965173186093246533823150,
       0.45088462765653286067989087747721881613]
A_OVER_K = [
    [1.0, -1.0, 0.0, 0.0],
    [-1.0, 2.0, -1.0, 0.0],
    [0.0, -1.0, 2.0, -1.0],
    [0.0, 0.0, -1.0, 3.0],
]
SINGLE_X = [0.025, 0.1, 0.4, 1.6, 6.4]
SINGLE_EXPECTED_RATIO = [
    1.0167886580681464,
    1.0686409085462310,
    1.2997154238127544,
    2.0725731932112820,
    5.6040397392455910,
]
MULTI_DT = [0.0125, 0.05, 0.2, 0.8, 1.6]
MULTI_EXPECTED_RATIO = [
    1.1390965391368788,
    1.6584662296311474,
    2.7548583547850100,
    3.5867115108339060,
    4.9619307279126330,
]


def require(condition, label):
    if not condition:
        raise SystemExit("FVQ30_G02_FAIL " + label)


def dot(a, b):
    return sum(x*y for x, y in zip(a, b))


def matvec(a, x):
    return [sum(row[j]*x[j] for j in range(4)) for row in a]


def mnorm(x):
    return math.sqrt(sum(CAP*DZ[i]*x[i]*x[i] for i in range(4)))


def maxabs(x):
    return max(abs(v) for v in x)


def close(a, b, scale=1.0):
    return abs(a-b) <= 2.0e-12*max(1.0, abs(scale), abs(a), abs(b))


for eig, vec in ((EIG1, V1), (EIG2, V2)):
    av = matvec(A_OVER_K, vec)
    ev = [eig*DZ[i]*vec[i] for i in range(4)]
    require(maxabs([av[i]-ev[i] for i in range(4)]) < 5.0e-15, "generalized eigenpair")

require(close(L1, (K/CAP)*EIG1, L1), "lambda1 construction")
require(close(L2, (K/CAP)*EIG2, L2), "lambda2 construction")
require(abs(sum(DZ[i]*V1[i]*V2[i] for i in range(4))) < 5.0e-16, "M orthogonality")

amp1 = 5.0
amp2 = L1*amp1*V1[1]/(-L2*V2[1])
hdot2 = -L1*amp1*V1[1] - L2*amp2*V2[1]
require(abs(hdot2) < 5.0e-15, "predeclared near-zero derivative node")

for i, x in enumerate(SINGLE_X, 1):
    a = 10.0
    ube = [a*v/(1.0+x) for v in V1]
    uexact = [a*v*math.exp(-x) for v in V1]
    eraw = [0.5*a*v*x*x/(1.0+x) for v in V1]
    delta = [0.5*a*v*x*x/(1.0+x)**2 for v in V1]
    exact = [ube[j]-uexact[j] for j in range(4)]
    raw_m = mnorm(eraw)
    double_m = 2.0*mnorm(delta)
    bm = min(raw_m, double_m)
    exact_m = mnorm(exact)
    binf = bm/math.sqrt(min(CAP*d for d in DZ))
    exact_inf = maxabs(exact)
    ratio = bm/exact_m
    require(exact_m <= bm + 2.0e-14, f"single {i} M bound")
    require(exact_inf <= binf + 2.0e-12, f"single {i} infinity bound")
    require(close(ratio, SINGLE_EXPECTED_RATIO[i-1], ratio), f"single {i} owner-result regression")
    expected_route = "RAW" if x < 1.0 else "DOUBLE_DEFECT"
    route = "RAW" if raw_m <= double_m else "DOUBLE_DEFECT"
    require(route == expected_route, f"single {i} route")
    print(f"FVQ30_G02_SINGLE:POINT={i}:X={x:.17e}:ROUTE={route}:COMBINED_OVER_EXACT={ratio:.17e}")

for i, dt in enumerate(MULTI_DT, 1):
    x1 = L1*dt
    x2 = L2*dt
    ube = [amp1*V1[j]/(1.0+x1) + amp2*V2[j]/(1.0+x2) for j in range(4)]
    uexact = [amp1*V1[j]*math.exp(-x1) + amp2*V2[j]*math.exp(-x2) for j in range(4)]
    eraw = [0.5*amp1*V1[j]*x1*x1/(1.0+x1) + 0.5*amp2*V2[j]*x2*x2/(1.0+x2) for j in range(4)]
    delta = [0.5*amp1*V1[j]*x1*x1/(1.0+x1)**2 + 0.5*amp2*V2[j]*x2*x2/(1.0+x2)**2 for j in range(4)]
    exact = [ube[j]-uexact[j] for j in range(4)]
    raw_m = mnorm(eraw)
    double_m = 2.0*mnorm(delta)
    bm = min(raw_m, double_m)
    exact_m = mnorm(exact)
    binf = bm/math.sqrt(min(CAP*d for d in DZ))
    exact_inf = maxabs(exact)
    ratio = bm/exact_m
    require(exact_m <= bm + 2.0e-14, f"multi {i} M bound")
    require(exact_inf <= binf + 2.0e-12, f"multi {i} infinity bound")
    require(close(ratio, MULTI_EXPECTED_RATIO[i-1], ratio), f"multi {i} owner-result regression")
    print(f"FVQ30_G02_MULTI:POINT={i}:DT={dt:.17e}:COMBINED_OVER_EXACT={ratio:.17e}:RAW_OVER_DOUBLE={raw_m/double_m:.17e}")

print("FVQ30_G02_ANALYTIC_FACTOR=2")
print("FVQ30_G02_EMPIRICAL_FACTOR_FITTED=NO")
print("FVQ30_G02_EXACT_LINEAR_REGRESSION PASS")
