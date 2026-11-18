"""Actual original calendar numeric-reader and bounded Snow descriptor refusals."""
import argparse,contextlib,json,re,shutil
from pathlib import Path
import ordinary_reset_runtime as runtime
from ordinary_output_reset import metadata,active_selection,prior
from original_output_baseline import assignment

m=runtime.m

def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','profile-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();item=json.loads((a.profile_root/'RESULT.json').read_text());inputs=Path(item['input_root']);build=Path(item['build_root'])
    project=m.e.load(inputs,original_output=True);meta,case=m.validate_bundle(build,a.reference_work,project)
    assert metadata(project)['swmonth']==0 and metadata(project)['swodat']==1
    q=dict(status='RUNNING',build_sha256=m.sha(build/'BUILD.json'),reader_refusals=[],descriptor_refusals=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        for label,key,value in [('period-negative','PERIOD',-1),('period-range','PERIOD',367),('nprint-zero','NPRINTDAY',0),
            ('nprint-range','NPRINTDAY',1441),('monthly-range','SWMONTH',2),('reset-range','SWRES',2),('dates-range','SWODAT',2)]:
            bad=a.output/('input-'+label);shutil.copytree(case,bad);path=bad/'swap.swp';path.write_text(assignment(path.read_text(encoding='cp1252'),key,value),encoding='cp1252')
            out=a.output/('reader-'+label);out.mkdir()
            try:
                with contextlib.ExitStack() as stack:m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),bad,out,
                    [m.h.ColumnStart('original',0)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
            except (ValueError,RuntimeError) as error:
                diagnostic='\n'.join(p.read_text(errors='replace') for pattern in ('donor.stderr','donor.stdout','swap.log','swap.err') for p in out.rglob(pattern))
                assert 'HYBRID_READY' not in diagnostic and not list(out.glob('accepted-*.zip'))
                assert key.lower() in diagnostic.lower() and 'range' in diagnostic.lower(),diagnostic
                q['reader_refusals'].append(dict(attack=label,status='REFUSED_BEFORE_HYBRID_READY',diagnostic=diagnostic[-12000:],error=str(error)));save()
            else:raise AssertionError('Invalid original numeric calendar input accepted: '+label)
        for key,value in [('NPRINTDAY',3),('SWRES',2),('SWFROST',1),('SWBR',1),('SWSOLU',1),('SWSOLU',2),
            ('SWSOPHY',1),('SWMETDETAIL',1),('SWDRA',0),('SWHEA',0),('SWCALT',1),('SWBOTB',6)]:
            bad=a.output/('descriptor-'+key+'-'+str(value));shutil.copytree(inputs,bad);path=bad/'swap.swp';path.write_text(assignment(path.read_text(encoding='cp1252'),key,value),encoding='cp1252')
            try:metadata(m.e.load(bad,original_output=True))
            except ValueError as error:q['descriptor_refusals'].append(dict(key=key,value=value,status='REFUSED',error=str(error)));save()
            else:raise AssertionError('Unsupported selected ordinary annual descriptor accepted: '+key)
        q['literal_delegations']=[]
        for key,value in [('SWRES',0),('SWMONTH',1),('FLPRINTDT','.FALSE.'),('SWSNOW',1)]:
            target=a.output/('literal-delegation-'+key);shutil.copytree(inputs,target);path=target/'swap.swp';path.write_text(assignment(path.read_text(encoding='cp1252'),key,value),encoding='cp1252')
            delegated=m.e.load(target,original_output=True);assert active_selection(delegated) is None
            actual=metadata(delegated);assert actual==prior.metadata(delegated) and actual['policy']!=metadata(project)['policy']
            try:m.validate_bundle(build,a.reference_work,delegated)
            except ValueError as error:q['literal_delegations'].append(dict(key=key,value=value,status='LITERAL_PRIOR_METADATA_EXACT_FOREIGN_BUNDLE_REFUSED',metadata=actual,error=str(error)));save()
            else:raise AssertionError('Ordinary annual bundle rebound to another selected owner: '+key)
        q['status']='SEVEN_ORDINARY_READER_TWELVE_DESCRIPTOR_FOUR_LITERAL_DELEGATIONS_PASS';print(q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()

if __name__=='__main__':main()
