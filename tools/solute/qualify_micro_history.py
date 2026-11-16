"""Actual complete-history native decoder attacks and full daily cold continuation."""
import contextlib,hashlib,json,struct,zipfile
import daily_host as h
from daily_coupling import CoupledDailyColumn,validate_bundle


def physical(row):
    return {k:v for k,v in row.items() if k not in ('column','revision','committed','candidate_only','coupling')}


def payload(path):
    with zipfile.ZipFile(path) as z:return {n:z.read(n) for n in ('result.end','macro.bin')}


def malformed_active(origin,day,project,label,reuse,out,call):
    digest=h.sha(origin)
    with zipfile.ZipFile(origin) as z:members={n:z.read(n) for n in z.namelist()}
    raw=members['macro.bin'];size=struct.unpack_from('=i',raw,len(raw)-4)[0];start=len(raw)-size
    assert struct.unpack_from('=8i',raw,start)[1]==1
    changes=[]
    def replace(name,offset,fmt,value):
        changes.append((name,raw[:offset]+struct.pack(fmt,value)+raw[offset+struct.calcsize(fmt):]))
    for i,name,value in [(0,'version',9),(1,'absent',0),(2,'crop',999),(3,'drought',0),(4,'model',9),
                         (5,'layers',999),(6,'mrows',429),(7,'krows',430)]:replace(name,start+4*i,'=i',value)
    replace('clock',start+32,'=d',0.)
    for i,name in [(start+40,'M'),(start+40+430*struct.unpack_from('=i',raw,start+20)[0]*8,'K')]:
        replace(name+'-nan',i,'=d',float('nan'));replace(name+'-negative',i,'=d',-1.)
    replace('trailer',len(raw)-4,'=i',size+8)
    changes.extend([('short',raw[:-1]),('outer-eof',raw+b'x')])
    for name,data in changes:
        changed=dict(members);changed['macro.bin']=data
        manifest=json.loads(changed['checkpoint.json']);manifest['files']['macro.bin']=hashlib.sha256(data).hexdigest()
        changed['checkpoint.json']=json.dumps(manifest).encode()
        checkpoint=out/(label+'-micro-'+name+'.zip')
        with zipfile.ZipFile(checkpoint,'w') as z:
            for n,value in changed.items():z.writestr(n,value)
        target=out/(label+'-micro-refused-'+name)
        call(label+'-micro-'+name,reuse+['--output',target,'--days',day+1,'--restart',checkpoint,'--restart-day',day],refuse=True)
        assert not list(target.glob('accepted-*.zip')) and h.sha(origin)==digest
    return dict(count=len(changes),active_day=day,origin_sha256=digest,origin_unchanged=True,no_accepted_publication=True)


def every_day(bundle,reference,project,out,expected):
    out.mkdir();meta,case=validate_bundle(bundle,reference,project)
    warmdir=out/'warm';warmdir.mkdir()
    cold=CoupledDailyColumn(bundle,reference,out/'cold',project,'complete-history-daily')
    events=[]
    with contextlib.ExitStack() as stack:
        warm=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,warmdir,
             [h.ColumnStart()],runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=project)
        with (out/'daily.jsonl').open('w') as log:
            for day in range(1,project.last_day+1):
                row=warm.step(1,checkpoint=True)
                assert row['committed'] and physical(row)==physical(expected[day-1]),(day,'warm reference')
                proposal=cold.prepare()
                assert physical(proposal.budget)==physical(row),(day,'cold physical')
                assert payload(cold._candidate[3])==payload(warmdir/f'accepted-column-1-day-{day}.zip'),(day,'cold native')
                if day in (2,365,530,531,730,1095):
                    old=cold.checkpoint;digest=h.sha(old) if old else None
                    cold.discard(proposal);assert old is None or h.sha(old)==digest
                    replay=cold.prepare();assert replay.budget==proposal.budget
                    proposal=replay
                cold.accept(proposal)
                log.write(json.dumps(dict(day=day,physical_exact=True,native_exact=True,checkpoint_sha256=h.sha(cold.checkpoint)))+'\n');log.flush()
                if day in (365,530,730):
                    cold=CoupledDailyColumn(bundle,reference,out/f'recovered-{day}',project,'complete-history-daily',origin=cold.checkpoint,day=day)
                    events.append(day)
        warm.close()
    return dict(days=project.last_day,every_physical_exact=True,every_native_exact=True,disk_recovery_days=events)
