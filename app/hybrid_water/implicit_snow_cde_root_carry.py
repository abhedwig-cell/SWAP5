"""Carry two existing original root diagnostic rates across dormant cold starts.

Original RootExtraction returns before assigning these rates for rd<vsmall or
ptra<nihil; Integral still accumulates them. Preserve their actual values, never
reset or reconstruct them. This changes no physical equation or accepted flux.
"""
import hashlib
from pathlib import Path
import re

STATE='implicit_snow_root_state'
CODECS={'S5CIS001':'S5IRC001','S5CCS001':'S5IRC002','S5ITC001':'S5IRC003'}


def provider_source():
    text=Path(__file__).with_name(STATE+'.f90').read_text(encoding='cp1252')
    if text.count('swsolu/=0')!=1:raise ValueError('Changed original root diagnostic parent domain')
    return text.replace('swsolu/=0','swsolu/=1',1)


def enabled(project):
    if not project.input_directory or not project.original_output or project.macro or not project.solute or project.age:return False
    from frost_boundary_composition import selection as frost_boundary_selection
    if frost_boundary_selection(project.input_directory,project.original_output) is not None:return False
    from experimental_project import inspect
    report=inspect(project.input_directory);s=report['selectors']
    return s['SWKIMPL']==s['SWSNOW']==1 and report['boundary']['SWBOTB'] in (5,8)


def magic(project,parent):
    if not enabled(project):return parent
    name=parent.decode() if isinstance(parent,bytes) else parent
    if name not in CODECS:raise ValueError('Unqualified implicit Snow root parent codec: '+name)
    return CODECS[name].encode()


def metadata(project,parent):
    if not enabled(project):return None
    folder=Path(__file__).parent
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(policy='literal-original-inactive-root-diagnostic-rate-carry-v1',
        source_sha256=sha(Path(__file__)),parent_provider_sha256=sha(folder/(STATE+'.f90')),
        provider_sha256=hashlib.sha256(provider_source().encode('cp1252')).hexdigest(),
        parent_codec=parent,new_codec=magic(project,parent).decode(),
        fields=['alpwetnoddrz','alpdrynodrtz'],bytes=96,new_physical_state=False)


def apply_build(output,project,patched):
    if not enabled(project):return patched
    folder=Path(__file__).parent
    (output/(STATE+'.f90')).write_text(provider_source(),encoding='cp1252')
    path=output/'macropore.f90';text=path.read_text(encoding='cp1252')
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    if text.count(begin)!=1 or text.count(end)!=1:raise ValueError('Changed Snow root native checkpoint owner')
    first=text.index(begin);last=text.index(end,first)+len(end);body=text[first:last]
    codecs=re.findall(r"'(S5[A-Z0-9]{6})'",body)
    if len(codecs)!=2 or len(set(codecs))!=1:raise ValueError('Foreign Snow root parent native codec')
    body=body.replace("'"+codecs[0]+"'","'"+magic(project,codecs[0]).decode()+"'")
    anchor='      use MOD_grid, only: numnod'
    if body.count(anchor)!=1:raise ValueError('Changed Snow root native imports')
    body=body.replace(anchor,'      use hybrid_implicit_snow_root_state,only:implicit_snow_root_checkpoint\n'+anchor,1)
    for restoring in ('.true.','.false.'):
        anchor=('        read(unit,iostat=ios) trailing' if restoring=='.true.' else '      end if\n      close(unit)')
        if body.count(anchor)!=1:raise ValueError('Changed Snow root native EOF owner')
        body=body.replace(anchor,'        call implicit_snow_root_checkpoint(unit,'+restoring+',clock)\n'+anchor,1)
    # Compile the small state module in the existing native owner's unit. Its
    # object is already linked by the unchanged qualified host recipe.
    provider=provider_source()
    path.write_text(provider+'\n'+text[:first]+body+text[last:],encoding='cp1252')
    return patched


def validate_source(bundle,project,output):
    if not enabled(project):return
    root=output.get('implicit_snow_root_carry')
    if not root or root!=metadata(project,root['parent_codec']) or output['native_codec']!=root['new_codec']:
        raise ValueError('Foreign implicit Snow root carry policy')
    folder=Path(__file__).parent;bundle=Path(bundle)
    if (bundle/(STATE+'.f90')).read_text(encoding='cp1252')!=provider_source():
        raise ValueError('Foreign actual implicit Snow root rate provider')
    text=(bundle/'macropore.f90').read_text(encoding='cp1252')
    provider=provider_source()+'\n'
    if not text.startswith(provider) or text.count(provider)!=1:
        raise ValueError('Foreign compiled implicit Snow root rate provider')
    body=text.split('    subroutine hybrid_macro_checkpoint(',1)[1].split('    end subroutine hybrid_macro_checkpoint',1)[0]
    for part in ('use hybrid_implicit_snow_root_state,only:implicit_snow_root_checkpoint',
                 'call implicit_snow_root_checkpoint(unit,.true.,clock)',
                 'call implicit_snow_root_checkpoint(unit,.false.,clock)'):
        if body.count(part)!=1:raise ValueError('Foreign actual implicit Snow root native owner')
    if body.count("'"+root['new_codec']+"'")!=2 or "'"+root['parent_codec']+"'" in body:
        raise ValueError('Foreign actual implicit Snow root native codec')
