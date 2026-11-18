"""Real original groundwater history numeric/date reader and descriptor refusals."""
import argparse
import contextlib
import json
from pathlib import Path
import re
import shutil
import groundwater_history_runtime as runtime
from original_output_baseline import assignment

m=runtime.m


def main():
    parser=argparse.ArgumentParser()
    for key in ('reference-work','profile-root','output'):parser.add_argument('--'+key,type=Path,required=True)
    args=parser.parse_args();args.output.mkdir();item=json.loads((args.profile_root/'RESULT.json').read_text())
    inputs=Path(item.get('input_root',args.profile_root/'input'));build=Path(item.get('build_root',args.profile_root/'build'))
    project=m.e.load(inputs,original_output=True);meta,case=m.validate_bundle(build,args.reference_work,project)
    record=dict(status='RUNNING',build_sha256=m.sha(build/'BUILD.json'),reader_refusals=[],descriptor_refusals=[],policy_refusals=[])
    def save():(args.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8')
    save()
    try:
        faults={'too-deep':'2002-01-01 -10001.0\n2004-12-31 -95.0\n',
                'too-high':'2002-01-01 1001.0\n2004-12-31 -95.0\n',
                'minimum-five-unsaturated':'2002-01-01 0.0\n2004-12-31 -95.0\n',
                'outside-period':'2005-01-01 -95.0\n2005-12-31 -95.0\n',
                'before-period':'2000-01-01 -95.0\n2000-12-31 -95.0\n',
                'missing-table':''}
        for label,table in faults.items():
            bad=args.output/('input-'+label);shutil.copytree(case,bad);path=bad/'swap.swp'
            text,count=re.subn(r'(?mi)^([ \t]*DATE1[ \t]+GWLEVEL[^\r\n]*\n).*?^\* End of table',
                lambda match:match[1]+table+'* End of table',path.read_text(encoding='cp1252'),count=1,flags=re.S);assert count==1
            path.write_text(text,encoding='cp1252');out=args.output/('reader-'+label);out.mkdir()
            try:
                with contextlib.ExitStack() as stack:m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),bad,out,
                    [m.h.ColumnStart('original',0)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
            except (ValueError,RuntimeError) as error:
                diagnostic='\n'.join(p.read_text(errors='replace') for pattern in ('donor.stderr','donor.stdout','swap.log','swap.err') for p in out.rglob(pattern))
                assert not list(out.glob('accepted-*.zip')) and 'HYBRID_READY' not in diagnostic
                assert any(word in (diagnostic+str(error)).lower() for word in ('gwlevel','groundwater','date1','checkdate','range','date','previous table is incomplete'))
                record['reader_refusals'].append(dict(attack=label,status='REFUSED_BEFORE_HYBRID_READY',diagnostic=diagnostic[-12000:],error=str(error)));save()
            else:raise AssertionError('Invalid original groundwater input accepted: '+label)
        for key,value in [('SWHYST',3),('SWSNOW',2),('SWFROST',1),('SWBR',1),('SWSOPHY',1),('SWMETDETAIL',1),('SWSOLU',2),('SWHEA',0),('SWCALT',1)]:
            bad=args.output/('descriptor-'+key);shutil.copytree(inputs,bad);path=bad/'swap.swp'
            path.write_text(assignment(path.read_text(encoding='cp1252'),key,value),encoding='cp1252')
            try:m.e.load(bad,original_output=True)
            except ValueError as error:record['descriptor_refusals'].append(dict(key=key,value=value,status='REFUSED',error=str(error)))
            else:raise AssertionError('Unsupported prescribed groundwater descriptor accepted: '+key)
        for owner,fields in [('lower_boundary_receipt',('policy','source_sha256','predecessor_sha256','template_sha256','effective_SWBOTB','production_sha256')),
                             ('groundwater_native_state',('policy','source_sha256','provider_sha256','predecessor_sha256','predecessor_provider_sha256','magic','domain_bytes','actual_domain','cde_prefix_offset'))]:
            for field in fields:
                out=args.output/('policy-'+owner+'-'+field);out.mkdir();bad=json.loads((build/'BUILD.json').read_text());bad['identity'][owner][field]='foreign'
                (out/'BUILD.json').write_text(json.dumps(bad),encoding='utf8')
                for helper in ('mod_subsurface_solute_source.f90','mod_aquifer_solute_reservoir.f90'):
                    if (build/helper).exists():shutil.copyfile(build/helper,out/helper)
                try:m.validate_bundle(out,args.reference_work,project)
                except ValueError as error:
                    assert 'Foreign original lower-boundary receipt' in str(error) or 'Foreign prescribed groundwater native carry policy' in str(error),str(error)
                    record['policy_refusals'].append(dict(owner=owner,field=field,status='REFUSED',error=str(error)))
                else:raise AssertionError('Foreign prescribed groundwater policy accepted')
        assert m.validate_bundle(build,args.reference_work,project)[0]==meta
        record['status']='SIX_ORIGINAL_GROUNDWATER_HISTORY_READER_NINE_DESCRIPTOR_FIFTEEN_POLICY_REFUSALS_PASS'
        print(record['status'],flush=True)
    except Exception as error:record.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
