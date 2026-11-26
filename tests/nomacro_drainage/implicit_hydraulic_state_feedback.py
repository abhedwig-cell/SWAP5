"""Actual original-input implicit constitutive/state feedback; no qualification claim."""
import argparse,hashlib,io,json,subprocess,sys,time,zipfile
from contextlib import ExitStack
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource
from original_output_baseline import assignment
from explicit_bottom9_runtime import m,own
from implicit_hydraulic_state import selected,validate_candidate
from frost_boundary_convergence import require_convergence
BASE='22520105f5a3ccac2bd2ae1b726f27b7b0d67b1e'
SHA=lambda b:hashlib.sha256(b).hexdigest()
CASES={
    'model3-water':dict(models=[3],solute=0,snow=0,initial=2),
    'model4-snow-water':dict(models=[4],solute=0,snow=1,initial=2),
    'model5-cde-profile':dict(models=[5],solute=1,snow=0,initial=1),
    'model6-snow-cde-profile':dict(models=[6],solute=1,snow=1,initial=1),
    'mixed8-9-water':dict(models=[8,9],solute=0,snow=0,initial=2),
    'mixed10-11-snow-water':dict(models=[10,11],solute=0,snow=1,initial=2),
    'mixed1-7-cde':dict(models=[1,7],solute=1,snow=0,initial=2),
}


def main():
    p=argparse.ArgumentParser()
    for name in ['output','build-output','reference-work']:p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--case',choices=['gardner-water','model7-snow-cde','model7-snow-cde-fitted',*CASES],required=True)
    p.add_argument('--optimization',choices=['O0','O2'],required=True)
    p.add_argument('--days',type=int,default=35)
    a=p.parse_args();assert a.days in (8,35)
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()
    assert not subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all'],cwd=R)
    a.output.mkdir();inputs=a.output/'inputs';inputs.mkdir();q=dict(status='RUNNING_ACTUAL_IMPLICIT_HYDRAULIC_STATE_FEEDBACK_NOT_ADMITTED',actual_source=head,case=a.case,optimization=a.optimization,canonical_admission=False,input_root=str(inputs),build_root=str(a.build_output/'bundle'),days=a.days)
    save=lambda:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        specification=CASES.get(a.case)
        fitted=a.case=='model7-snow-cde-fitted' or specification is not None
        solute=specification['solute'] if specification else int(a.case=='model7-snow-cde-fitted')
        name=('ORDINARY_IMPLICIT_POND_UBUNTU_FOLLOWUP_O0_RAW_ARCHIVE' if a.case=='gardner-water' or fitted else 'FROST_ANALYTICAL_BOUNDARY10_SEARCH_WINDOWS_O0_ORIGINAL_V1')
        prefix=('ordinary-matrix/cde-head-history1/input/' if fitted and solute else 'ordinary-matrix/water-plate/input/' if a.case=='gardner-water' or fitted else 'current-unaffected-postimages/model7-cde-d1-b8-dense/inputs/')
        with ExitStack() as stack:
            source=GitArchiveSource(R,BASE)
            descriptor=json.loads((source/(name+'.json')).read_text())
            if 'parts' in descriptor:
                archive=Archive(source,name,stack);names=archive.names;get=archive.get
            else:
                raw=(source/descriptor['archive']).read_bytes()
                assert len(raw)==descriptor['bytes'] and SHA(raw)==descriptor['sha256']
                z=stack.enter_context(zipfile.ZipFile(io.BytesIO(raw)));names=descriptor['members']
                assert len(z.namelist())==len(set(z.namelist()))==len(names) and set(z.namelist())==set(names)
                def get(n):
                    value=z.read(n);assert len(value)==names[n]['bytes'] and SHA(value)==names[n]['sha256'];return value
            for n in names:
                if n.startswith(prefix):
                    target=inputs/n[len(prefix):];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(get(n))
            q['input_authority']=dict(actual_git_source=BASE,archive=name,archive_sha256=descriptor['sha256'],prefix=prefix)
        path=inputs/'swap.swp';before=path.read_bytes();text=before.decode('cp1252')
        edits=({'iHWCKmodel':'2'} if a.case=='gardner-water' else dict(SWHYST=0,SWSNOW=1,iHWCKmodel=7) if a.case=='model7-snow-cde-fitted' else dict(SWFROST=0,SWKIMPL=1))
        if specification:
            edits=dict(SWHYST=0,SWSNOW=specification['snow'],SWINCO=specification['initial'],iHWCKmodel=' '.join(map(str,specification['models'])))
        if fitted:
            import re
            with ExitStack() as stack:
                donor_name='FROST_ANALYTICAL_BOUNDARY10_SEARCH_WINDOWS_O0_ORIGINAL_V1'
                donor=Archive(GitArchiveSource(R,BASE),donor_name,stack)
                member='current-unaffected-postimages/model7-cde-d1-b8-dense/inputs/swap.swp';value=donor.get(member)
                named={}
                keys=(['ALFA_2','NPAR_2','OMEGA_1','H0'] if not specification else
                      [*(['ALFA_2','NPAR_2','OMEGA_1'] if any(v in (6,7,10,11) for v in specification['models']) else []),
                       *(['H0'] if any(v in (5,7,8,9,10,11) for v in specification['models']) else []),
                       *(['HA','APAR','OMEGA_K','SWVAPOR'] if any(v>=8 for v in specification['models']) else [])])
                for key in keys:
                    rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[^\r\n]*(?:\r?\n|$)',value.decode('cp1252'));assert len(rows)==1
                    assert not re.search(r'(?mi)^[ \t]*'+key+r'[ \t]*=',text)
                    named[key]=rows[0];text+='\n'+rows[0]
                q['additional_original_parameter_authority']=dict(actual_git_source=BASE,archive=donor_name,archive_sha256=donor.record['sha256'],member=member,member_sha256=SHA(value),literal_original_named_lines=named,existing_parameter_table_unchanged=True,numerical_controls_unchanged=True)
        for key,value in edits.items():
            import re
            text=assignment(text,key,value) if re.search(r'(?mi)^\s*'+key+r'\s*=',text) else text+'\n'+key+' = '+str(value)+'\n'
        path.write_bytes(text.encode('cp1252'))
        if specification and 3 in specification['models']:
            q['original_model3_oxygen_composition']=[]
            for crop in inputs.glob('*.crp'):
                old=crop.read_bytes();after=assignment(old.decode('cp1252'),'SWOXYGEN',1).encode('cp1252');crop.write_bytes(after)
                q['original_model3_oxygen_composition'].append(dict(file=crop.name,before_sha256=SHA(old),after_sha256=SHA(after),explicit_assignment=dict(SWOXYGEN=1),original_source_rule='Original oxygenstress.f90 refuses model3 with oxygen2; original supported oxygen1 is selected explicitly, as in retained analytical model3 fixtures.'))
        q['explicit_physical_configuration_edits']=dict(assignments=edits,original_swp_sha256=SHA(before),current_swp_sha256=SHA(path.read_bytes()),all_other_files_original_bytes=True,physical_parameters_or_numerical_limits_edited=False)
        project=m.e.load(inputs,original_output=True);item=selected(project);assert item
        q['actual_selection']=item;q['input_inventory']=m.e.inventory(inputs);save()
        build=Path(q['build_root']);command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
        started=time.perf_counter()
        with (a.output/'build.stdout').open('xb') as out,(a.output/'build.stderr').open('xb') as err:
            run=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=240)
        q['build']=dict(command=command,returncode=run.returncode,seconds=time.perf_counter()-started);save();run.check_returncode()
        meta,_=m.validate_bundle(build,a.reference_work,project);q['actual_BUILD_sha256']=SHA((build/'BUILD.json').read_bytes())
        cuts={2,4,7,8} if a.days==8 else {2,4,7,9,30,34,35}
        q['trajectory'],data=m.trajectory(build,a.reference_work,project,a.output/'trajectory',a.days,cuts,240);save()
        q['original_convergence']=require_convergence(a.output);save()
        q['native_samples']=[]
        for day in sorted(cuts):
            with zipfile.ZipFile(a.output/'trajectory'/f'accepted-column-1-day-{day}.zip') as z:
                raw=z.read('macro.bin');validate_candidate(raw,project)
                q['native_samples'].append(dict(day=day,bytes=len(raw),sha256=SHA(raw),actual_parent_magic=raw[:8].decode(),extension_tag='S5IHX001'))
        q['cold']=[]
        for lo,hi in ([(2,4),(7,8)] if a.days==8 else [(2,4),(7,9),(30,34)]):
            q['cold'].append(own(build,a.reference_work,project,a.output/'trajectory',data,lo,hi,a.output/('own-'+str(lo))));save()
        from cde_clock_controls import transactions
        q['external_transactions']=transactions(build,a.reference_work,project,a.output/'trajectory',a.output/'transactions')
        assert all(v is True for v in q['external_transactions'].values())
        assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()==head
        q['status']='ACTUAL_IMPLICIT_ANALYTICAL_STATE_PHYSICAL_NATIVE_COLD_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_ACTUAL_IMPLICIT_HYDRAULIC_STATE_FEEDBACK_NOT_ADMITTED',error=repr(error));raise
    finally:save()
    print(q['status'],a.case,a.optimization,flush=True)


if __name__=='__main__':main()
