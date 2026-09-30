from math import sqrt

def rapid_domain(id_,ic_top,ic_bottom,satfr,zwater,zbottom,zdrain,pond,dt,
                 dipo,dz,volume,areaexp,kd_ref,res_ref,frreduq,
                 water_storage,volume_under_drain,drain_type=1,enabled=True):
    per=[0.0]*len(volume)
    if id_ != 1 or not enabled:
        return 0.0,per,None
    allowed=(zbottom < zdrain) or (drain_type != 1)
    if not allowed:
        return 0.0,per,None

    kdcp=[0.0]*len(volume)
    kd=0.0
    for i in range(ic_top,ic_bottom+1):
        ratio=max(0.0,min(1.0,volume[i]/dz[i]))
        width=dipo[i]*(1.0-sqrt(max(0.0,1.0-ratio)))
        kdcp[i]=((width**areaexp)/dipo[i])*dz[i] if dipo[i]>0 else 0.0
        if i == ic_top:
            kdcp[i] *= satfr
        kd += kdcp[i]

    drainable=max(0.0,water_storage-volume_under_drain)
    dh=zwater-max(zdrain,zbottom)
    if zwater > -1e-7:
        dh += pond
    dh=max(0.0,dh)

    if kd > 1e-10:
        fac=min(kd_ref/kd,1.1)
        resistance=res_ref*fac
        total=min(frreduq*(dh/resistance)*dt,drainable)
    else:
        resistance=None
        total=0.0

    if kd > 1e-15:
        for i in range(ic_top,ic_bottom+1):
            per[i]=total*kdcp[i]/kd

    return total,per,resistance

if __name__=="__main__":
    dipo=[4.0]*5
    dz=[10.0]*5
    volume=[0.2,0.3,0.4,0.5,0.0]

    total,per,res=rapid_domain(
        1,1,3,0.6,-60.0,-100.0,-80.0,0.0,0.1,
        dipo,dz,volume,3.0,0.001,20.0,1.0,
        0.7,0.1,drain_type=2
    )
    assert abs(sum(per)-total)<1e-14
    assert total>0.0
    assert per[3]>per[2]>per[1]>0.0

    total2,per2,_=rapid_domain(
        2,1,3,0.6,-60.0,-100.0,-80.0,0.0,0.1,
        dipo,dz,volume,3.0,0.001,20.0,1.0,
        0.7,0.1,drain_type=2
    )
    assert total2==0.0 and sum(per2)==0.0

    capped,_,_=rapid_domain(
        1,1,3,0.6,-20.0,-100.0,-80.0,0.0,0.1,
        dipo,dz,volume,3.0,0.001,20.0,1.0,
        0.03,0.0,drain_type=2
    )
    assert abs(capped-0.03)<1e-14

    tube_blocked,_,_=rapid_domain(
        1,1,3,0.6,-60.0,-70.0,-80.0,0.0,0.1,
        dipo,dz,volume,3.0,0.001,20.0,1.0,
        0.7,0.1,drain_type=1
    )
    assert tube_blocked==0.0

    print("PPA_WU05A5_P5_DRAINAGE_LOCAL=PASS")
