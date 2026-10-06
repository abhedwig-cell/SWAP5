#!/usr/bin/env python3
"""Full immutable original process composition; independent geometric integral oracle.

This qualifies only reference-owner evidence, never production runtime or hard mass.
"""
from pathlib import Path
import argparse,subprocess,tempfile,itertools,json,hashlib,math
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def integral(k,a,b):
    return sum(v*max(0.,min(b,i+1.)-max(a,float(i))) for i,v in enumerate(k))
def distribute(q,k,gw,spacing,aniso,inf,omit_tiny_unsaturated=True):
    if abs(q)<=1e-10:return [0.]*8
    w=-min(gw,0.);hor=[v*aniso for v in k];depth=8.-w
    fac=math.sqrt((depth/integral([1./v for v in k],w,8.))/(integral(hor,w,8.)/depth))
    span=.25*spacing*fac
    if inf and q < -1e-10:
        sat_first=math.ceil(w)-w
        span*=max(.5,sat_first/span)
    end=min(8.,w+span)
    if not(inf and q < -1e-10):
        total=integral(hor,w,end)
        return [q*integral(hor,max(w,float(i)),min(end,i+1.))/total if min(end,i+1.)>max(w,float(i)) else 0. for i in range(8)]
    surface=1.;uns=integral(hor,surface,w);sat=integral(hor,w,end);total=uns+sat
    result=[]
    for i in range(8):
        a=max(surface,float(i));b=min(w,i+1.)
        above=0.
        if b>a and uns>(1e-8 if omit_tiny_unsaturated else 0.):
            c=integral(hor,surface,a);d=integral(hor,surface,b)
            above=q/total*(d*d-c*c)/uns
        a=max(w,float(i));b=min(end,i+1.)
        below=0.
        if b>a:
            c=integral(hor,b,end);d=integral(hor,a,end)
            below=q/total*(d*d-c*c)/sat
        result.append(above+below)
    return result

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--build');ap.add_argument('--record',required=True);args=ap.parse_args()
    build=Path(args.build or tempfile.mkdtemp(prefix='ppa-wu05b16-owner-'));build.mkdir(parents=True,exist_ok=True)
    status=json.loads((ROOT/'integration/audits/PPA_WU05B16_STATUS.json').read_text())
    prereg=json.loads((ROOT/status['preregistration']).read_text())
    for path,identity in prereg['immutable_sources'].items():assert sha(ROOT/path)==identity['sha256'],path
    axes=prereg['probe_axes'];cases=list(itertools.product(axes['physical_switches']['SWDIVDINF'],axes['groundwater_cm'],axes['frozen_bottom_cm'],axes['available_air_below_frost_cm'],axes['raw_level_rate_cm_day'],axes['qbot_cm_day'],axes['spacing_cm'],axes['anisotropy']))
    inputs=''.join(str(n)+' '+' '.join(format(x,'.17g') for x in c)+'\n' for n,c in enumerate(cases,1));(build/'cases.txt').write_text(inputs)
    files=['tests/frost/test_ppa_wu05b16_divdra_globals.f90','reference/swap-4.3.1/b1_11_frost_source/SWAP/divdra.f90','reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90','tests/frost/test_ppa_wu05b16_divdra_owner.f90']
    for opt in (0,2):
        folder=build/f'o{opt}';folder.mkdir(exist_ok=True)
        command=['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J',str(folder),'-I',str(folder),*[str(ROOT/f) for f in files],'-o',str(folder/'test')]
        subprocess.run(command,check=True,cwd=folder)
        with (folder/'output.txt').open('w') as out:subprocess.run([str(folder/'test')],input=inputs,text=True,stdout=out,check=True,cwd=folder)
        print(f'B16_FULL_UNCHANGED_ORIGINAL_O{opt}_EXECUTION=PASS',flush=True)
    assert (build/'o0/output.txt').read_bytes()==(build/'o2/output.txt').read_bytes()
    rows=(build/'o0/output.txt').read_text().splitlines();assert len(rows)==len(cases)
    counts=dict(cases=len(cases),low_air=0,normal_air=0,blocked=0,equality=0,surviving=0,near_zero_replacement=0,scaled=0,original_small_flux_early_return=0,nonzero_nodal_reporting_residual=0)
    max_partition=0.;max_ledger=0.;max_net_reference=0.;examples=[]
    max_omitted=0.;max_conservative_partition_closure=0.;initial_tiny_disappearance=0
    for n,(c,line) in enumerate(zip(cases,rows),1):
        values=line.split();assert int(values[0])==n
        rawlevel,*v=map(float,values[1:]);before=v[:8];finallevel=v[8];after=v[9:17];bottom=v[17]
        inf,gw,frost,air,raw,qbot,spacing,aniso=c;k=[1.,4.]*4
        expected_before=distribute(raw,k,gw,spacing,aniso,inf)
        assert rawlevel==raw
        if 0.<abs(raw)<=1e-10:
            assert before==[0.]*8
            initial_tiny_disappearance+=1
        frozen=[i for i in range(8) if -(i+.5)>=frost];rf=[0. if i in frozen else 1. for i in range(8)];rf[len(frozen)]=.5
        low=air<.01
        if low:
            counts['low_air']+=1
            blocked=frost < -3.;counts['blocked' if blocked else 'equality' if frost==-3. else 'surviving']+=1
            level=0. if blocked else raw
            bottom_expected=0. if blocked else qbot
            if abs(level)<1e-6:
                level=0. if blocked else qbot;counts['near_zero_replacement']+=1
            else:
                level*=1.+qbot/level;counts['scaled']+=1
            modified=[x*r+(1.-r)*1e-10 for x,r in zip(k,rf)]
            expected_after=distribute(level,modified,min(gw,frost),spacing,aniso,inf)
            conservative=distribute(level,modified,min(gw,frost),spacing,aniso,inf,False)
            omitted=sum(conservative)-sum(expected_after)
            max_omitted=max(max_omitted,abs(omitted))
            if abs(level)>1e-10:
                max_conservative_partition_closure=max(max_conservative_partition_closure,abs(sum(conservative)-level))
                assert abs(sum(conservative)-level)<1e-14
            expected_net=0. if blocked or abs(raw)<1e-6 else -raw
            # Scalar redistribution cancels the retained upward-positive bottom
            # transfer in the signed net ledger; no SWDIVD0 reporting inference.
            assert abs(bottom_expected-level-expected_net)<1e-14
        else:
            counts['normal_air']+=1;expected_after=[x*r for x,r in zip(expected_before,rf)];level=sum(expected_after);bottom_expected=qbot
        assert abs(finallevel-level)<1e-14,(n,'level',finallevel,level)
        assert bottom==bottom_expected,(n,'bottom')
        err=max(abs(a-b) for a,b in zip(before+after,expected_before+expected_after));max_partition=max(max_partition,err)
        assert err<2e-12,(n,c,'independent partition',err,before,after,expected_after)
        residual=sum(after)-finallevel;max_ledger=max(max_ledger,abs(residual))
        if abs(finallevel)<=1e-10 and low:counts['original_small_flux_early_return']+=1
        if abs(residual)>1e-14:
            counts['nonzero_nodal_reporting_residual']+=1
            if len(examples)<8:examples.append(dict(case=n,input=c,nodal=sum(after),level=finallevel,bottom=bottom,residual=residual))
        # Positive nodal sink and positive upward bottom flux have opposite net signs.
        physical_net=bottom-sum(after);report_net=bottom-finallevel
        max_net_reference=max(max_net_reference,abs(physical_net-report_net))
    result=dict(work_unit='PPA-WU05B16',phase='A_REFERENCE_OWNER_ADJUDICATION_ONLY',status='LOCAL_REFERENCE_PROBE_COMPLETE_NOT_RUNTIME_ADMITTED',baseline=prereg['baseline'],production_source=prereg['baseline_source'],counts=counts,optimization_byte_identity=True,max_independent_partition_error=max_partition,max_nodal_level_residual=max_ledger,max_physical_report_net_residual=max_net_reference,residual_examples=examples,source_sha256={f:sha(ROOT/f) for f in files},driver_sha256=sha(Path(__file__)),input_sha256=sha(build/'cases.txt'),build=str(build),output_sha256=sha(build/'o0/output.txt'),executables={f'o{o}':sha(build/f'o{o}/test') for o in (0,2)},claim='Complete unchanged original FrozenBounds+DIVDRA controlled process composition only; no full legacy simulation, hard-mass gate or production admission.')
    result.update(initial_original_tiny_scalar_disappearance_cases=initial_tiny_disappearance,max_independently_predicted_tiny_unsaturated_omission=max_omitted,max_conservative_geometric_partition_closure=max_conservative_partition_closure,owner_adjudication='Nodal sink and bottom remain separate. Low-air surviving non-tiny scalar becomes raw+qbot, so bottom minus drainage equals -raw. Near-zero surviving scalar becomes qbot, so net is zero. Blocked scalar/bottom are zero. This is actual spatial redistribution, not the SWDIVD0 reporting-only defect.',bounded_numerical_finding='Separate infiltration skips positive unsaturated transmissivity <=1e-8, while the total transmissivity denominator includes it; independently predicted omitted flux explains the nonzero final nodal/level residual. No correction is applied or qualified here. Original abs(scalar)<=1e-10 early return is separately retained and diagnosed.')
    Path(args.record).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
