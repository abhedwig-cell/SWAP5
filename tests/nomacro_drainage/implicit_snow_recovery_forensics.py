"""Read original portable recovery evidence without executing models or compilers."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile
from datetime import date

from implicit_snow_control_forensics import native_controls,source_controls
from implicit_snow_forensics import native,scalar
from ordinary_pond_evidence import read,digest,require,rows,physical


def checkpoint(path,build,row,selectors,external_origin=None,external_source=None):
    with zipfile.ZipFile(path) as z:
        require(set(z.namelist())=={'checkpoint.json','macro.bin','result.end'},'Transaction checkpoint members differ')
        meta=json.loads(z.read('checkpoint.json'))
        binding=dict(meta['binding']);receipt=dict(meta['receipt'])
        if external_origin is not None:
            expected=dict(version=1,source_sha256=external_source,
                coupling_id='original-output',forcing='original-project')
            require(binding.pop('external_daily',None)==expected,'Published external daily binding differs')
            clock=(date.fromisoformat(build['project']['start_date'])-date(1900,1,1)).days+1
            require(receipt.pop('coupling',None)==dict(id='original-output',revision=1,origin_revision=0,
                origin_sha256=external_origin,origin_day=4,window_day1900=[clock+4,clock+5],forcing='original-project'),
                'Published coupling origin or revision differs')
        require(binding==build['binding'] and physical([receipt])==physical([row]),
                'Transaction checkpoint binding or physical receipt differs')
        require(set(meta['files'])=={'macro.bin','result.end'},'Transaction native inventory differs')
        data={n:z.read(n) for n in meta['files']}
        require(all(hashlib.sha256(v).hexdigest()==meta['files'][n] for n,v in data.items()),
                'Transaction actual payload digest differs')
        native(data['macro.bin'],row,build,build['identity']['original_output'],selectors)
        return data


def transactions(root,profile,buildpath,inputs,external_source):
    r=read(root/'RESULT.json');build=read(buildpath/'BUILD.json');data=rows(profile/'trajectory')
    require(r['status']=='ACTUAL_IMPLICIT_SNOW_EXTERNAL_TRANSACTION_PASS' and
            r['actual_BUILD_sha256']==digest(buildpath/'BUILD.json') and
            r['actual_profile_sha256']==digest(profile/'RESULT.json') and
            r['checks']==dict.fromkeys(('discard_no_day_advance','replay_exact','accept_exact',
                'recovered_next_day_exact','origin_unchanged'),True),'Transaction producer or checks differ')
    return transaction_payloads(root/'actual',profile,buildpath,inputs,external_source)


def transaction_payloads(actual,profile,buildpath,inputs,external_source):
    build=read(buildpath/'BUILD.json');data=rows(profile/'trajectory')
    swp=(inputs/'swap.swp').read_text(encoding='cp1252')
    selectors={k:scalar(swp,k) for k in ('SWKIMPL','SWSNOW','SWSOLU','SWHYST','SWBOTB','SWDRA')}
    origin=checkpoint(profile/'trajectory/accepted-column-1-day-4.zip',build,data[3],selectors)
    expected=checkpoint(actual/'external/trial-1/accepted-column-1-day-5.zip',build,data[4],selectors)
    for rel in ('external/trial-1/accepted-column-1-day-5.zip','external/trial-2/accepted-column-1-day-5.zip'):
        require(checkpoint(actual/rel,build,data[4],selectors)==expected,'Actual discarded/replayed/published native payload differs')
    require(checkpoint(actual/'external/accepted-column-1-day-5.zip',build,data[4],selectors,
        digest(profile/'trajectory/accepted-column-1-day-4.zip'),external_source)==expected,'Actual published payload differs')
    checkpoint(actual/'recovered/trial-1/accepted-column-1-day-6.zip',build,data[5],selectors)
    for rel,payload in (('external/verified-initial-origin',origin),('external/trial-1/origin',origin),
                        ('external/trial-2/origin',origin),('recovered/verified-initial-origin',expected)):
        require(all((actual/rel/n).read_bytes()==v for n,v in payload.items()),'Actual transaction origin changed')
    return dict(status='INDEPENDENT_ACTUAL_TRANSACTION_PAYLOADS_PASS',actual_BUILD_sha256=digest(buildpath/'BUILD.json'))


def audit(original,first,final):
    original,first,final=map(Path,(original,first,final));initial=original/'implicit-snow'
    q=read(final/'recovery/RESULT.json');old=read(first/'recovery/RESULT.json')
    require(read(initial/'RESULT.json')['status']=='FAILED_OR_CENSORED' and old['status']=='FAILED' and
        q['status']=='ACTUAL_MISSING_IMPLICIT_SNOW_CONTROLS_ONLY_PASS' and
        q['original_failed_producer_sha256']==old['original_failed_producer_sha256']==digest(initial/'RESULT.json') and
        all(q[k]==0 for k in ('fresh_compilations','fresh_full_model_periods','fresh_short_model_periods')),
        'Original failures or controls-only producer differ')
    require('PermissionError' in (first/'recovery/commands/transactions-water-head.stderr').read_text(),
            'Original permission failure missing')
    projection=read(original/'COMPILED_PROJECTION_V1.json');out=dict(status='RUNNING',native={},source={},transactions={},reused={})
    with zipfile.ZipFile(original/'source/actual-producer-source.zip') as z:
        external_source=hashlib.sha256(z.read('app/hybrid_water/daily_coupling.py')).hexdigest()
    for actual,entry in projection.items():
        a=original/entry['archive_prefix'];b=final/entry['archive_prefix']
        require(digest(a/'BUILD.json')==entry['actual_BUILD_sha256']==digest(b/'BUILD.json'),'Restored actual build rebound')
        for file in a.iterdir():
            if file.is_file():require((b/file.name).is_file() and digest(file)==digest(b/file.name),'Restored original compiled bytes changed')
    expected_reuse={'missing-audit-full-cde-groundwater-clock','missing-audit-full-cde-head-step','source-controls-water-head'}
    require(len(q['steps'])==12 and {s['label'] for s in q['steps'] if s['status']=='REUSED_ORIGINAL_PASS'}==expected_reuse and
        all(s['status'] in ('PASS','REUSED_ORIGINAL_PASS') for s in q['steps']),'Recovery step denominator differs')
    for step in q['steps']:
        if step['status']=='REUSED_ORIGINAL_PASS':
            rel=step['actual_reused_result'].split('/recovery/',1)[1];path=first/'recovery'/rel
            require(digest(path)==step['actual_reused_result_sha256'],'Reused original result changed')
            out['reused'][step['label']]=digest(path)
    for label in ('water-head','cde-head-step','cde-groundwater-clock','cde-groundwater-interval'):
        profile=initial/'short'/label;p=read(profile/'RESULT.json');build=original/projection[p['build_root']]['archive_prefix']
        inputs=original/p['input_root'].split('/proof/',1)[1]
        control=first if label=='water-head' else final
        out['source'][label]=source_controls(control/'recovery'/('source-controls-'+label),build)
        out['transactions'][label]=transactions(final/'recovery'/('transactions-'+label),profile,build,inputs,external_source)
        if label in ('water-head','cde-head-step'):
            out['native'][label]=native_controls(final/'recovery'/('native-controls-'+label),profile,build,inputs)
    out.update(status='INDEPENDENT_ORIGINAL_IMPLICIT_SNOW_RECOVERY_PASS',models=0,compilations=0,
        actual_compiled_refusals=50,actual_source_refusals=sum(v['actual_refusals'] for v in out['source'].values()),
        actual_transaction_contexts=4,original_failures_preserved=True)
    return out


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('original','first','final','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();r=audit(a.original,a.first,a.final)
    with a.output.open('x',encoding='utf-8') as f:json.dump(r,f,indent=2);f.write('\n')
    print(r['status'])
