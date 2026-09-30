import numpy as np

def distributed_exchange(bottoms, out_sat, out_uns, in_int, in_mtx, top=0):
    nd,n=out_sat.shape
    qexc=np.zeros((nd,n))
    for domain in range(nd):
        for node in range(top,bottoms[domain]+1):
            qexc[domain,node]=(
                out_sat[domain,node]
                + out_uns[domain,node]
                - in_int[domain,node]
                - in_mtx[domain,node]
            )
    return qexc,qexc.sum(axis=0)

if __name__=="__main__":
    out_sat=np.array([
        [.04,.03,.02,.01,.005],
        [.02,.015,.01,.005,0],
        [.01,.008,.004,0,0],
    ])
    out_uns=np.array([
        [.03,.02,.01,.005,.002],
        [.01,.008,.006,.002,0],
        [.005,.004,.002,0,0],
    ])
    in_int=np.array([
        [.01,.012,.008,.004,.001],
        [.005,.004,.003,.001,0],
        [.002,.002,.001,0,0],
    ])
    in_mtx=np.array([
        [.015,.01,.006,.003,.001],
        [.004,.003,.002,.001,0],
        [.001,.001,.001,0,0],
    ])

    for bottoms in ([4,3,2],[3,3,2]):
        qexc,node=distributed_exchange(bottoms,out_sat,out_uns,in_int,in_mtx)
        dt=0.1
        macro_delta=-qexc.sum()*dt
        matrix_delta=node.sum()*dt
        assert abs(macro_delta+matrix_delta)<1e-14
        for domain,bottom in enumerate(bottoms):
            assert np.all(qexc[domain,bottom+1:]==0.0)

    print("PPA_WU05A5_P4_DISTRIBUTED_EXCHANGE_LOCAL=PASS")
