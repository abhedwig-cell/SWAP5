"""Explicit actual fixed irrigation age, composed with literal accepted owners."""
from pathlib import Path
import hashlib
import importlib.util
import re
import original_output_hysteresis as output
import age_fixed_irrigation as young

ROOT=output.ROOT
PATCH=ROOT/'reference/swap-4.3.1/patches/NOMACRO-AGE-IRRIGATION-SOURCE-01/source.py'
DOMAIN='age_irrigation_source_domain'
MAGICS={b'S5AGE002':b'S5AI0002',b'S5AGE003':b'S5AI0003',b'S5AGE004':b'S5AI0004',b'S5AGE005':b'S5AI0005',b'S5IOA001':b'S5AIO001',b'S5IHA001':b'S5AIH001'}
LAYOUTS={code:index for code,index in zip(MAGICS,range(2,8))}


def enabled(project):return getattr(project,'age_irrigation_source',False)


def selection(project):
    if not enabled(project):return None
    if project.macro or not project.age or project.solute or not project.input_directory:raise ValueError('Fixed age source requires an experimental no-macro age project')
    if project.time_step_policy!='original-adaptive-day-seed-v1':raise ValueError('Fixed age source requires the original adaptive-day-seed policy')
    from experimental_project import inspect
    s=inspect(project.input_directory)['selectors']
    for key,value in dict(SWMACRO=0,SWSOLU=2,SWIRFIX=1,SWSNOW=0,SWFROST=0,SWBR=0,SWDRA=1,SWMETDETAIL=0,SWSOPHY=0).items():
        if s[key]!=value:raise ValueError('Fixed age source currently excludes '+key)
    return dict(policy='original-fixed-current-irrigation-age-days-v1',irrigation_types=[0,1],units='days',source='actual current original CIRR',native_static_parameters_preserved=True,subsurface=False)


def base_magic(project):
    if output.selection(project) is not None:return output.magic(project)
    if output.ordinary.selection(project) is not None:return output.ordinary.magic(project)
    import age_output_schedule as schedule
    for owner in (output.clock,schedule,output.regular):
        if owner.selection(project) is not None:return owner.MAGIC
    from conserved_original_age import MAGIC
    return MAGIC


def magic(project):
    selection(project)
    return MAGICS[base_magic(project)]


def metadata(project):
    selected=selection(project)
    if selected is None:return None
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(**selected,native_codec=magic(project).decode(),base_native_codec=base_magic(project).decode(),
                source_sha256=sha(Path(__file__)),domain_source_sha256=sha(Path(__file__).with_name(DOMAIN+'.f90')),
                correction_sha256=sha(PATCH),original_event_carry='complete original irrigation owner',
                physical_age_providers_changed=False,age_tolerance='8192*epsilon*max(1,actual_age_inventory,actual_age_fluxes)')


def output_metadata(project):
    result=output.metadata(project)
    if not enabled(project) or result is None:return result
    return dict(result,native_codec=magic(project).decode(),irrigation_source=metadata(project))


def age_identity(original,project):
    result=output.age_identity(original,project)
    if not enabled(project):return result
    result=dict(result,native_codec=magic(project).decode(),irrigation_source=metadata(project))
    if project.original_output:result['original_output']=output_metadata(project)
    return result


def fixed_metadata(project):
    if enabled(project):return metadata(project)
    return young.metadata() if young.enabled(project) else None


def render_irrigation(source):
    anchor='      subroutine read_irrigation_fixed()'
    read="         if (swsolu > 0) call rdfdor ('irconc',0.d0,1000.d0,irconc,mairg,ifnd)"
    if source.count(anchor)!=1 or source.count(read)!=1:raise ValueError('Changed original fixed age reader')
    source=source.replace(anchor,anchor+'\n         use hybrid_age_irrigation_source_domain,only:hybrid_age_irrigation_source_assert,hybrid_age_irrigation_source_register',1)
    return source.replace(read,read+"""
         if(swsolu/=2)error stop 'Foreign original fixed irrigation age kind'
         if(any(irtype(1:ifnd)==2))error stop 'Fixed current-age source supports sprinkler and surface irrigation only'
         do i=1,ifnd
            call hybrid_age_irrigation_source_assert(irconc(i))
         end do
         call hybrid_age_irrigation_source_register(ifnd)""",1)


def render_context(source):
    first=source.index('   subroutine hybrid_irrigation_checkpoint(');last=source.index('   end subroutine',first)+len('   end subroutine');before,body,after=source[:first],source[first:last],source[last:]
    anchor='      integer::ios'
    if body.count(anchor)!=1:raise ValueError('Changed actual private irrigation native declaration')
    body=body.replace(anchor,anchor+',source_entries,first_pending,last_pending',1)
    anchor='      use plant_interface,only:fl_cropemergence'
    if body.count(anchor)!=1:raise ValueError('Changed actual private irrigation native imports')
    body=body.replace(anchor,'      use hybrid_age_irrigation_source_domain,only:hybrid_age_irrigation_source_count,hybrid_age_irrigation_source_assert\n      use variables,only:t1900\n'+anchor,1)
    anchor='         hybrid_irrigation_pending=.true.'
    if body.count(anchor)!=1:raise ValueError('Changed actual private irrigation pending boundary')
    check="""         source_entries=hybrid_age_irrigation_source_count()
         if(source_entries<1.or.source_entries>size(irdate))error stop 'Foreign fixed age source shape'
         if(any(hybrid_irrigation_snapshot%irdate(1:source_entries)/=irdate(1:source_entries)).or. &
            any(hybrid_irrigation_snapshot%irtype(1:source_entries)/=irtype(1:source_entries)).or. &
            any(hybrid_irrigation_snapshot%irdepth(1:source_entries)/=irdepth(1:source_entries)).or. &
            any(hybrid_irrigation_snapshot%irrate(1:source_entries)/=irrate(1:source_entries)).or. &
            any(hybrid_irrigation_snapshot%irconc(1:source_entries)/=irconc(1:source_entries))) &
            error stop 'Foreign fixed age source native input table'
         first_pending=1+count(irdate(1:source_entries)<t1900-1d-3)
         last_pending=1+count(irdate(1:source_entries)<=t1900+1d-3)
         if(hybrid_irrigation_snapshot%nirri<first_pending.or.hybrid_irrigation_snapshot%nirri>last_pending) &
            error stop 'Foreign fixed age source native event cursor'
         call hybrid_age_irrigation_source_assert(hybrid_irrigation_snapshot%cirr)
         if(hybrid_irrigation_snapshot%cirr/=0d0)then
            if(hybrid_irrigation_snapshot%nirri<2)error stop 'Foreign fixed age source native current age'
            if(hybrid_irrigation_snapshot%cirr/=irconc(hybrid_irrigation_snapshot%nirri-1)) &
               error stop 'Foreign fixed age source native current age'
         end if
"""
    return before+body.replace(anchor,check+anchor,1)+after


def render_macro(source,project):
    first=source.index('    subroutine hybrid_macro_checkpoint(');last=source.index('    end subroutine hybrid_macro_checkpoint',first)+len('    end subroutine hybrid_macro_checkpoint');before,body,after=source[:first],source[first:last],source[last:]
    old=base_magic(project).decode();codes=re.findall(r"'(S5[A-Z0-9]{6})'",body)
    if codes!=[old,old]:raise ValueError('Changed native age source preimage')
    body=body.replace("'"+old+"'","'"+magic(project).decode()+"'")
    imports=re.findall(r'(?m)^      use MOD_grid, only: numnod(?:,dz)?$',body)
    if len(imports)!=1:raise ValueError('Changed actual native hydraulic import')
    anchor=imports[0]
    body=body.replace(anchor,anchor+'\n      use hybrid_age_irrigation_source_domain,only:hybrid_age_irrigation_source_checkpoint',1)
    layout=LAYOUTS[base_magic(project)];anchor='        read(unit,iostat=ios) trailing'
    if body.count(anchor)!=1:raise ValueError('Changed native age source trailing boundary')
    body=body.replace(anchor,f'        call hybrid_age_irrigation_source_checkpoint(unit,.true.,{layout})\n'+anchor,1)
    anchor='      end if\n      close(unit)'
    if body.count(anchor)!=1:raise ValueError('Changed native age source write boundary')
    body=body.replace(anchor,f'        call hybrid_age_irrigation_source_checkpoint(unit,.false.,{layout})\n'+anchor,1)
    return before+body+after


def apply_build(output_path,project,patched):
    if selection(project) is None:return patched
    spec=importlib.util.spec_from_file_location('fixed_current_age_source',PATCH);patch=importlib.util.module_from_spec(spec);spec.loader.exec_module(patch)
    path=output_path/'solute.f90';source=patch.adapter(path.read_bytes()).decode('cp1252');anchor='submodule (MOD_Solute) MOD_calc_AgeTracer'
    if source.count(anchor)!=1:raise ValueError('Changed actual original age submodule')
    path.write_text(source.replace(anchor,anchor+'\n      use hybrid_age_irrigation_source_domain,only:hybrid_age_irrigation_source_assert',1),encoding='cp1252')
    path=output_path/'macropore.f90';path.write_text(render_macro(path.read_text(encoding='cp1252'),project),encoding='cp1252')
    path=output_path/'irrigation.f90';path.write_text(render_context(path.read_text(encoding='cp1252')),encoding='cp1252')
    (output_path/(DOMAIN+'.f90')).write_bytes(Path(__file__).with_name(DOMAIN+'.f90').read_bytes())
    return [DOMAIN,*patched]
