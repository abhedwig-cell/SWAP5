"""Exact composed native body provenance, accepted carriers and original replays."""
import base64,copy,gzip,json,math
from pathlib import Path
import composed_oxygen as run
from root_oxygen_evidence import audit as root_audit,data,table
from matched_oxygen_evidence import select as factor_select,output as factor_output
from pressure_oxygen_evidence import final_select,partition_output
from matched_micro_replay import source as literal_source
from film_runtime_profiles import profile4
sha=run.sha;ROOT=run.ROOT;BASE=run.BASE

def build_binding(folder,files,opt,reg=None):
    b=json.loads((folder/'BUILD.json').read_text());old=json.loads(files[opt+'/build/BUILD.json']);context=run.parent.audit.paths(old,opt)
    assert b['parent_build_sha256']==sha(files[opt+'/build/BUILD.json'])and b['compiler']==old['compiler']and b['production_admission']is False and b['whole_scientific_admission']is False
    clean=lambda flags:[x for x in flags if not x.startswith(('-I','-J'))]
    assert clean(b['flags'])==clean(old['flags'])and '-'+opt in b['flags']and '-fcheck=all'in b['flags']and '-ffpe-trap=invalid,zero,overflow'in b['flags']
    assert len(b['sources'])==236 and len(b['events'])==237 and b['events']==json.loads((folder/'EVENTS.json').read_text())and all(e['returncode']==0 for e in b['events'])
    replacements=run.replacements(reg);seen=set();objects=[]
    for i,(s,(name,pin))in enumerate(zip(b['sources'],old['source_sha256'].items())):
        raw=files[run.parent.audit.key(name,context,opt)];assert sha(raw)==pin and s['original']==name and s['before_sha256']==pin
        relative=next((n for n in replacements if name.replace('\\','/').endswith('/'+n)),None)
        expected=replacements[relative].encode()if relative else raw
        assert s['observation_patch']==relative and(folder/s['source']).read_bytes()==expected and sha(expected)==s['after_sha256']
        if relative:seen.add(relative)
        assert s['object']==str(i)+'.o'and sha((folder/s['object']).read_bytes())==s['object_sha256']
        event=b['events'][i];cmd=event['command'];assert clean(cmd[1:cmd.index('-c')])==clean(b['flags'])and cmd[-2]=='-o'
        assert cmd[cmd.index('-c')+1].replace('\\','/').endswith('/'+s['source'])and cmd[-1].replace('\\','/').endswith('/'+s['object']);objects.append(cmd[-1])
    assert seen==set(replacements)
    args=b['link_arguments'];offset=2 if run.os.name=='nt'and '-Wl,--stack,16777216'in args else(2 if '-Wl,--stack,16777216'in args else 1)
    assert args[:offset]==(['-fopenmp','-Wl,--stack,16777216']if offset==2 else['-fopenmp'])and args[offset:offset+236]==objects
    assert len(args)==offset+240 and args[-2]=='-o'
    assert args[-4].replace('\\','/').endswith('/publication.o')and args[-3].replace('\\','/').endswith('/libttutil.a')
    assert(folder/'link.args').read_text()=='\n'.join('"'+x.replace('\\','/')+'"'for x in args)+'\n'
    assert b['events'][-1]['command'][1].startswith('@')and b['events'][-1]['command'][1].replace('\\','/').endswith('/link.args')
    exe=folder/('observed.exe'if offset==2 else'observed');assert sha(exe.read_bytes())==b['executable_sha256']
    assert sha((folder/'publication.o').read_bytes())==b['publication_sha256']==old['publication_provider']['object_sha256']and sha((folder/'libttutil.a').read_bytes())==b['archive_sha256']==old['archive_sha256']
    return b

def replay_binding(folder,factors,finals,opt,compiler):
    original=json.loads((ROOT/'integration/audits/PPA_WU05C3A_B111_OXYGEN_SOURCE.json').read_text());literal=gzip.decompress(base64.b64decode(original['gzip_base64']));assert sha(literal)==original['sha256']
    factor=folder/'factor-replay';r=json.loads((factor/'REPLAY.json').read_text());assert r['compiler']==compiler and r['source_sha256']==original['sha256']and(factor/'oxygenstress.f90').read_bytes()==literal
    assert sha((factor/'oracle.exe').read_bytes())==r['executable_sha256']and '-'+opt in r['command']and '-fcheck=all'in r['command']and '-fbacktrace'in r['command']
    assert len(r['runs'])==len(factors);worst=0
    for i,(frame,event)in enumerate(zip(factors,r['runs'])):
        payload=('\n'.join(' '.join(f'{x:.17e}'for x in row)for row in frame)+'\n').encode();output=(factor/f'{i}.stdout').read_bytes()
        assert(factor/f'{i}.input').read_bytes()==payload and event['returncode']==0 and event['input_sha256']==sha(payload)and event['output_sha256']==sha(output)
        worst=max(worst,factor_output(output,frame))
    assert worst==r['maximum_factor_difference']
    partition=folder/'partition-replay';r=json.loads((partition/'REPLAY.json').read_text());source,metadata=literal_source()
    assert(partition/'literal.f90').read_text(encoding='utf-8')==source and r['metadata']==metadata and r['source_sha256']==sha(source.encode())and sha((partition/'partition.exe').read_bytes())==r['executable_sha256']
    assert '-'+opt in r['command']and '-fcheck=all'in r['command']and '-ffpe-trap=invalid,zero,overflow'in r['command']and len(r['runs'])==len(finals)
    maximum=0
    for i,(frame,event)in enumerate(zip(finals,r['runs'])):
        payload=('\n'.join(' '.join(f'{x:.17e}'for x in row)for row in frame)+'\n').encode();output=(partition/f'{i}.stdout').read_bytes()
        assert(partition/f'{i}.input').read_bytes()==payload and event['input_sha256']==sha(payload)and event['output_sha256']==sha(output)
        error=partition_output(output,frame);assert error==event['error'];maximum=max(maximum,error)
    return dict(maximum_original_factor_difference=worst,unchanged_factor_bound=1e-4,maximum_literal_partition_difference=maximum,unchanged_partition_bound=1e-14)

def audit(folder,files,origin,replays=True):
    assert json.loads((folder/'ORIGIN.json').read_text())==origin
    registration=json.loads((folder/'REGISTRATION.json').read_text());assert registration==json.loads((BASE/run.REG).read_text())and registration['production_admission']is False and registration['whole_scientific_admission']is False
    opt=origin['optimization'];reg=json.loads((folder/'SELECTED.json').read_text());old=json.loads(files[opt+'/build/BUILD.json']);parent=folder/'parent'
    assert(parent/'checkpoint-524.bin').read_bytes()==files[opt+'/full1096/checkpoint-524.bin']
    exe=parent/('model.exe'if origin['platform']=='windows'else'model');assert sha(exe.read_bytes())==old['executable_sha256']
    builds={p:build_binding(folder/p,files,opt,reg if p=='forcing-build'else None)for p in ('root-build','forcing-build')}
    names=json.loads((BASE/'PRESSURE_DIAGNOSTIC_INPUTS_20261104.json').read_text())['files_sha256'];records={}
    for phase,buildname in [('unobserved',None),('root-whole','root-build'),('root-own537','root-build'),('whole','forcing-build'),('own537','forcing-build')]:
        place=folder/phase;r=run.parent.audit.rotation.run_record(place);records[phase]=r
        assert r['returncode']==0 and r['diagnostic_override']is False and r['inputs']==names and r['executable_sha256']==(old['executable_sha256']if buildname is None else builds[buildname]['executable_sha256'])
        assert all((place/n).read_bytes()==files[opt+'/full1096/'+n]and sha((place/n).read_bytes())==pin for n,pin in names.items())
        is_tail=phase in ('root-own537','own537');whole='root-whole'if phase=='root-own537'else'whole'
        seed=(folder/whole/'checkpoint-537.bin').read_bytes()if is_tail else files[opt+'/full1096/checkpoint-524.bin']
        assert r['restart_sha256']==sha(seed)and profile4(seed)['day']==(537 if is_tail else 524)
        expected='STRICT_OWN_OBSERVED_BUILD_RESTART'if is_tail else('STRICT_OWN_PARENT_BUILD_RESTART'if phase=='unobserved'else'NUMERICALLY_IDENTICAL_BODY_ONLY_OBSERVATION_CODEC_CONTROL_NOT_SAME_BUILD_RESTART');assert r['scope']==expected
        assert(place/'checkpoint.bin').read_bytes()==files[opt+'/full1096/checkpoint-584.bin']
        for name,clock in [('budget.csv','t1_day'),('crop.csv','day')]:
            actual=table((place/name).read_bytes());expected=[x for x in table(files[opt+'/full1096/'+name])if(537 if is_tail else 524)<float(x[clock])<=584];assert actual==expected
        for prefix,unit in [('water','cm'),('solute','mg_cm2')]:
            budget=table((place/'budget.csv').read_bytes());defects=[float(x[prefix+'_end_'+unit])-float(x[prefix+'_start_'+unit])-float(x[prefix+'_in_'+unit])+float(x[prefix+'_out_'+unit])for x in budget]
            assert max(map(abs,defects))<=1e-10 and abs(math.fsum(defects))<=1e-8
    for whole,tail in [('root-whole','root-own537'),('whole','own537')]:
        for name in ('root_accepted.dat','root_nodes.dat'):
            assert(folder/tail/name).read_bytes().splitlines()==[line for line in(folder/whole/name).read_bytes().splitlines()if float(line.split()[0])>=537]
    for name in ('budget.csv','crop.csv','root_accepted.dat','root_nodes.dat'):assert(folder/'root-whole'/name).read_bytes()==(folder/'whole'/name).read_bytes()
    for name in ('oxygen_trials.dat','micro_trials.dat'):assert(folder/'own537'/name).read_bytes().splitlines()==[line for line in(folder/'whole'/name).read_bytes().splitlines()if float(line.split()[0])>=537]
    trace=data((folder/'whole/root_accepted.dat').read_bytes(),9);nodes=data((folder/'whole/root_nodes.dat').read_bytes(),104);budget=table((folder/'whole/budget.csv').read_bytes())
    assert reg==run.seams.selected(trace);point=profile4(files[opt+'/full1096/checkpoint-524.bin']);assert nodes[0][2:36]==point['head_cm']and nodes[0][36:70]==point['theta']
    report=root_audit(trace,nodes,budget);raw=data((folder/'whole/oxygen_trials.dat').read_bytes(),41);micro=data((folder/'whole/micro_trials.dat').read_bytes(),40)
    factors=factor_select(raw,nodes,trace,reg);finals=final_select(micro,nodes,trace,reg);controls=[]
    def refuse(name,fn):
        try:fn()
        except(AssertionError,StopIteration):controls.append(name)
        else:raise AssertionError('accepted composed oxygen defect '+name)
    for label in ('missing_leaf','duplicate_leaf','oxygen_rate','node_sink','daily_budget','nonfinite'):
        t,n,b=copy.deepcopy((trace,nodes,budget))
        if label=='missing_leaf':t.pop(0)
        elif label=='duplicate_leaf':t.insert(1,t[0])
        elif label=='oxygen_rate':t[0][4]+=1e-6
        elif label=='node_sink':n[0][70]+=1e-6
        elif label=='daily_budget':b[0]['oxygen_reduction_cm']=str(float(b[0]['oxygen_reduction_cm'])+1e-6)
        else:t[0][2]=float('nan')
        refuse(label,lambda:root_audit(t,n,b))
    for label in ('missing_factor','ambiguous_factor','wrong_head','missing_receipt'):
        r,n,a=copy.deepcopy((raw,nodes,trace))
        if label=='missing_factor':r=[x for x in r if x[:2]!=factors[0][0][:2]]
        elif label=='ambiguous_factor':extra=copy.deepcopy(factors[0]);extra[0][13]+=1;r+=extra
        elif label=='wrong_head':
            for x in r:
                if x[:2]==factors[0][0][:2]:x[11]+=1e-3
        else:a.remove(reg['selected_profiles'][0]['receipt'])
        refuse(label,lambda:factor_select(r,n,a,reg))
    altered=copy.deepcopy(micro)
    for x in altered:
        if x[:2]==finals[0][0][:2]:x[39]+=1e-6
    refuse('wrong_final_sink',lambda:final_select(altered,nodes,trace,reg))
    changed=copy.deepcopy(finals[0]);changed[0][4]+=1e-6;output=('ATTR '+' '.join(str(finals[0][0][i])for i in(3,4,5,27))+'\n').encode();refuse('falsified_partition_output',lambda:partition_output(output,changed))
    report.update(status='ACTUAL_COMPOSED_ACCEPTED_CARRIERS_AND_ORIGINAL_FACTORS_PARTITION_QUALIFIED',platform=origin['platform'],optimization=opt,selected_profiles=len(factors),rooted_nodes=sum(int(f[0][10])for f in factors),rejected_controls=controls,frames=[dict(time=f[0][:2],intermediate_loss=f[0][4],final_accepted_micro_loss=m[0][4])for f,m in zip(factors,finals)],oxygen584=dict(native=report['daily'][-1]['integrated']['oxygen_reduction_cm'],unchanged_full_series_limit=5.371840000016327e-7,full_series_science='PARENT36_OF37_OXYGEN_FAILED'),production_admission=False,whole_scientific_admission=False,migration_complete=False)
    if replays:report['original_replays']=replay_binding(folder,factors,finals,opt,old['compiler'])
    return report,factors,finals
