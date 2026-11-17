"""Refuse forged fixed-age policy, foreign native input and active age receipt."""
import argparse
import contextlib
import json
from pathlib import Path
import age_fixed as f
from daily_coupling import CoupledDailyColumn

m=f.m


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','evidence','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();checks=[]
    for kind,other in [('surface','subsurface-interval'),('subsurface-interval','surface')]:
        project=m.e.load(a.evidence/'inputs'/kind)
        for opt in ('O0','O2'):
            name=kind+'-'+opt;build=a.evidence/(name+'-build');meta,case=m.validate_bundle(build,a.reference_work,project)
            for field,value in [('policy','foreign'),('irrigation_age_day',1.)]:
                target=a.output/(name+'-'+field);target.mkdir();bad=json.loads((build/'BUILD.json').read_text());bad['identity']['original_age_fixed_irrigation'][field]=value;(target/'BUILD.json').write_text(json.dumps(bad))
                try:m.validate_bundle(target,a.reference_work,project)
                except ValueError as error:assert 'fixed young-water age policy' in str(error)
                else:raise AssertionError('Foreign fixed age policy accepted')
                checks.append(dict(profile=name,attack='policy-'+field,status='REFUSED'))
            target=a.output/(name+'-foreign-input');source=a.evidence/(other+'-'+opt+'-full')/'accepted-column-1-day-4.zip';digest=m.sha(source)
            try:CoupledDailyColumn(build,a.reference_work,target,project,'foreign-age-input',origin=source,day=4,adopt_native=True)
            except ValueError:pass
            else:raise AssertionError('Foreign fixed age input native accepted')
            assert m.sha(source)==digest;checks.append(dict(profile=name,attack='foreign-native-input',status='REFUSED'))
            target=a.output/(name+'-candidate');target.mkdir();source=a.evidence/(name+'-full')/'accepted-column-1-day-4.zip';origin=target/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin);digest=m.sha(source)
            with contextlib.ExitStack() as stack:
                host=m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
                    [m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
                col=host.columns[0];before=(col.day,col.stocks.copy(),col.age_state.copy(),col.age_effluent.copy());receive=m.h.receive
                def corrupt(process,*args,**kwargs):
                    disposition,response=receive(process,*args,**kwargs)
                    if process is col.worker and 'HYBRID_AGE_CUMULATIVE' in response:
                        values=response['HYBRID_AGE_CUMULATIVE'].copy();values[5]=str(float(values[5])+1.);response['HYBRID_AGE_CUMULATIVE']=values
                    return disposition,response
                try:
                    m.h.receive=corrupt
                    try:host.step(1,checkpoint=True)
                    except ValueError as error:assert 'age candidate exceeds accepted age balance policy' in str(error)
                    else:raise AssertionError('Fabricated age source at young-water gift accepted')
                finally:m.h.receive=receive
                assert before==(col.day,col.stocks,col.age_state,col.age_effluent) and not list(target.glob('accepted-*.zip'))
            assert m.sha(source)==digest;checks.append(dict(profile=name,attack='active-nonzero-age-source',status='REFUSED',committed_state_unchanged=True))
    result=dict(status='FIXED_YOUNG_AGE_POLICY_FOREIGN_NATIVE_AND_ACTIVE_SOURCE_REFUSALS_PASS',checks=checks)
    (a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],len(checks))


if __name__=='__main__':main()
