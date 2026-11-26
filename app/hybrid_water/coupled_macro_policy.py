"""Explicit fresh, unreduced macro policy for the existing private day worker.

The intact original profile remains available. No no-macro dispatch changes.
"""
import copy,json,re,shutil,subprocess
from pathlib import Path
import daily_host as h
import original_macro_policy as original
from donor_sources import replace
from macro_complete_jacobian import render_rate as render_complete_rate,render_head as render_complete_head
from macro_perched_classification import render as render_perched_classification
from macro_contact_history import render_rate as render_contact_rate,render_macro as render_contact_macro
from macro_stock_rank2 import render_rate as render_rank2_rate,render_head as render_rank2_head
from macro_stock_jacobian import render_rate as render_stock_rate,render_head as render_stock_head
from macro_trial_origin import render as render_trial_origin,PHYSICAL_FIELDS
POLICY='fresh-coupled-unreduced-field-coupled-current-geometry-stock-gradient-v9r1'

def render_headcalc(source):
    source=source.replace('\r\n','\n')
    if 'fresh_coupled_candidate_checks' in source:raise ValueError('Already patched coupled worker')
    a=source.index('!     initialize flags',source.index('!     check on convergence'))
    b=source.index('!     implemented to improve iteration performance',a)
    checks=source[a:b]
    source=source[:a]+'      call fresh_coupled_candidate_checks()\n\n'+source[b:]
    needle='      if (dabs(sum1) > CritDevBalTot) flnonconv = .TRUE.'
    source=replace(source,needle,'''      ! Cached convergence is provisional. Same pressure, original K policy,
      ! current exchange and all unchanged criteria must agree before success.
      if (swmacro == 1) then
         if (.not.ieee_is_finite(sum1)) flnonconv=.true.
         if (.not.flnonconv .and. abs(sum1)<=CritDevBalTot) then
            flunsatok(1:3)=.false.
            call vector_F(1, hgrad)
            sump=0.5d0*dot_product(F(1:NN),F(1:NN))
            sum1=sum(F(1:NN))
            Fmax=maxval(abs(F(1:NN)))
            call fresh_coupled_candidate_checks()
            if(any(.not.ieee_is_finite(F(1:NN))))flnonconv=.true.
         end if
      end if

'''+needle)
    m=re.search(r'(?mi)^subroutine headcalc[ \t]*$',source)
    if not m:raise ValueError('Original HeadCalc entry missing')
    source=source[:m.end()]+'''
   use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
   use, intrinsic :: iso_fortran_env, only: error_unit
'''+source[m.end():]
    # A requested legacy exchange scaling is an explicit failure of this new
    # UNREDUCED policy, never a silently different constitutive problem.
    source=re.sub(r'(?m)^   call vector_F\(1, hgrad\)$',
        '''   if(swmacro==1 .and. IDecMpRat/=0)then
      write(error_unit,*)'FRESH_UNREDUCED_SCALE_REQUEST',t1900,dt,IDecMpRat
      error stop 'Fresh unreduced macro policy refuses exchange scaling'
   end if
   call vector_F(1, hgrad)''',source,count=1)
    m=re.search(r'(?mi)^[ \t]*contains[ \t]*$',source)
    if not m:raise ValueError('Original contained solver missing')
    source=source[:m.end()]+'\n\n   subroutine fresh_coupled_candidate_checks()\n'+checks+'   end subroutine fresh_coupled_candidate_checks\n'+source[m.end():]
    source=replace(source,'h(i) = hold(i) - difh(i) * factmax1','h(i) = hold(i) - (difh(i) * factmax1) * factor')
    return source


def render_macrorate(source):
    """CONTRACT06 field route: retain Darcy gradient in already-unsaturated zone."""
    source=source.replace('\r\n','\n')
    old='if (H(ic) < cofgen(9,lay)-1.d-8 .AND. HMp > 1.d-8) then'
    if source.count(old)!=1:raise ValueError('Original Darcy contract anchor differs')
    return source.replace(old,'if (HMp > 1.d-8) then')

def build_bundle(base,reference,target,*,owner_optimization='O2'):
    if owner_optimization not in ('O0','O2'):raise ValueError('Unsupported owner optimization')
    base,reference,target=map(Path,(base,reference,target))
    original.build_bundle(base,reference,target)
    meta=json.loads((target/'BUILD.json').read_text());identity=copy.deepcopy(meta['identity'])
    objects=reference/'build/swap-obj';ttutil=reference/'build/ttutil-obj'
    p=target/'headcalc.f90';rendered=render_complete_head(render_rank2_head(render_stock_head(render_headcalc(p.read_text(encoding='cp1252')))))
    if rendered.count('FRESH_UNREDUCED_SCALE_REQUEST')!=1 or rendered.count('call fresh_coupled_candidate_checks()')!=2:raise ValueError('Incomplete fresh/unreduced worker guard')
    p.write_text(rendered,encoding='cp1252')
    p=target/'macropore.f90';macro=render_trial_origin(p.read_text(encoding='cp1252'),(reference/'build/swap-selected/variables.f90').read_text(encoding='cp1252'))
    macro=replace(macro,'      VlMpDm1Cp= VlMpDmCp(1,1:numnod)','      VlMpDm1Cp(1:numnod)= VlMpDmCp(1,1:numnod)')
    p.write_text(render_contact_macro(macro),encoding='cp1252')
    p=target/'macrorate.f90';p.write_text(render_complete_rate(render_contact_rate(render_rank2_rate(render_stock_rate(render_macrorate((reference/'build/swap-selected/macrorate.f90').read_text(encoding='cp1252')))))),encoding='cp1252')
    identity['donor_generated']['macrorate.f90']=h.sha(p)
    shutil.copyfile(Path(__file__).with_name('macro_stock_rank2.f90'),target/'macro_stock_rank2.f90')
    identity['donor_generated']['macro_stock_rank2.f90']=h.sha(target/'macro_stock_rank2.f90')
    shutil.copyfile(Path(__file__).with_name('macro_stock_complete.f90'),target/'macro_stock_complete.f90')
    identity['donor_generated']['macro_stock_complete.f90']=h.sha(target/'macro_stock_complete.f90')
    p=target/'calcgwl.f90';p.write_text(render_perched_classification((reference/'build/swap-selected/calcgwl.f90').read_text(encoding='cp1252')),encoding='cp1252')
    identity['donor_generated']['calcgwl.f90']=h.sha(p)
    flags=[('-'+owner_optimization if f in ('-O0','-O2') else f) for f in identity['donor_flags']]
    if owner_optimization=='O0':flags=flags+['-fcheck=all','-fbacktrace']
    commands=[['gfortran',*flags,'-I',str(objects),'-I',str(ttutil),'-c',n] for n in ['calcgwl.f90','macropore.f90','macrorate.f90','macro_stock_rank2.f90','macro_stock_complete.f90','headcalc.f90','swap_main.f90']]
    replacements={Path(n).with_suffix('.o').name:target/Path(n).with_suffix('.o').name for n in identity['donor_generated']}
    commands.append(['gfortran','-o',str(h.executable(target,'day_donor')),*(str(replacements.get(p.name,p)) for p in sorted(objects.glob('*.o'))),str(target/'macro_stock_rank2.o'),str(target/'macro_stock_complete.o'),str(target/'hybrid_step_budget.o'),str(ttutil/'libttutil.a')])
    logs=[]
    for command in commands:
        p=subprocess.run(command,cwd=target,capture_output=True,text=True,timeout=90)
        logs.append(dict(command=command,returncode=p.returncode,stdout=p.stdout,stderr=p.stderr))
        (target/'COUPLED_MACRO_BUILD.json').write_text(json.dumps(logs,indent=2)+'\n')
        if p.returncode:raise ValueError(p.stderr)
    for n in ['calcgwl.f90','headcalc.f90','macropore.f90','macrorate.f90','macro_stock_rank2.f90','macro_stock_complete.f90','swap_main.f90']:identity['donor_generated'][n]=h.sha(target/n)
    identity['original_macro_policy_parent']=identity.pop('macro_policy')
    identity['coupled_macro']={'policy':POLICY,'generator_sha256':h.sha(Path(__file__)),'trial_origin_generator_sha256':h.sha(Path(__file__).with_name('macro_trial_origin.py')),'stock_gradient_generator_sha256':h.sha(Path(__file__).with_name('macro_stock_jacobian.py')),'rank2_generator_sha256':h.sha(Path(__file__).with_name('macro_stock_rank2.py')),'rank2_source_sha256':h.sha(Path(__file__).with_name('macro_stock_rank2.f90')),'contact_generator_sha256':h.sha(Path(__file__).with_name('macro_contact_history.py')),'perched_generator_sha256':h.sha(Path(__file__).with_name('macro_perched_classification.py')),'complete_generator_sha256':h.sha(Path(__file__).with_name('macro_complete_jacobian.py')),'complete_source_sha256':h.sha(Path(__file__).with_name('macro_stock_complete.f90')),'field_contract':'CONTRACT06: remove redundant air-entry exclusion only; original Andelst scope','physical_origin_fields':list(PHYSICAL_FIELDS),'owner_flags':flags,'unmodified_original_pool_flags':identity['donor_flags'],'owner_objects_sha256':{n:h.sha(target/n) for n in ['calcgwl.o','headcalc.o','macropore.o','macrorate.o','macro_stock_rank2.o','macro_stock_complete.o','swap_main.o']},'native_codec':'UNCHANGED_S5MAC006; new policy/build receipt refuses foreign origins'}
    identity['macro_policy']={'name':POLICY,'generator_sha256':h.sha(Path(__file__)),'native_macro_format':'S5MAC006-complete-physical-trial-origin','objects_sha256':identity['coupled_macro']['owner_objects_sha256']}
    meta['identity']=identity;meta['binding']={**meta['binding'],'build':identity,'macro_policy':POLICY}
    meta['executable_sha256']['donor']=h.sha(h.executable(target,'day_donor'))
    (target/'BUILD.json').write_text(json.dumps(meta,indent=2)+'\n');return target

def validate_bundle(bundle,reference):
    from daily_coupling import validate_bundle as validate_base
    bundle,reference=map(Path,(bundle,reference));meta,case=validate_base(bundle,reference,h.ANDELST)
    policy=meta['identity'].get('coupled_macro',{})
    if meta['binding'].get('macro_policy')!=POLICY or policy.get('policy')!=POLICY:raise ValueError('Foreign coupled worker policy')
    if policy['generator_sha256']!=h.sha(Path(__file__)) or policy['trial_origin_generator_sha256']!=h.sha(Path(__file__).with_name('macro_trial_origin.py')):raise ValueError('Coupled generator differs')
    if policy['stock_gradient_generator_sha256']!=h.sha(Path(__file__).with_name('macro_stock_jacobian.py')):raise ValueError('Stock gradient generator differs')
    if policy['rank2_generator_sha256']!=h.sha(Path(__file__).with_name('macro_stock_rank2.py')) or policy['rank2_source_sha256']!=h.sha(Path(__file__).with_name('macro_stock_rank2.f90')):raise ValueError('Rank2 source differs')
    if policy['contact_generator_sha256']!=h.sha(Path(__file__).with_name('macro_contact_history.py')):raise ValueError('Contact source differs')
    if policy['perched_generator_sha256']!=h.sha(Path(__file__).with_name('macro_perched_classification.py')):raise ValueError('Perched classification source differs')
    if policy['complete_generator_sha256']!=h.sha(Path(__file__).with_name('macro_complete_jacobian.py')) or policy['complete_source_sha256']!=h.sha(Path(__file__).with_name('macro_stock_complete.f90')):raise ValueError('Complete D3 source differs')
    if policy['physical_origin_fields']!=list(PHYSICAL_FIELDS):raise ValueError('Coupled physical origin differs')
    for name,digest in policy['owner_objects_sha256'].items():
        if h.sha(bundle/name)!=digest:raise ValueError('Coupled owner object differs: '+name)
    for name,digest in meta['identity']['donor_objects'].items():
        if h.sha(reference/'build/swap-obj'/name)!=digest:raise ValueError('Original physical provider differs: '+name)
    if h.sha(reference/'build/ttutil-obj/libttutil.a')!=meta['identity']['ttutil_library']:raise ValueError('Original TTUTIL differs')
    return meta,case
