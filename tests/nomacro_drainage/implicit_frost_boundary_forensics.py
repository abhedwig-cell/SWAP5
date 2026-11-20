"""Read raw original residual witnesses independently of the component controller."""
import argparse
from decimal import Decimal, localcontext
import hashlib
import itertools
import json
import math
from pathlib import Path
import sys


def audit(profile):
    q=json.loads((profile/'RESULT.json').read_text(encoding='utf-8'))
    assert q['status']=='ACTUAL_QUALIFIED_POND_COMPOSITION_FROST_SURFACE_720_STATES_6480_ENTRIES_PASS_NO_PUBLIC_ADMISSION'
    expected=set(itertools.product((-1,1),range(1,7),(0.,.01,.5,1.),range(1,4),range(1,6),(0,)))
    reports={}
    for name,variant in q['variants'].items():
        assert variant['returncode']==0 and not variant['stderr']
        source=profile/(name+'.f90')
        executable=profile/(name+('.exe' if (profile/(name+'.exe')).exists() else ''))
        for path,field in [(source,'injected_source_sha256'),(executable,'executable_sha256')]:
            assert hashlib.sha256(path.read_bytes()).hexdigest()==variant[field]
        boundary=[line.split() for line in variant['stdout'].splitlines() if line.startswith('ACTUAL_FROST_BOUNDARY ')]
        matrix=[line.split() for line in variant['stdout'].splitlines() if line.startswith('ACTUAL_FROST_MATRIX ')]
        assert len(boundary)==720 and all(len(row)==14 for row in boundary)
        assert {int(row[1]) for row in boundary}==set(range(1,721))
        assert {(int(row[2]),int(row[3]),float(row[7]),int(row[4]),int(row[5]),int(row[6])) for row in boundary}==expected
        assert len(matrix)==6480 and all(len(row)==12 for row in matrix)
        assert {(int(row[1]),int(row[2]),int(row[3])) for row in matrix}==set(itertools.product(range(1,721),range(1,4),range(1,4)))
        failures=0; maximum=Decimal(0)
        with localcontext() as context:
            context.prec=80
            for row in matrix:
                assert all(math.isfinite(float(value)) for value in row[4:])
                analytic,reported,error,scale,relative,left,right,delta=[Decimal.from_float(float(value)) for value in row[4:]]
                assert delta>0
                fd=(right-left)/(2*delta)
                independently_scaled=max(abs(analytic),abs(fd),Decimal('1e-8'))
                roundoff=64*Decimal.from_float(sys.float_info.epsilon)*independently_scaled
                assert abs(fd-reported)<=roundoff
                assert abs(abs(analytic-reported)-error)<=roundoff
                assert abs(scale-max(abs(analytic),abs(reported),Decimal('1e-8')))<=roundoff
                assert abs(relative-error/scale)<=64*Decimal.from_float(sys.float_info.epsilon)*max(Decimal(1),abs(relative))
                ratio=abs(analytic-fd)/independently_scaled
                maximum=max(maximum,ratio)
                failures+=ratio>Decimal('2e-6')
        assert failures==variant['matrix_failures']
        assert (failures==0) == (name=='diagnostic_frost_surface_conductivity')
        reports[name]=dict(states=720,raw_matrix_entries=6480,distinct_complete_cartesian_domain=True,
            independently_recomputed_failures=failures,maximum_scaled_residual_difference_error=str(maximum))
    assert set(reports)=={'actual_qualified_ordinary_implicit_composition','diagnostic_frost_surface_conductivity'}
    return dict(status='INDEPENDENT_ACTUAL_RESIDUAL_CARTESIAN_JACOBIAN_SOURCE_EXECUTABLE_WITNESSES_PASS',
        profile_result_sha256=hashlib.sha256((profile/'RESULT.json').read_bytes()).hexdigest(),
        producer=q['source'],optimization=q['optimization'],variants=reports,
        fresh_model_executions=0,fresh_compiler_executions=0,canonical_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('profile','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();assert not a.output.exists()
    result=audit(a.profile);a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(result['status'],result['optimization'])
