from dataclasses import dataclass

@dataclass
class GeometryCase:
    static: list
    dynamic: list
    pp: list
    bottom_potential: list
    top: int = 0
    dz: list | None = None
    dipo: list | None = None

def mpvolume(case):
    n=len(case.static)
    nd=len(case.pp)
    dz=case.dz or [10.0]*n
    dipo=case.dipo or [4.0]*n
    total=[max(0.0,s+d) for s,d in zip(case.static,case.dynamic)]

    bottom_main=None
    for ic in range(n-1,case.top-1,-1):
        wmin=(1.0-(1.0-0.001/dipo[ic])**2)*dz[ic]
        if bottom_main is None:
            if total[ic] < wmin and case.static[ic] < 1e-5:
                total[ic]=0.0
            if total[ic] > 0.0:
                bottom_main=ic

    if bottom_main is None:
        bottom_main=case.top

    if nd>1:
        bottom_main=max(bottom_main,case.bottom_potential[1])

    bottoms=[bottom_main]
    for domain in range(1,nd):
        bottoms.append(min(case.bottom_potential[domain],bottom_main))

    domain_volume=[[0.0]*n for _ in range(nd)]
    for domain in range(nd):
        for ic in range(case.top,bottoms[domain]+1):
            domain_volume[domain][ic]=case.pp[domain][ic]*total[ic]

    return total,bottoms,domain_volume

if __name__=="__main__":
    pp=[
        [0.5,0.5,0.6,0.8,1.0],
        [0.3,0.3,0.25,0.2,0.0],
        [0.2,0.2,0.15,0.0,0.0],
    ]
    static=[0.02,0.02,0.01,0.0,0.0]
    potentials=[4,3,2]

    cases=[
        [0.0,0.0,0.0,0.0,0.0],
        [0.05,0.04,0.03,0.02,0.01],
        [0.05,0.04,0.03,0.0,0.0],
    ]

    bottoms=[]
    for dynamic in cases:
        total,bottom,domain_volume=mpvolume(
            GeometryCase(static,dynamic,pp,potentials)
        )
        reconstructed=[
            sum(domain_volume[d][ic] for d in range(len(pp)))
            for ic in range(len(total))
        ]
        assert all(abs(a-b)<1e-14 for a,b in zip(total,reconstructed))
        bottoms.append(bottom)

    assert bottoms[0] == [3,3,2]
    assert bottoms[1] == [4,3,2]
    assert bottoms[2] == [3,3,2]

    print("PPA_WU05A5_P3_GEOMETRY_LOCAL=PASS")
