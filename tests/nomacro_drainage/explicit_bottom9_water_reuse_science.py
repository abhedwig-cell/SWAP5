"""Read the real O0 day2 continuation; retain its own checkpoint receipts."""
import io,json,re,zipfile
from analytical_hydraulic_archives import SHA
from explicit_bottom9_water_science import audit as water
from initial_profile_groundwater_science import ledger
from implicit_conductivity_forensics import general_checkpoint
from original_output_files import compare as outputs
from analytical_calendar_native_state import decode,terminal_terms


def audit(profile,campaign,reference,locations):
    initial=water(profile,reference,locations);q=json.loads((profile/'RESULT.json').read_text());c=json.loads((campaign/'RESULT.json').read_text())
    assert c['status']=='ACTUAL_OLD35DAY_PILOT_REUSED_REAL_NATIVE2_CONTINUATION_AND_THREE_EXACT_COLD_WINDOWS_PASS'
    assert c['original35day_pilot']==locations['original_profile_path'] and c['actual_compiled_producer']==q['source'] and c['full_initial35day_period_replayed'] is False
    assert c['continuous_reference_first_day']==3 and c['continuous_reference_last_day']==35 and len(c['cold'])==3
    warm=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()]
    full=campaign/'reference-from-real-day2';rows=[json.loads(line) for line in (full/'daily.jsonl').read_text().splitlines()];assert len(rows)==33
    fields=('stock_start_cm','stock_end_cm','external_flux_cm','pressure_head_cm','groundwater_cm','drainage_outward_cm','bottom_outward_cm')
    assert all(all(a[k]==b[k] for k in fields) for a,b in zip(rows,warm[2:]))
    source=(profile/'trajectory/accepted-column-1-day-2.zip').read_bytes();assert source==(full/'accepted-column-1-day-2.zip').read_bytes() and SHA(source)==c['actual_origin_sha256']
    meta=json.loads((locations['build']/'BUILD.json').read_text());selected={**meta['identity']['original_output'],'swhyst':0}
    text=(locations['inputs']/'swap.swp').read_text(encoding='cp1252');grid=re.search(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)',text);assert grid
    dz=[]
    for line in grid[1].splitlines():
        _,_,height,count=line.split();dz.extend([float(height)/int(count)]*int(count))
    assert len(dz)==34
    native=[]
    for path in full.glob('accepted-column-1-day-*.zip'):
        day=int(path.stem.split('-')[-1]);row=warm[1] if day==2 else rows[day-3]
        raw=path.read_bytes();observed=general_checkpoint(raw,meta,row,selected,dz)
        with zipfile.ZipFile(io.BytesIO(raw)) as z:
            saved=json.loads(z.read('checkpoint.json'));assert saved['receipt']==row and saved['binding']==meta['binding']
            assert all(SHA(z.read(name))==digest for name,digest in saved['files'].items())
            state,header=decode(z.read('macro.bin'),(locations['build']/'integral.f90').read_text(encoding='cp1252'),34)
            assert abs(sum(terminal_terms(state,row['stock_end_cm'])))<=1e-10
        native.append(dict(day=day,registered_native_observer=observed,calendar_header=list(header)))
    assert {i['day'] for i in native}=={2,4,19,23,30,34,35}
    cold=[]
    for item in c['cold']:
        start,end=item['start'],item['end'];folder=campaign/('own-'+str(start));own=[json.loads(line) for line in (folder/'daily.jsonl').read_text().splitlines()];assert len(own)==end-start
        assert all(all(a[k]==b[k] for k in fields) for a,b in zip(own,warm[start:end]))
        with zipfile.ZipFile(io.BytesIO((full/f'accepted-column-1-day-{end}.zip').read_bytes())) as a,zipfile.ZipFile(io.BytesIO((folder/f'accepted-column-1-day-{end}.zip').read_bytes())) as b:
            for name in ('macro.bin','result.end'):assert a.read(name)==b.read(name)
        actual=outputs(full/'original',folder/'original',selected,start,end,meta['project']['start_date']);assert actual==item['exact_user_output']
        cold.append(dict(start=start,end=end,complete_native_byte_exact=True,physical_exact=True,actual_user_output=actual))
    return dict(status='ACTUAL_ORIGINAL35_PERIOD_REAL_DAY2_CONTINUATION_NATIVE_RECEIPTS_AND_EXACT_COLD_WINDOWS_CENTRAL_REPLAY_PASS',original35day_science=initial,case=q['case'],optimization='O0',native=sorted(native,key=lambda i:i['day']),cold=cold,all33_physical_rows_exact_to_original=True,compiler_executions=0,model_executions=0,original_full_initial35_periods_replayed=0,canonical_admission=False)
