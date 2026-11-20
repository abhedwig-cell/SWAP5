"""Independent actual malformed native/source and current-postimage observers."""
import hashlib
import json
from pathlib import Path
import struct
import zipfile

from ordinary_pond_evidence import read,digest,rows,physical,require
from groundwater_snow_forensics import native
import implicit_conductivity_forensics as original


def native_controls(root,profile,bundle):
    root,profile,bundle=Path(root),Path(profile),Path(bundle);q=read(root/'RESULT.json');build=read(bundle/'BUILD.json')
    require(q['status']=='ACTUAL_EXPLICIT_SNOW_GROUNDWATER_CDE_COMPILED_NATIVE_TRANSACTION_PASS' and
            q['actual_BUILD_sha256']==digest(bundle/'BUILD.json') and all(v is True for v in q['transactions'].values()),'Incomplete actual native/transaction campaign')
    selected=build['identity']['original_output'];hys=selected['swhyst'];n=build['project']['nodes']
    with zipfile.ZipFile(profile/'trajectory/accepted-column-1-day-4.zip') as z:before=z.read('macro.bin')
    row=rows(profile/'trajectory')[3];parsed=native(before,row,build,selected)
    is_interval=selected.get('groundwater_cde_interval') is True
    require(len(q['clock_refusals'])==(77 if is_interval else 80) and len(q['groundwater_refusals'])==29,'Actual native refusal denominator differs')
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
                offset=parsed['groundwater_domain_offset']+104;value=struct.unpack_from('<d',before,offset)[0]+1.
                expected=bytearray(before);struct.pack_into('<d',expected,offset,value)
                require(bad==bytes(expected),'Actual public head mutation differs');public+=1
        require(len(labels)==len(set(labels)),'Repeated native attack counted twice')
    return dict(status='INDEPENDENT_ACTUAL_SNOW_GROUNDWATER_NATIVE_TRANSACTION_PASS',
                actual_refusals=compiled+public,compiled_refusals=compiled,accepted_receipt_refusals=public,actual_transactions=1)


def source_controls(roots,bundle):
    roots=[Path(roots)] if isinstance(roots,(str,Path)) else [Path(root) for root in roots]
    bundle=Path(bundle);build=read(bundle/'BUILD.json');selected=build['identity']['original_output']
    expected=27 if selected.get('groundwater_cde_interval') else 30 if selected['flprintdt'] else 29
    source_names={'head-relaxed-guard':'headcalc.f90','head-missing-guard':'headcalc.f90','head-foreign-parent':'headcalc.f90',
        'cde-private-source':'original_cde_output_state.f90','snow-private-source':'thermal_output_snow_calendar_state.f90',
        'thermal-domain-source':'original_output_thermal_domain.f90','groundwater-native-source':'groundwater_history_native_state.f90',
        'timecontrol-source':'timecontrol.f90','pond-event-source':'implicit_pond_event_state.f90',
        'pond-availability-source':'implicit_pond_availability.f90','top-boundary-source':'boundtop.f90'}
    fields=[];failed=0
    for root in roots:
        q=read(root/'RESULT.json')
        if q['status']=='FAILED':
            require(q['error']=="AssertionError(('timecontrol-source', 'Foreign complete parent Snow groundwater TimeControl provider'))",'Unexpected failed source producer')
            failed+=1
        else:require(q['status'] in ('ACTUAL_EXPLICIT_SNOW_GROUNDWATER_SOURCE_POLICY_REFUSALS_PASS','ACTUAL_SELECTED_SNOW_GROUNDWATER_SOURCE_POLICY_REFUSALS_PASS'),'Actual source campaign incomplete')
        require(q['actual_BUILD_sha256']==digest(bundle/'BUILD.json') and q['model_executions']==q['compilations']==0,'Actual source context rebound')
        for item in q['refusals']:
            label=item['field'];fields.append(label);target=root/label;meta=read(target/'BUILD.json')
            require(item['before_worker'] is item['no_publication'] is True and item['error'].startswith('Foreign ') and
                    not list(target.rglob('donor.stdout')) and not list(target.rglob('accepted-*.zip')),'Actual malicious source started worker/publication')
            if label.startswith('policy-'):
                field=label[len('policy-'):]
                require(field in selected and all(i['original_output'][field]=='foreign' for i in (meta['identity'],meta['binding']['build'])),'Actual forged policy missing')
            else:
                require(label in source_names,'Foreign source attack')
                name=source_names[label]
                require((target/name).read_bytes()!=(bundle/name).read_bytes() and
                        all(i['donor_generated'][name]==digest(target/name) for i in (meta['identity'],meta['binding']['build'])),'Actual source and forged mutable hash missing')
    require(len(fields)==len(set(fields))==expected and set(source_names)<=set(fields),'Actual source attack denominator differs')
    return dict(status='INDEPENDENT_ACTUAL_SNOW_GROUNDWATER_SOURCE_REFUSALS_PASS',actual_refusals=expected,
                original_failed_producers_preserved=failed)
