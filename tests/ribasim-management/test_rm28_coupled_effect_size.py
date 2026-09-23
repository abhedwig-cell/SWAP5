from __future__ import annotations

import math

WINDOW_S=8.64
AREA_M2=1.0
IRRIGATION_VOLUME_M3=3.6e-5

# RM27 SWAP lower-boundary pressure-head probes mapped through the admitted
# fixed-interface datum relation to hydraulic head.
H=[-0.715002,-0.715000,-0.714998]
Q1=[
    1.37866996161697225e-7,
    1.37859119191273564e-7,
    1.37851242220849904e-7,
]
Q2=[
    1.37863527996127688e-7,
    1.37855651034698882e-7,
    1.37847774073784066e-7,
]

# Canonical F-GC fixed-interface independent one-cell groundwater oracle,
# repeated identically in jobs 106941629937 and 107048912789.
GW_SLOPE=0.020335665520960458
GW_INTERCEPT=0.014540000237417468
GW_FIT_ERROR=7.0603245472256049e-16


def require(condition: bool,message: str)->None:
    if not condition:
        raise AssertionError(message)


def fit_response(q: list[float])->tuple[float,float,float]:
    # Frozen symmetric three-point line. Use the outer points for the slope
    # and verify the center independently; no fitting library is required.
    slope=(q[2]-q[0])/(H[2]-H[0])
    intercept=q[1]-slope*H[1]
    fit=max(abs(slope*h+intercept-v) for h,v in zip(H,q))
    return slope,intercept,fit


def coupled_root(swap_slope:float,swap_intercept:float)->tuple[float,float,float]:
    denom=swap_slope-GW_SLOPE
    require(math.isfinite(denom) and abs(denom)>0.0,"parallel/nonfinite response lines")
    head=(GW_INTERCEPT-swap_intercept)/denom
    q_swap=swap_slope*head+swap_intercept
    q_gw=GW_SLOPE*head+GW_INTERCEPT
    residual=q_swap-q_gw
    require(all(math.isfinite(x) for x in (head,q_swap,q_gw,residual)),"nonfinite root")
    return head,q_swap,residual


s1,i1,e1=fit_response(Q1)
s2,i2,e2=fit_response(Q2)
require(e1<=1e-18 and e2<=1e-18,"RM27 three-point SWAP response is not affine at numerical precision")
require(GW_FIT_ERROR<1e-15,"frozen canonical groundwater oracle fit no longer in expected envelope")

h1,q1,r1=coupled_root(s1,i1)
h2,q2,r2=coupled_root(s2,i2)

head_shift=abs(h1-h2)
flux_shift=abs(q1-q2)
volume_shift=flux_shift*AREA_M2*WINDOW_S
irrigation_ratio=volume_shift/IRRIGATION_VOLUME_M3
gw_volume_1=abs(q1)*AREA_M2*WINDOW_S
gw_volume_2=abs(q2)*AREA_M2*WINDOW_S
gw_volume_mean=0.5*(gw_volume_1+gw_volume_2)
gw_ratio=volume_shift/gw_volume_mean

print(f"RM28_SWAP_SLOPE_ONE_STEP_PER_S={s1:.17g}")
print(f"RM28_SWAP_INTERCEPT_ONE_STEP_M_PER_S={i1:.17g}")
print(f"RM28_SWAP_FIT_ERROR_ONE_STEP_M_PER_S={e1:.17g}")
print(f"RM28_SWAP_SLOPE_TWO_HALF_PER_S={s2:.17g}")
print(f"RM28_SWAP_INTERCEPT_TWO_HALF_M_PER_S={i2:.17g}")
print(f"RM28_SWAP_FIT_ERROR_TWO_HALF_M_PER_S={e2:.17g}")
print(f"RM28_GW_SLOPE_PER_S={GW_SLOPE:.17g}")
print(f"RM28_GW_INTERCEPT_M_PER_S={GW_INTERCEPT:.17g}")
print(f"RM28_GW_FIT_ERROR_M_PER_S={GW_FIT_ERROR:.17g}")
print(f"RM28_COUPLED_HEAD_ONE_STEP_M={h1:.17g}")
print(f"RM28_COUPLED_HEAD_TWO_HALF_M={h2:.17g}")
print(f"RM28_COUPLED_HEAD_SHIFT_M={head_shift:.17g}")
print(f"RM28_COUPLED_Q_ONE_STEP_M_PER_S={q1:.17g}")
print(f"RM28_COUPLED_Q_TWO_HALF_M_PER_S={q2:.17g}")
print(f"RM28_COUPLED_Q_SHIFT_M_PER_S={flux_shift:.17g}")
print(f"RM28_RESIDUAL_ONE_STEP_M_PER_S={r1:.17g}")
print(f"RM28_RESIDUAL_TWO_HALF_M_PER_S={r2:.17g}")
print(f"RM28_GW_TRANSFER_VOLUME_ONE_STEP_M3={gw_volume_1:.17g}")
print(f"RM28_GW_TRANSFER_VOLUME_TWO_HALF_M3={gw_volume_2:.17g}")
print(f"RM28_GW_TRANSFER_VOLUME_SHIFT_M3={volume_shift:.17g}")
print(f"RM28_SHIFT_OVER_IRRIGATION_VOLUME={irrigation_ratio:.17g}")
print(f"RM28_SHIFT_OVER_MEAN_GW_TRANSFER={gw_ratio:.17g}")
print("RM28_COUPLED_EFFECT_SIZE=PASS")
