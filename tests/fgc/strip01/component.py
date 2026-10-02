"""Fresh-process real SWAP component qualification before groundwater iteration."""
import argparse
import ctypes
import json
from pathlib import Path
import numpy as np


class Swap:
    def __init__(self,path):
        self.lib=ctypes.CDLL(str(Path(path).resolve()))
        ptr=ctypes.POINTER(ctypes.c_double); iptr=ctypes.POINTER(ctypes.c_int)
        for name in ["strip_initialize","strip_commit"]:
            f=getattr(self.lib,name);f.restype=ctypes.c_int;f.argtypes=[]
        self.lib.strip_initialize.argtypes=[ctypes.c_double]*3
        self.lib.strip_begin.restype=ctypes.c_int;self.lib.strip_begin.argtypes=[ctypes.c_double]
        self.lib.strip_trial.restype=ctypes.c_int;self.lib.strip_trial.argtypes=[ptr]*4
        self.lib.strip_state.restype=ctypes.c_int;self.lib.strip_state.argtypes=[iptr,ptr,ptr,ptr]
    def initialize(self,rain_cm_day=.1,initial_head_m=-4.5,elastic_per_cm=0):return self.lib.strip_initialize(rain_cm_day,initial_head_m,elastic_per_cm)
    def begin(self,dt):return self.lib.strip_begin(dt)
    def trial(self,head):
        vectors=[np.ascontiguousarray(head,dtype=np.float64),*[np.zeros(50) for _ in range(3)]]
        rc=self.lib.strip_trial(*[v.ctypes.data_as(ctypes.POINTER(ctypes.c_double)) for v in vectors])
        return rc,*vectors[1:]
    def state(self):
        rev=np.zeros(50,dtype=np.int32);values=[np.zeros(50) for _ in range(3)]
        rc=self.lib.strip_state(rev.ctypes.data_as(ctypes.POINTER(ctypes.c_int)),
                               *[v.ctypes.data_as(ctypes.POINTER(ctypes.c_double)) for v in values])
        assert rc==0
        return rev,*values
    def commit(self):return self.lib.strip_commit()


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--library",required=True)
    p.add_argument("--dt",type=float,required=True)
    p.add_argument("--head",type=float,default=-4.5)
    p.add_argument("--initial-head",type=float,default=-4.5)
    p.add_argument("--rain-cm-day",type=float,default=.1)
    p.add_argument("--elastic-per-cm",type=float,default=0)
    p.add_argument("--output",type=Path,required=True)
    a=p.parse_args(); s=Swap(a.library)
    rc=s.initialize(a.rain_cm_day,a.initial_head,a.elastic_per_cm);assert rc==0,rc
    before=s.state();rc=s.begin(a.dt);assert rc==0,rc
    status,q,delta,residual=s.trial(np.full(50,a.head))
    row=dict(dt_day=a.dt,head_m=a.head,initial_head_m=a.initial_head,rain_cm_day=a.rain_cm_day,elastic_per_cm=a.elastic_per_cm,trial_status=int(status),passed=False,
             initial_storage_m=before[2].tolist(),q_m_day=q.tolist(),delta_storage_m=delta.tolist(),
             residual_m=residual.tolist())
    assert all(np.array_equal(v,w) for v,w in zip(before,s.state())),"trial changed committed state"
    row["committed_state_unchanged_after_trial"]=True
    if status!=0:
        replay=s.trial(np.full(50,a.head))
        assert replay[0]==status and all(np.array_equal(v,w) for v,w in zip((q,delta,residual),replay[1:]))
        assert all(np.array_equal(v,w) for v,w in zip(before,s.state()))
        row["failed_replay_identical"]=True
    if status==0:
        assert all(np.array_equal(v,w) for v,w in zip(before,s.state())),"trial changed committed state"
        replay=s.trial(np.full(50,a.head));assert replay[0]==0
        assert all(np.array_equal(v,w) for v,w in zip((q,delta,residual),replay[1:])),"replay differs"
        assert max(abs(residual))<=1e-14
        assert np.max(abs(q-q[0]))==0 and np.max(abs(delta-delta[0]))==0,"homogeneous columns differ"
        assert max(abs(.01*a.rain_cm_day*a.dt-q*a.dt-delta))<=1e-12,"component rainfall balance"
        assert s.commit()==0
        after=s.state();assert np.all(after[0]==1)
        assert np.max(abs(after[1]-a.dt))<1e-14
        assert np.max(abs(after[2]-before[2]-delta))<1e-12
        row.update(passed=True,revision=after[0].tolist(),gwl_m=after[3].tolist())
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(row,indent=2)+"\n")
    print("STRIP01_REAL_SWAP_COMPONENT="+("PASS" if row["passed"] else "FAIL"),"status",status)
    if not row["passed"]:raise SystemExit(1)


if __name__=="__main__":main()
