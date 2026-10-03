"""Exercise only the exact RFM centered-FD predictor initialization; no MODFLOW run."""
import ctypes,os,sys
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'fgc'))
from test_fgc45_real_multiswap_modflow_end_to_end import Fgc45RealMultiSwap

head=float(os.environ.get('A28_H0_CM','-45'))
dt=float(os.environ.get('A28_DT_DAY','.01'))
rain=float(os.environ.get('A28_RAIN_CM_DAY','0'))
bridge=os.environ['FGC45_MULTISWAP_LIB']
lib=ctypes.CDLL(bridge)
lib.a28_set_policy_c.argtypes=[ctypes.c_int];lib.a28_set_policy_c.restype=ctypes.c_int
lib.a28_set_fixture_c.argtypes=[ctypes.c_double]*3;lib.a28_set_fixture_c.restype=ctypes.c_int
assert lib.a28_set_policy_c(0)==0, 'exact fixed-64 policy setup failed'
assert lib.a28_set_fixture_c(head,dt,rain)==0, 'fixture setup failed'
swap=Fgc45RealMultiSwap(bridge)
hcof,rhs,href=swap.initialize()
assert all(map(lambda x: x==x and abs(x)<float('inf'),(hcof,rhs,href)))
print(f'EXACT_RFM_FD_PREDICTOR_INIT=PASS h0_cm={head} dt_day={dt} rain_cm_day={rain} hcof={hcof:.17g} rhs={rhs:.17g} href_m={href:.17g}')
