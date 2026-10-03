"""Exact/A28 run entry; retains original live FGC45 assertions."""
import ctypes,os,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/fgc'))
import test_fgc45_real_multiswap_modflow_end_to_end as live
lib=ctypes.CDLL(os.environ['FGC45_MULTISWAP_LIB'])
lib.a28_set_policy_c.argtypes=[ctypes.c_int];lib.a28_set_policy_c.restype=ctypes.c_int
assert lib.a28_set_policy_c(int(sys.argv[1]=='a28'))==0
live.main()
matrix=(ctypes.c_double*2)();rfm=(ctypes.c_double*2)()
lib.a28_storage_c(matrix,rfm)
print(f'A28_ACCEPTED_STORAGE matrix={list(matrix)} rfm={list(rfm)}')
counts=(ctypes.c_int*3)();panels=ctypes.c_int();hmin=ctypes.c_double();hmax=ctypes.c_double();seconds=ctypes.c_double()
lib.a28_sorptivity_stats_c(counts,ctypes.byref(panels),ctypes.byref(hmin),ctypes.byref(hmax),ctypes.byref(seconds))
print(f'A28_SORPTIVITY counts64={counts[0]} counts32={counts[1]} counts16={counts[2]} panels={panels.value} hmin_cm={hmin.value:.17g} hmax_cm={hmax.value:.17g} seconds={seconds.value:.17g}')
