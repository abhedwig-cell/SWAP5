"""Actual original calendar numeric-reader and bounded Snow descriptor refusals."""
import argparse,contextlib,json,re,shutil
from pathlib import Path
import cde_interval_runtime as runtime
from cde_interval_output import metadata,active_selection,prior
from original_output_baseline import assignment

m=runtime.m

def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','profile-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();item=json.loads((a.profile_root/'RESULT.json').read_text(encoding='utf8'));inputs=Path(item['input_root']);build=Path(item['build_root'])
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
                diagnostic='\n'.join(p.read_text(encoding='utf8',errors='replace') for pattern in ('donor.stderr','donor.stdout','swap.log','swap.err') for p in out.rglob(pattern))
                assert 'HYBRID_READY' not in diagnostic and not list(out.glob('accepted-*.zip'))
                assert key.lower() in diagnostic.lower() and 'range' in diagnostic.lower(),diagnostic
                q['reader_refusals'].append(dict(attack=label,status='REFUSED_BEFORE_HYBRID_READY',diagnostic=diagnostic[-12000:],error=str(error)));save()
            else:raise AssertionError('Invalid original numeric calendar input accepted: '+label)
        q['literal_delegations']=[]
        partitions=[('dense-cde',{'SWMONTH':0,'SWODAT':0,'PERIOD':1}),
          ('subdaily-cde',{'NPRINTDAY':2}),('perstep-cde',{'FLPRINTDT':'.TRUE.'}),('water',{'SWSOLU':0}),
          ('frost',{'SWFROST':1}),('aquifer',{'SWBR':1}),('soil-table',{'SWSOPHY':1}),
          ('detailed-weather',{'SWMETDETAIL':1}),('other-drainage',{'SWDRA':0}),('no-heat',{'SWHEA':0}),
          ('analytic-heat',{'SWCALT':1}),('other-bottom',{'SWBOTB':6}),('age',{'SWSOLU':2})]
        for label,changes in partitions:
            target=a.output/('literal-delegation-'+label);shutil.copytree(inputs,target);path=target/'swap.swp';text=path.read_text(encoding='cp1252')
            for key,value in changes.items():text=assignment(text,key,value)
            path.write_text(text,encoding='cp1252')
            try:delegated=m.e.load(target,original_output=True)
            except ValueError as error:
                q['literal_delegations'].append(dict(label=label,changes=changes,status='UNCHANGED_PROJECT_DOMAIN_REFUSED',error=str(error)));save();continue
            assert active_selection(delegated) is None,label
            try:actual=metadata(delegated)
            except ValueError as error:
                try:prior.metadata(delegated)
                except ValueError as older:assert str(error)==str(older)
                else:raise AssertionError('Different prior refusal '+label)
                q['literal_delegations'].append(dict(label=label,changes=changes,status='LITERAL_PRIOR_REFUSAL_EXACT',error=str(error)));save();continue
            assert actual==prior.metadata(delegated) and actual['policy']!=metadata(project)['policy']
            try:m.validate_bundle(build,a.reference_work,delegated)
            except ValueError as error:q['literal_delegations'].append(dict(label=label,changes=changes,status='LITERAL_PRIOR_METADATA_EXACT_FOREIGN_BUNDLE_REFUSED',metadata=actual,error=str(error)));save()
            else:raise AssertionError('Per-step bundle rebound to another owner: '+label)
        q['status']='SEVEN_CDE_INTERVAL_READER_THIRTEEN_LITERAL_PARTITIONS_PASS';print(q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()

if __name__=='__main__':main()
