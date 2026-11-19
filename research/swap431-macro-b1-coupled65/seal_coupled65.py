"""Content-address raw evidence once; verify every byte before retention cleanup."""
from pathlib import Path
import hashlib,json,subprocess,sys,zipfile
R=Path(__file__).resolve().parent
D=Path(sys.argv[1])
BASE='15d14a7b5679b6e11a97414e29a09738e09b9a29'
def digest(data):return hashlib.sha256(data).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=R)
def save(name,q):(R/name).write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
refs=git('for-each-ref','--sort=-committerdate','--format=%(objectname) %(refname)','refs/heads/codex/swap431-macro-b1','refs/remotes/origin/codex/swap431-macro-b1').decode().splitlines()
reconcile=dict(experimental_baseline=BASE,canonical=git('rev-parse','origin/integration/f-ci-canonical').decode().strip(),refs_at_seal=refs,latest_concurrent_completed_negative='95a61203d345ccbf2c8f5851c37a0bb138a00835',known_cause_reopened=False,read_statuses=[])
paths=git('ls-tree','-r','--name-only',BASE,'research').decode().splitlines()
selected=['accept01','active27','rollback49','select50','inactive51','restore52','geometry53','georestore54','native55','diag56','dtmin57','dtmin58','node59','factor60','potential61','combined62','combined63']
for unit in selected:
    p='research/swap431-macro-b1-'+unit+'/STATUS.json'
    if p in paths:
        raw=git('show',BASE+':'+p);q=json.loads(raw)
        reconcile['read_statuses'].append(dict(path=p,ref=BASE,sha256=digest(raw),decision=q.get('decision',q.get('qualification',q.get('stage')))))
p='research/swap431-macro-b1-reject64/STATUS.json';raw=git('show','95a61203:'+p);q=json.loads(raw)
reconcile['read_statuses'].append(dict(path=p,ref='95a61203d345ccbf2c8f5851c37a0bb138a00835',sha256=digest(raw),decision=q['decision']))
save('RECONCILIATION.json',reconcile)
source=[]
for p in paths:
    if p.startswith('research/swap431-macro-b1-reject64/') and (p.endswith('.f90') or p.endswith('_BUILD.json') or p.endswith('_IDENTITY.json') or p.endswith('HARNESS.patch')):
        raw=git('show',BASE+':'+p);source.append(dict(path=p,ref=BASE,sha256=digest(raw),bytes=len(raw)))
save('SOURCE_IDENTITY.json',dict(source=source,compiler='GNU Fortran (Rev4, Built by MSYS2 project) 16.2.0',unchanged_solver_and_physics=True,new_builds=0,original_BUILD_and_IDENTITY_records_are_authority=True))
archive=R/'COUPLED65_RAW.zip';assert not archive.exists()
manifest=[];seen=set()
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in sorted(D.rglob('*')):
        if not p.is_file():continue
        raw=p.read_bytes();h=digest(raw);manifest.append(dict(path=p.relative_to(D).as_posix(),bytes=len(raw),sha256=h))
        if h not in seen:z.writestr('blobs/'+h,raw);seen.add(h)
    z.writestr('manifest.json',json.dumps(manifest,indent=2)+'\n')
with zipfile.ZipFile(archive) as z:
    for x in manifest:
        raw=z.read('blobs/'+x['sha256']);assert len(raw)==x['bytes'] and digest(raw)==x['sha256']
save('EVIDENCE.json',dict(file=archive.name,sha256=digest(archive.read_bytes()),bytes=archive.stat().st_size,logical_files=len(manifest),unique_blobs=len(seen),all_members_verified=True,layout='manifest.json maps complete route-relative files to blobs/sha256; no lossy compression',source_identity='SOURCE_IDENTITY.json',inherited_build_closure_ref=BASE,inherited_raw_COMBINED63='research/swap431-macro-b1-combined63/EVIDENCE.json',data_retention='All new raw, full case inputs, binary start/end packets and diagnostics retained; identical content stored once. Existing sealed build closure is inherited at exact ref, not duplicated.'))
print(json.dumps(dict(files=len(manifest),unique=len(seen),archive_bytes=archive.stat().st_size,sha256=digest(archive.read_bytes()))))
