"""Read-only complete component snapshots of the exact retained D restart."""
import argparse,contextlib,json,re,shutil,subprocess,sys
from pathlib import Path

PIN='640565a8dee425aad182101d37ee5afb2f6e14a5'

def saved_numeric(source):
    fields=[]
    for line in source.splitlines():
        match=re.match(r'\s*(real\([^)]*\)|integer|logical)(?!\w)(.*?\bsave\s*::\s*)(\w+)',line,re.I)
        if match:
            kind='real' if match[1].lower().startswith('real') else match[1].lower()
            fields.append((match[3],kind))
    return fields

def snapshot_source(selected,clock):
    fields=[]
    for module,file in [('plant_interface','interface_plant.f90'),('atmosphere_interface','interface_atmosphere.f90')]:
        for name,kind in saved_numeric((selected/file).read_text(encoding='cp1252')):
            fields.append((module,name,name,kind))
    for name,expression,kind in [
        ('h','h(1:numnod)','real'),('theta','theta(1:numnod)','real'),
        ('k','k(1:numnod+1)','real'),('kmean','kmean(1:numnod+1)','real'),
        ('dimoca','dimoca(1:numnod)','real'),('fhyst','fhyst(1:numnod)','real'),
        ('indeks','indeks(1:numnod)','integer'),
        *[(name,name,'real') for name in ('dt','dtold','pond','pondm1','gwl','volact')]]:
        fields.append(('variables',name,expression,kind))
    fields.append(('MOD_MvG','cofgen','cofgen(:,1:numnod)','real'))
    for name in ('tsoil','heacon','heacap'):
        fields.append(('MOD_SoilTemperature',name,name+'(1:numnod)','real'))
    for name in ('tetop','tebot'):fields.append(('MOD_SoilTemperature',name,name,'real'))
    for name in ('theatm','katm','q0','hsurf'):fields.append(('MOD_top',name,name,'real'))
    for name in ('FlRunoff','ftoph'):fields.append(('MOD_top',name,name,'logical'))
    imports=['module hybrid_state_diagnostic','use MOD_grid,only:numnod','use variables,only:t1900']
    writes=[];inventory=[]
    for i,(module,name,expression,kind) in enumerate(fields):
        alias='component_'+str(i)
        imports.append('use '+module+',only:'+alias+'=>'+name)
        expression=re.sub(r'^'+re.escape(name)+r'\b',alias,expression)
        fmt={'real':'es25.17e3','integer':'i0','logical':'l1'}[kind]
        label=module+'.'+name
        writes.append("write(*,'(a,*(1x,"+fmt+"))') 'DIAG_FIELD "+label+"',"+expression)
        inventory.append(dict(field=label,kind=kind,original_expression=expression.replace(alias,name)))
    text='\n'.join(imports)+f'''
implicit none
contains
subroutine hybrid_snapshot(phase)
character(*),intent(in)::phase
if(t1900<{clock}d0.or.t1900>{clock+1}d0)return
write(*,'(a,1x,a,1x,f18.8)')'DIAG_COMPONENT_BEGIN',phase,t1900
'''+ '\n'.join(writes)+'''
write(*,'(a)')'DIAG_COMPONENT_END'
end subroutine
end module
'''
    return text,inventory

def instrument_source(text,filename,replace):
    anchor='use MOD_grid, only: numnod' if filename=='swap_main.f90' else 'use MOD_grid,            only: numnod'
    text=replace(text,anchor,anchor+'\nuse hybrid_state_diagnostic,only:hybrid_snapshot')
    if filename=='swap_main.f90':
        for label,anchor in [('READY',"   write(*,'(a,1x,f16.8)') 'HYBRID_READY', t1900"),('DAY_RETURN',"      write(*,'(a,i0,1x,f18.8)') 'HYBRID_DAY_RETURN ', window, t1900")]:
            text=replace(text,anchor,"call hybrid_snapshot('"+label+"')\n"+anchor)
    else:
        for label,anchor in [('METEO2','            call Meteo(2)'),('METEO3','         call Meteo(3)')]:
            text=replace(text,anchor,"call hybrid_snapshot('BEFORE_"+label+"')\n"+anchor+"\ncall hybrid_snapshot('AFTER_"+label+"')")
        anchor='         call hybrid_apply_wofost(fl_cropemergence)'
        text=replace(text,anchor,anchor+"\ncall hybrid_snapshot('AFTER_MANAGEMENT_RESTORE')")
    return text

def snapshots(path,inventory):
    kinds={x['field']:x['kind'] for x in inventory};result=[];frame=None
    for line in path.read_text().splitlines():
        if line.startswith('DIAG_COMPONENT_BEGIN '):
            parts=line.split();frame=dict(phase=parts[1],clock=float(parts[2]),fields={})
        elif line.startswith('DIAG_FIELD '):
            parts=line.split();kind=kinds[parts[1]]
            convert=(lambda x:float(x.replace('D','E'))) if kind=='real' else (int if kind=='integer' else lambda x:x=='T')
            frame['fields'][parts[1]]=[convert(x) for x in parts[2:]]
        elif line.startswith('DIAG_COMPONENT_END'):
            assert len(frame['fields'])==len(inventory);result.append(frame);frame=None
    assert frame is None
    return result

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-root',type=Path,required=True);p.add_argument('--prior',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);p.add_argument('--reconnect-wofost-interface',action='store_true');a=p.parse_args()
    pinned=a.source_root.resolve();assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=pinned,text=True).strip()==PIN
    sys.path.insert(0,str(pinned/'tools/solute'));sys.path.insert(0,str(pinned/'app/hybrid_water'))
    import daily_host as h
    import experimental_project as e
    from daily_coupling import validate_bundle
    from check_nomacro_coverage import physical
    prior=a.prior.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    base=prior/'water-history-O0-build';ref=prior/'provider';project=e.load(prior/'input-water-history')
    meta,case=validate_bundle(base,ref,project);identity=meta['identity']
    assert h.sha(Path(shutil.which('gfortran')))==identity['compiler_sha256']
    objects=ref/'build/swap-obj';ttutil=ref/'build/ttutil-obj'
    for name,digest in identity['donor_objects'].items():assert h.sha(objects/name)==digest
    for directory,key in [(objects,'donor_modules'),(ttutil,'ttutil_modules')]:
        for name,digest in identity[key].items():assert h.sha(directory/name)==digest
    assert h.sha(ttutil/'libttutil.a')==identity['ttutil_library']
    source=prior/'water-history-O0-active-prefix/accepted-column-1-day-530.zip';digest=h.sha(source)
    origin=out/'verified-origin';receipt=h.verify_checkpoint(source,530,meta['binding'],origin)
    target=out/'private-carrier';shutil.copytree(base,target);(target/'BUILD.json').rename(target/'CARRIER_BUILD.json')
    for name in ('day_donor','day_kernel'):h.executable(target,name).chmod(0o755)
    replacements={Path(name).with_suffix('.o').name:target/Path(name).with_suffix('.o').name for name in identity['donor_generated']}
    linked=[str(replacements.get(q.name,q)) for q in sorted(objects.glob('*.o'))]+[str(target/'hybrid_step_budget.o'),str(ttutil/'libttutil.a')]
    logs=[]
    def compile(command):
        r=subprocess.run(command,cwd=target,capture_output=True,text=True,timeout=90)
        logs.append(dict(command=command,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr))
        (out/'COMPILATION.json').write_text(json.dumps(logs,indent=2)+'\n');assert r.returncode==0,r.stderr
    # Verify cached touched objects by reproducing the exact immutable executable.
    original_link=target/'unmodified-donor-check'
    compile(['gfortran','-o',str(original_link),*linked])
    assert h.sha(original_link)==meta['executable_sha256']['donor']
    diagnostic,inventory=snapshot_source(ref/'build/swap-selected',project.start_clock+530)
    (target/'hybrid_state_diagnostic.f90').write_text(diagnostic)
    for filename in ('swap.f90','swap_main.f90'):
        path=target/filename;assert h.sha(path)==identity['donor_generated'][filename]
        text=path.read_text(encoding='cp1252')
        text=instrument_source(text,filename,h.replace)
        path.write_text(text,encoding='cp1252')
    if a.reconnect_wofost_interface:
        path=target/'wofost.f90';assert h.sha(path)==identity['donor_generated']['wofost.f90']
        text=h.replace(path.read_text(encoding='cp1252'),'         r_act=hybrid_r_act',
            '         r_act=hybrid_r_act\n         call update_wofost_interface(s_pot,r_pot)\n         call update_wofost_interface(s_act,r_act)')
        path.write_text(text,encoding='cp1252')
    for filename in ('hybrid_state_diagnostic.f90',*(['wofost.f90'] if a.reconnect_wofost_interface else []),'swap.f90','swap_main.f90'):
        compile(['gfortran',*identity['donor_flags'],'-I',str(objects),'-I',str(ttutil),'-c',filename])
    compile(['gfortran','-o',str(h.executable(target,'day_donor')),*linked,str(target/'hybrid_state_diagnostic.o')])
    records={}
    for label,start,last in [('warm',h.ColumnStart(name='original'),531),('cold',h.ColumnStart(day=530,origin=origin,receipt=receipt,name='original'),1)]:
        model=out/label;model.mkdir();rows=[]
        with contextlib.ExitStack() as stack:
            host=h.DailyHost(stack,h.executable(target,'day_donor'),h.executable(target,'day_kernel'),case,model,[start],runtime=True,checkpoint_enabled=True,project=project)
            for _ in range(last):rows.append(host.step(1))
            host.close()
        assert not list(model.glob('accepted-*.zip'))
        records[label]=dict(last_row=rows[-1],snapshots=snapshots(model/'original/donor.stdout',inventory))
    oldwarm=json.loads((prior/'water-history-O0-active-prefix/daily.jsonl').read_text().splitlines()[530])
    oldcold=json.loads((prior/'water-history-O0-active-restart/daily.jsonl').read_text().splitlines()[0])
    assert physical(records['warm']['last_row'])==physical(oldwarm)
    if not a.reconnect_wofost_interface:assert physical(records['cold']['last_row'])==physical(oldcold)
    exact=physical(records['cold']['last_row'])==physical(records['warm']['last_row'])
    assert physical(oldwarm)!=physical(oldcold) and h.sha(source)==digest
    changes=[]
    warm={x['phase']:x for x in records['warm']['snapshots'] if x['clock']==project.start_clock+530}
    cold={x['phase']:x for x in records['cold']['snapshots'] if x['clock']==project.start_clock+530}
    for phase in sorted(set(warm)&set(cold)):
        for name,before in warm[phase]['fields'].items():
            after=cold[phase]['fields'][name]
            if before!=after:changes.append(dict(phase=phase,field=name,changed_entries=sum(x!=y for x,y in zip(before,after)),maximum_absolute_difference=max(abs(float(x)-float(y)) for x,y in zip(before,after))))
    status=('PRIVATE_COMPLETE_WOFOST_INTERFACE_RECONNECT_PASS' if exact else 'PRIVATE_COMPLETE_WOFOST_INTERFACE_RECONNECT_FAIL') if a.reconnect_wofost_interface else 'READ_ONLY_ORIGINAL_WATER_HISTORY_MISMATCH_EXACTLY_REPRODUCED'
    result=dict(status=status,interface_reconnected=a.reconnect_wofost_interface,cold_warm_physical_exact=exact,pinned_source=PIN,
        current_source=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),original_run=43416681903,
        origin_sha256=digest,origin_unchanged=True,no_publication=True,no_build_rebinding=True,
        original_executable_relink_exact=True,field_inventory=inventory,records=records,phase_differences=changes,
        private_sources={name:h.sha(target/name) for name in ('hybrid_state_diagnostic.f90','wofost.f90','swap.f90','swap_main.f90')},
        private_executable_sha256=h.sha(h.executable(target,'day_donor')),
        scope='Read-only original component-state evidence, not current public qualification or demonstrated causation')
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],flush=True)
    if a.reconnect_wofost_interface:assert exact,'Complete original interface reconnection did not reproduce warm physical state'

if __name__=='__main__':main()
