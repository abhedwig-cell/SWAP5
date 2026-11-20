"""Independent actual malformed native/source and current-postimage observers."""
import hashlib
import json
from pathlib import Path
import struct
import zipfile

from ordinary_pond_evidence import read,digest,rows,physical,require
from groundwater_interval_forensics import native
import implicit_conductivity_forensics as original


def native_controls(root,profile,bundle):
    root,profile,bundle=Path(root),Path(profile),Path(bundle);q=read(root/'RESULT.json');build=read(bundle/'BUILD.json')
    require(q['status']=='ACTUAL_GROUNDWATER_CDE_INTERVAL_DRAINAGE_COMPILED_NATIVE_TRANSACTION_PASS' and
            q['actual_BUILD_sha256']==digest(bundle/'BUILD.json') and all(v is True for v in q['transactions'].values()),'Incomplete actual native/transaction campaign')
    selected=build['identity']['original_output'];hys=selected['swhyst'];n=build['project']['nodes']
    with zipfile.ZipFile(profile/'trajectory/accepted-column-1-day-4.zip') as z:before=z.read('macro.bin')
    row=rows(profile/'trajectory')[3];parsed=native(before,row,build,selected)
    is_interval=selected.get('groundwater_cde_interval') is True
    require(len(q['clock_refusals'])==((53 if hys else 47) if is_interval else (56 if hys else 50)) and len(q['groundwater_refusals'])==(29 if hys else 25),'Actual native refusal denominator differs')
    compiled=public=0
    for key,folder in [('clock_refusals','clock-native'),('groundwater_refusals','groundwater-native')]:
        labels=[]
        for item in q[key]:
            label=item['attack'];labels.append(label);path=root/folder/label;bad=(path/'origin/macro.bin').read_bytes()
            require(item['status']=='REFUSED' and bad!=before and not list(path.glob('accepted-*.zip')),'Actual malicious native missing or accepted')
            diagnostic='\n'.join(p.read_text(encoding='utf-8',errors='replace') for p in path.rglob('donor.stderr'))
            require(diagnostic.replace('\r\n','\n')==item['diagnostic'].replace('\r\n','\n'),
                    'Actual native worker diagnostic differs from original receipt')
            if 'ERROR STOP' in diagnostic:compiled+=1
            else:
                require(not hys and key=='groundwater_refusals' and label=='hydraulic-head' and
                        item['error']=='Restored donor state differs from the accepted checkpoint receipt', 'Unexpected public refusal authority')
                offset=parsed['groundwater_domain_offset']+72;value=struct.unpack_from('<d',before,offset)[0]+1.
                expected=bytearray(before);struct.pack_into('<d',expected,offset,value)
                require(bad==bytes(expected),'Actual public head mutation differs');public+=1
        require(len(labels)==len(set(labels)),'Repeated native attack counted twice')
    return dict(status='INDEPENDENT_ACTUAL_INTERVAL_DRAINAGE_NATIVE_TRANSACTION_PASS',
                actual_refusals=compiled+public,compiled_refusals=compiled,accepted_receipt_refusals=public,actual_transactions=1)


def source_controls(root,bundle):
    root,bundle=Path(root),Path(bundle);q=read(root/'RESULT.json')
    meta=read(bundle/'BUILD.json');is_interval=meta['identity']['original_output'].get('groundwater_cde_interval') is True
    expected=9 if is_interval else 10
    require(q['status']=='ACTUAL_GROUNDWATER_INTERVAL_DRAINAGE_SOURCE_POLICY_REFUSALS_PASS' and
            q['actual_BUILD_sha256']==digest(bundle/'BUILD.json') and q['model_executions']==q['compilations']==0 and len(q['refusals'])==expected,'Actual source/policy campaign incomplete')
    fields=[]
    for item in q['refusals']:
        label=item['field'];fields.append(label);target=root/label;meta=read(target/'BUILD.json')
        require(item['before_worker'] is item['no_publication'] is True and item['error'].startswith('Foreign ') and
                not list(target.rglob('donor.stdout')) and not list(target.rglob('accepted-*.zip')),'Actual malicious source started worker/publication')
        if label.startswith('policy-'):
            field=label[len('policy-'):]
            require(all(i['original_output'][field]=='foreign' for i in (meta['identity'],meta['binding']['build'])),'Actual forged policy missing')
        else:
            name='original_cde_output_state.f90' if label=='cde-private-source' else 'headcalc.f90'
            require((target/name).read_bytes()!=(bundle/name).read_bytes() and
                    all(i['donor_generated'][name]==digest(target/name) for i in (meta['identity'],meta['binding']['build'])),'Actual source and forged mutable hash missing')
    require(len(set(fields))==expected,'Actual source attack denominator differs')
    return dict(status='INDEPENDENT_ACTUAL_INTERVAL_DRAINAGE_SOURCE_REFUSALS_PASS',actual_refusals=expected)


def postimages(root,profiles,bundles):
    root=Path(root);q=read(root/'RESULT.json');count=0
    require(q['status']=='ACTUAL_CURRENT_GROUNDWATER_CLOCK_SOURCE_GUARD_NATIVE_POSTIMAGE_PASS' and
            q['repeated_full_periods']==q['fresh_compilations']==0,'Current source postimage incomplete')
    for name,item in q['cases'].items():
        profile=Path(profiles[name]);bundle=Path(bundles[name]);receipt=profile/'RESULT.json'
        require(digest(receipt)==item['original_receipt_sha256'] and digest(bundle/'BUILD.json')==item['actual_BUILD_sha256'] and
                item['actual_origin_receipt_BUILD_unchanged'] is True,'Current postimage rebound original source or BUILD')
        build=read(bundle/'BUILD.json');selected=build['identity']['original_output'];warm=rows(profile/'trajectory')
        def outputs(path):return {n:original.output_records((path/n).read_bytes(),n) for n in ('result_output.csv','result_output.bin') if (path/n).is_file()}
        for window in item['cold']:
            low,high=window['start'],window['end'];cold=root/name/f'own-{low}';actual=rows(cold)
            require(physical(actual)==physical(warm[low:high]),'Current postimage physical continuation differs')
            with zipfile.ZipFile(profile/f'trajectory/accepted-column-1-day-{high}.zip') as a,zipfile.ZipFile(cold/f'accepted-column-1-day-{high}.zip') as b:
                require(all(a.read(n)==b.read(n) for n in ('result.end','macro.bin')),'Current complete native postimage differs')
                native(b.read('macro.bin'),actual[-1],build,selected)
            require(original.output_continuation(outputs(profile/'trajectory/original'),outputs(cold/'original'),selected,
                    low,high,build['project']['start_date'])==window['exact_original_output'],'Current exact user output postimage differs')
            count+=1
    return dict(status='INDEPENDENT_CURRENT_COMPOSED_POSTIMAGES_PASS',actual_cold_windows=count)
