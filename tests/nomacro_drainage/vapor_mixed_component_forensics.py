"""Read retained mixed original-module observations without rerunning a model."""
import argparse
from decimal import Decimal, localcontext
import hashlib
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
PAIRS=((8,11),(11,8),(7,8),(8,7),(9,10),(10,9))
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def read(folder):
    q=json.loads((folder/'RESULT.json').read_text())
    assert q['status']=='ACTUAL_ORIGINAL_HYDRAULIC_INTERFACES_OBSERVED_NO_ADMISSION'
    assert q['model_periods']==0 and q['model7_capacity_correction'] and q['actual_probe_scope'].startswith('6orderedpairs*4heads*3opposedtemperaturepairs*4perlayervaporflags*6layervisits=1728')
    assert len(q['actual_original_object_closure'])==40
    assert SHA((folder/'actual-hydraulic.exe').read_bytes())==q['executable_sha256']
    probe=ROOT/'tests/nomacro_drainage/hydraulic_vapor_mixed_probe.f90'
    assert SHA(probe.read_bytes())==q['driver_sha256']
    assert not (folder/'model8.stderr').read_bytes()
    target=ROOT/'reference/swap-4.3.1/hydraulic-corrections/VAPOR-KELVIN-SIGN01/WC_K_models_04_11.capacity7.f90'
    source=target.read_bytes().replace(b'\r\n',b'\n')
    if not q['vapor_sign_correction']:
        source=source.replace(b'Hr        = dexp(-h/100.0d0*MgRT)',b'Hr        = dexp(h/100.0d0*MgRT)',1)
    assert (folder/'WC_K_models_04_11.f90').read_bytes().replace(b'\r\n',b'\n')==source
    rows={}
    for line in (folder/'model8.stdout').read_text().splitlines():
        if not line.startswith('ACTUAL_ORIGINAL_HYDRAULIC '):continue
        fields=line.split();key=tuple(map(int,fields[1:8]));values=tuple(map(float,fields[8:]));assert len(values)==11
        pair,model,soil,j,thermal,flags,visit=key
        assert model==PAIRS[pair-1][soil-1] and soil==(1,2,1,2,2,1)[visit-1]
        assert values[0]==-10.0**(5-2*j) and values[1]==((thermal-1)*20 if soil==1 else 40-(thermal-1)*20)
        assert all(map(math.isfinite,values)) and key not in rows
        rows[key]=values
    assert len(rows)==1728
    # Alternating calls must not leak another layer's module-local parameters,
    # temperature, hydraulic selector or vapor switch into a repeated visit.
    unique={}
    for key,values in rows.items():
        reduced=key[:-1]
        if reduced in unique:assert unique[reduced]==values
        unique[reduced]=values
    assert len(unique)==576
    for key,values in unique.items():
        pair,model,soil,j,thermal,flags=key
        own=flags & (1 << (soil-1))
        assert values==unique[(pair,model,soil,j,thermal,own)]
        if model==7:assert values==unique[(pair,model,soil,j,thermal,0)]
    return q,unique


def audit(evidence):
    optimizations={};datasets={}
    with localcontext() as context:
        context.prec=80
        for opt in ('O0','O2'):
            original_q,original=read(evidence/f'hydraulic-vapor-mixed-original-{opt}-v1')
            corrected_q,corrected=read(evidence/f'hydraulic-vapor-mixed-corrected-{opt}-v1')
            assert not original_q['vapor_sign_correction'] and corrected_q['vapor_sign_correction']
            changed=0;maximum=Decimal(0)
            for key,old in original.items():
                new=corrected[key];pair,model,soil,j,thermal,flags=key
                # Only conductivity (central and the two derivative probes)
                # changes; original retention, capacity and dK owner stay exact.
                assert all(old[i]==new[i] for i in (0,1,2,3,5,6,7,10))
                liquid=original[(pair,model,soil,j,thermal,0)]
                if model==7 or not flags & (1 << (soil-1)):
                    assert old==new
                    continue
                for column,head in ((4,old[0]),(8,old[0]-old[10]),(9,old[0]+old[10])):
                    d=Decimal.from_float
                    ratio=(-Decimal(2)*d(abs(head))/100*(Decimal('.018015')*Decimal('9.81')/Decimal('8.314'))/(d(old[1])+Decimal('273.15'))).exp()
                    expected=d(liquid[column])+(d(old[column])-d(liquid[column]))*ratio
                    bound=8*(d(math.ulp(new[column]))+ratio*d(math.ulp(old[column]))+(1-ratio)*d(math.ulp(liquid[column])))
                    fraction=abs(d(new[column])-expected)/bound
                    assert fraction<=1,(key,column,str(fraction))
                    maximum=max(maximum,fraction)
                changed+=old[4]!=new[4]
            datasets[opt]=(original,corrected)
            optimizations[opt]=dict(actual_calls_each_variant=1728,distinct_states=576,changed_central_conductivities=changed,kelvin_80digit_max_fraction_8ULP_bound=str(maximum),repeated_and_other_layer_flag_invariance=True)
    assert datasets['O0']==datasets['O2']
    return dict(status='INDEPENDENT_MIXED_ORIGINAL_VAPOR_COMPONENT_PASS_NOT_ADMITTED',optimizations=optimizations,O0_O2_exact=True,model_executions=0,compiler_executions=0,public_admission=False)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--evidence',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    result=audit(args.evidence)
    with args.output.open('x',encoding='utf8') as stream:stream.write(json.dumps(result,indent=2)+'\n')
    print(result['status'])
