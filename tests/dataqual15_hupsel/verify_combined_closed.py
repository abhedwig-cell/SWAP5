"""Portable verification of the closed combined DATAQUAL15 execution capsule.

Uses only Python's standard library and repository-relative paths. Does not
execute a replacement model, trust old absolute workspace paths, or promote
experimental functionality to production.
"""
import argparse, csv, hashlib, io, json, math, struct, tarfile, zlib
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]
sha = lambda data: hashlib.sha256(data).hexdigest()
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--root', type=Path, default=ROOT)
p.add_argument('--archive', type=Path)
p.add_argument('--receipt', type=Path)
a = p.parse_args()
root = a.root.resolve()
folder = root/'integration/dataqual15_hupsel'
receipt = json.loads((a.receipt or folder/'COMBINED_CLOSED_RESULT.json').read_text())
archive = a.archive or folder/'COMBINED_CLOSED_EVIDENCE.tar.xz'
assert sha(archive.read_bytes()) == receipt['archive_sha256'], 'archive digest'
with tarfile.open(archive, 'r:xz') as tar:
    files = {}
    for item in tar:
        name = PurePosixPath(item.name)
        assert item.isfile() and not name.is_absolute() and '..' not in name.parts
        assert item.name not in files, item.name
        files[item.name] = tar.extractfile(item).read()
manifest = json.loads(files['MANIFEST.json'])
assert set(files) == set(manifest)|{'MANIFEST.json'}
assert len(files) == receipt['archive_members']
for name, digest in manifest.items(): assert sha(files[name]) == digest, name
qualification = json.loads(files['QUALIFICATION.json'])
assert qualification['repository_source_sha256'] == receipt['repository_source_sha256']
for name, digest in receipt['repository_source_sha256'].items():
    assert sha(files['source/repository/'+name]) == digest, name
    assert sha((root/name).read_bytes()) == digest, 'checkout source differs: '+name
baseline=js_baseline=json.loads(files['BASELINE_PRODUCTION_SHA256.json'])
current={p.relative_to(root).as_posix():sha(p.read_bytes()) for area in ['src','app'] for p in (root/area).rglob('*') if p.is_file()}
delta={name:current.get(name) for name in set(baseline)|set(current) if baseline.get(name)!=current.get(name)}
assert delta==receipt['reviewed_production_delta'], 'unreviewed production path or content change'
for label, build in qualification['normalized_builds'].items():
    assert len(build['source_sha256']) == build['provider_count']
    for name, digest in build['source_sha256'].items(): assert sha(files[name]) == digest, name
    assert sha(files['binaries/'+label]) == build['executable_sha256']
    raw=json.loads(files['builds/'+label+'/BUILD.json'])
    events=json.loads(files['builds/'+label+'/EVENTS.json']) if 'builds/'+label+'/EVENTS.json' in files else raw['events']
    assert events and all(e['returncode']==0 for e in events), label+' compilation/link/native event'
assert sha(files['ttutil/libttutil.a']) == qualification['ttutil_sha256']
for case_name, relative in qualification['original_input_map'].items():
    assert files[case_name] == files['source/repository/'+relative]

def js(name): return json.loads(files[name])
def rows(name): return list(csv.DictReader(io.StringIO(files[name].decode())))
def crc(data):
    assert len(data)>12 and zlib.crc32(data[:-4]) == struct.unpack_from('=I',data,len(data)-4)[0]
def grass(data):
    crc(data); assert data[:8] == b'S5GRS003'
    pos=8; embedded=[]
    for _ in range(6):
        n=struct.unpack_from('=i',data,pos)[0];assert 0<n<2097152
        pos+=4;embedded.append(data[pos:pos+n]);pos+=n
    nodes,clock=struct.unpack_from('=id',data,pos);assert nodes==113 and clock==int(clock)
    expected=['input.swp','grass.crp','input.met','swap.bbc','swap.dra']
    for value,name in zip(embedded[:5],expected): assert value==files['cases/grass-full367/'+name]
    return data[pos:-4],clock
def hupsel(data):
    crc(data);assert data[:8]==b'S5HR0003'
    clock,nodes=struct.unpack_from('=di',data,8);assert nodes==34 and clock==int(clock)
    pos=20
    for name in ['swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra']:
        n=struct.unpack_from('=i',data,pos)[0];assert 0<n<16777216;pos+=4
        assert data[pos:pos+n]==files['cases/hupsel-full1096/'+name];pos+=n
    n=struct.unpack_from('=i',data,pos)[0];pos+=4;inner=data[pos:pos+n]
    crc(inner);assert inner[:8]==b'S5HG0002' and struct.unpack_from('=d',inner,12)[0]==clock
    nphysical=struct.unpack_from('=i',inner,84)[0];physical=inner[88:88+nphysical]
    assert len(physical)+92==len(inner) and physical[:6]==b'S5PT00';crc(physical)
    return clock

positive=['grass-full367','grass-restart365','hupsel-full1096','hupsel-restart584',
          'hupsel-restart730','hupsel-restart868','hupsel-tail1058-O0','hupsel-restart1077-O0']
for label in positive:
    result=js('cases/'+label+'/RESULT.json');assert result['returncode']==0 and not result['censored']
    expected_end=367 if label.startswith('grass') else 731 if label=='hupsel-restart730' else 591 if label=='hupsel-restart584' else 1096
    assert result['requested_days']==expected_end and result['completed_days']==expected_end
    build_label='grass-O2' if label.startswith('grass') else 'hupsel-O0' if label.endswith('O0') else 'hupsel-O2'
    raw_build=js('builds/'+build_label+'/BUILD.json')
    assert result['source_sha256']==raw_build['source_sha256'], label+' executed source binding'
    if label.startswith('grass'):
        assert result['executable_sha256']==qualification['normalized_builds'][build_label]['executable_sha256']
    else:
        assert not result['diagnostic_predecessor']
        build_directory=next(flag[2:] for flag in raw_build['flags'] if flag.startswith('-I'))
        assert Path(result['command'][0]).parent==Path(build_directory), label+' executable binding'
    for name,data in files.items():
        if name.startswith('cases/'+label+'/') and name.endswith('.bin'):
            if data[:8]==b'S5GRS003': grass(data)
            elif data[:8]==b'S5HR0003': hupsel(data)
            else: raise AssertionError('unexpected positive checkpoint '+name)

full='cases/hupsel-full1096/'
assert hupsel(files[full+'restart.bin'])==1096
assert files[full+'restart.bin']==files[full+'checkpoint.bin']
for name in ['budget.csv','crop.csv','germination.csv','endpoint.csv','state.csv','temperature.csv','restart.bin','checkpoint.bin']:
    assert files[full+name]==files['golden/hupsel/'+name], 'baseline Hupsel '+name
gp='cases/grass-full367/'
assert grass(files[gp+'checkpoint.bin'])[1]==367
assert grass(files[gp+'checkpoint.bin'])[0]==grass(files['golden/grass/checkpoint-367.bin'])[0]
for name in ['budget.csv','crop.csv']: assert files[gp+name]==files['golden/grass/'+name]
assert [int(r['day']) for r in rows(gp+'budget.csv')]==list(range(1,368))
assert [int(r['day']) for r in rows(gp+'crop.csv')]==list(range(1,368))
# Original maize is prescribed rather than WOFOST: its first494 days are
# covered by the full daily water/root-demand ledger, not invented biomass rows.
assert [int(r['day']) for r in rows(full+'crop.csv')]==list(range(495,1097))
daily=rows(full+'budget.csv');assert float(daily[0]['t0_day'])==0 and float(daily[-1]['t1_day'])==1096
assert sorted({int(float(r['t1_day'])) for r in daily if float(r['t1_day']).is_integer()})==list(range(1,1097))
for previous,next_row in zip(daily,daily[1:]):
    assert float(previous['t1_day'])==float(next_row['t0_day'])
    for kind,unit in [('water','cm'),('solute','mg_cm2')]:
        left=float(previous[kind+'_end_'+unit]);right=float(next_row[kind+'_start_'+unit])
        assert abs(left-right)<=64*math.ulp(1.0)*max(1.,abs(left),abs(right)), kind+' inter-window continuity'
assert all(float(r['t1_day'])>float(r['t0_day']) for r in daily)
assert files['cases/grass-restart365/checkpoint.bin']==files[gp+'checkpoint.bin']
for name in ['budget.csv','crop.csv']:
    assert rows('cases/grass-restart365/'+name)==[r for r in rows(gp+name) if float(r['day'])>365]

for label,start,end,checkpoint in [('hupsel-restart730',730,731,'checkpoint-731.bin'),
    ('hupsel-restart584',584,591,'checkpoint-591.bin'),('hupsel-restart868',868,1096,'restart.bin'),
    ('hupsel-tail1058-O0',1058,1096,'restart.bin'),('hupsel-restart1077-O0',1077,1096,'restart.bin')]:
    prefix='cases/'+label+'/'
    assert files[prefix+'restart.bin']==files[full+checkpoint], label+' native'
    for name,key in [('budget.csv','t1_day'),('crop.csv','day')]:
        actual=rows(prefix+name);expected=[r for r in rows(full+name) if start<float(r[key])<=end]
        if label=='hupsel-restart584' and name=='crop.csv':
            # A read-only pre-emergence diagnostic is deliberately not a
            # continuation variable after emergence. It cannot affect physics.
            for row in actual+expected: row.pop('pressure_average_cm')
        assert actual==expected, label+' '+name
assert files['cases/hupsel-tail1058-O0/restart-origin.bin']==files[full+'checkpoint-1058.bin']

balances={}
for label in ['hupsel-full1096','hupsel-tail1058-O0','grass-full367']:
    data=rows('cases/'+label+'/budget.csv');assert data
    report=js('cases/'+label+'/RESULT.json')
    keys=['water_residual_cm','solute_residual_mg_cm2','observed_heat_residual_j_cm2'] if label.startswith('hupsel') else ['residual_cm','heat_residual_j_cm2']
    for row in data:
        for key,value in row.items(): assert math.isfinite(float(value)), (label,key)
        if label.startswith('hupsel'):
            for kind,unit in [('water','cm'),('solute','mg_cm2')]:
                values=[float(row[kind+'_end_'+unit]),float(row[kind+'_start_'+unit]),float(row[kind+'_in_'+unit]),float(row[kind+'_out_'+unit])]
                recomputed=values[0]-values[1]-values[2]+values[3]
                # Bound only roundoff in regrouping the accepted daily ledger;
                # this is not an additional model acceptance tolerance.
                rounding=256*math.ulp(1.0)*max(1.,sum(map(abs,values)))
                assert abs(recomputed-float(row[kind+'_residual_'+unit]))<=rounding
    balances[label]={key:max(abs(float(r[key])) for r in data) for key in keys}
    bounds=qualification['hard_bounds']
    if label.startswith('hupsel'):
        assert balances[label]['water_residual_cm']==report['maximum_water_residual_cm']
        assert balances[label]['solute_residual_mg_cm2']==report['maximum_solute_residual_mg_cm2']
        assert balances[label]['water_residual_cm']<=bounds['water_cm']
        assert balances[label]['solute_residual_mg_cm2']<=bounds['solute_mg_cm2']
        assert balances[label]['observed_heat_residual_j_cm2']<=bounds['heat_j_cm2']
    else:
        assert balances[label]['residual_cm']<=bounds['water_cm']
        assert balances[label]['heat_residual_j_cm2']<=bounds['heat_j_cm2']

controls=0
for label in ['hupsel-guards730-O2','hupsel-guards868-O2','hupsel-guards1077-O0']:
    report=js('cases/'+label+'/RESULT.json');assert len(report['events'])==37
    for event in report['events']:
        assert event['status']=='PASS' and event['returncode']==1
        assert event['reached_post_read_boundary']==(event['case']=='valid_nonadvancing')
    controls+=37
guard=js('cases/grass-guards365/RESULT.json');assert len(guard['events'])==11
assert all(e['returncode']!=0 for e in guard['events'])
assert not qualification['full_scientific_equivalence'] and not qualification['production_promoted'] and not qualification['canonically_admitted']
print(json.dumps(dict(status='PASS',repository_sources=len(receipt['repository_source_sha256']),members=len(files),
    hupsel_original_days=1096,grass_preserved_days=367,hupsel_decoder_checks=controls,grass_invalid_checks=11,
    balances=balances,scientific_equivalence=False,production_promoted=False),indent=2))
