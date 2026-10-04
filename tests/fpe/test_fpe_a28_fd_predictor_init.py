"""Exercise only the exact RFM centered-FD predictor initialization; no MODFLOW run."""
import ctypes,os,sys
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'fgc'/'support'))
from fgc45_real_multiswap_ctypes import Fgc45RealMultiSwap

head=float(os.environ.get('A28_H0_CM','-45'))
dt=float(os.environ.get('A28_DT_DAY','.01'))
rain=float(os.environ.get('A28_RAIN_CM_DAY','0'))
bridge=os.environ['FGC45_MULTISWAP_LIB']
lib=ctypes.CDLL(bridge)
lib.a28_set_policy_c.argtypes=[ctypes.c_int];lib.a28_set_policy_c.restype=ctypes.c_int
lib.a28_set_fixture_c.argtypes=[ctypes.c_double]*3;lib.a28_set_fixture_c.restype=ctypes.c_int
lib.a28_set_iteration_limit_c.argtypes=[ctypes.c_int];lib.a28_set_iteration_limit_c.restype=ctypes.c_int
lib.a28_set_solver_balance_tolerance_c.argtypes=[ctypes.c_double];lib.a28_set_solver_balance_tolerance_c.restype=ctypes.c_int
iteration_limit=int(os.environ.get('A28_NONLINEAR_ITERATION_LIMIT','16'))
solver_balance_tolerance=float(os.environ.get('A28_SOLVER_BALANCE_TOL_CM','1e-12'))
assert lib.a28_set_policy_c(0)==0, 'exact fixed-64 policy setup failed'
assert lib.a28_set_iteration_limit_c(iteration_limit)==0, 'test-only nonlinear iteration limit setup failed'
assert lib.a28_set_solver_balance_tolerance_c(solver_balance_tolerance)==0, 'test-only solver balance tolerance setup failed'
assert lib.a28_set_fixture_c(head,dt,rain)==0, 'fixture setup failed'
lib.a28_set_head_tolerances_c.argtypes=[ctypes.c_double,ctypes.c_double]
lib.a28_set_head_tolerances_c.restype=ctypes.c_int
HEAD_ABS=float(os.environ.get('A28_HEAD_ABS_TOL_CM','1e-12'))
HEAD_REL=float(os.environ.get('A28_HEAD_REL_TOL','1e-12'))
assert lib.a28_set_head_tolerances_c(HEAD_ABS,HEAD_REL)==0
swap=Fgc45RealMultiSwap(bridge)
hcof,rhs,href=swap.initialize()
assert all(map(lambda x: x==x and abs(x)<float('inf'),(hcof,rhs,href)))
print(f'EXACT_RFM_FD_PREDICTOR_INIT=PASS h0_cm={head} dt_day={dt} rain_cm_day={rain} max_iterations={iteration_limit} solver_balance_tol_cm={solver_balance_tolerance:.17g} head_abs_tol_cm={HEAD_ABS:.17g} head_rel_tol={HEAD_REL:.17g} hcof={hcof:.17g} rhs={rhs:.17g} href_m={href:.17g}')
