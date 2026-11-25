"""Compose the existing two-rate native carry with bounded implicit Frost."""
import hashlib
import math
from pathlib import Path
import re
import struct

STATE = 'implicit_frost_root_state'
PARENT_SHA = '617c85df35a799ad400278d59d51f89941c9d6ef4f57193c7f124c40817ea0e2'
IMPORT = '      use hybrid_implicit_frost_root_state,only:implicit_frost_root_checkpoint\n'
CALLS = tuple('        call implicit_frost_root_checkpoint(unit,'+flag+',clock)\n'
              for flag in ('.true.', '.false.'))


def hysteresis(project):
    from experimental_project import switches
    mode=switches((Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')).get('SWHYST')
    if mode==2:return 2
    from frost_hysteresis_composition import selection
    selected=selection(project.input_directory,project.original_output)
    if selected is None or selected['implicit']!=1:
        raise ValueError('Unqualified implicit Frost hysteresis root domain')
    return selected['hysteresis']


def source(solute,mode=2):
    if type(mode) is not int or mode not in (0,1,2):
        raise ValueError('Invalid implicit Frost hysteresis root mode')
    text = Path(__file__).with_name('implicit_snow_root_state.f90').read_text(encoding='cp1252')
    if hashlib.sha256(text.encode('cp1252')).hexdigest() != PARENT_SHA:
        raise ValueError('Qualified original two-rate native provider changed')
    edits = [('hybrid_implicit_snow_root_state', 'hybrid_implicit_frost_root_state'),
             ('implicit_snow_root_checkpoint', 'implicit_frost_root_checkpoint'),
             ('use MOD_swap_base, only: swsolu,swsnow,swhyst',
              'use MOD_swap_base, only: swsolu,swsnow,swhyst,swfrost,swdra'),
             ('(swbotb/=5.and.swbotb/=8)', '(swbotb/=6.or.swfrost/=1.or.swdra/=1.or.swhyst/='+str(mode)+')'),
             ('expected=[1,numnod', 'expected=[4,numnod'),
             ('HYBRID_SNOW_ROOT_NATIVE', 'HYBRID_FROST_ROOT_NATIVE')]
    if solute: edits.append(('swsolu/=0', 'swsolu/=1'))
    for before, after in edits:
        if before not in text: raise ValueError('Changed qualified root carry anchor')
        text = text.replace(before, after)
    return text


def metadata(project):
    from implicit_frost_composition import enabled
    if not enabled(project): return None
    return dict(policy='literal-original-implicit-frost-root-diagnostic-carry-v1',
        source_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n', b'\n')).hexdigest(),
        parent_provider_sha256=PARENT_SHA,
        provider_sha256=hashlib.sha256(source(project.solute,hysteresis(project)).encode('cp1252')).hexdigest(),
        fields=['alpwetnoddrz', 'alpdrynodrtz'], bytes=96, header_version=4,
        native_revision=2, new_physical_state=False)


def macro(text, project):
    begin='    subroutine hybrid_macro_checkpoint('; end='    end subroutine hybrid_macro_checkpoint'
    if text.count(begin)!=1 or text.count(end)!=1:
        raise ValueError('Changed implicit Frost native checkpoint owner')
    low=text.index(begin); high=text.index(end,low)+len(end); body=text[low:high]
    anchor='      use MOD_grid, only: numnod'
    if body.count(anchor)!=1: raise ValueError('Changed implicit Frost native imports')
    body=body.replace(anchor,IMPORT+anchor,1)
    for anchor, call in zip(('        read(unit,iostat=ios) trailing', '      end if\n      close(unit)'), CALLS):
        if body.count(anchor)!=1: raise ValueError('Changed implicit Frost native EOF owner')
        body=body.replace(anchor,call+anchor,1)
    return source(project.solute,hysteresis(project))+'\n'+text[:low]+body+text[high:]


def apply_build(output, project, patched):
    provider=source(project.solute,hysteresis(project))
    (output/(STATE+'.f90')).write_text(provider,encoding='cp1252')
    path=output/'macropore.f90';path.write_text(macro(path.read_text(encoding='cp1252'),project),encoding='cp1252')
    return patched


def restore_macro(actual, project):
    prefix=source(project.solute,hysteresis(project))+'\n'
    if not actual.startswith(prefix) or actual.count(prefix)!=1:
        raise ValueError('Foreign complete implicit Frost root provider')
    actual=actual[len(prefix):]
    for part in (IMPORT,*CALLS):
        if actual.count(part)!=1: raise ValueError('Foreign implicit Frost root native call')
        actual=actual.replace(part,'',1)
    return actual


def validate_native(raw, project):
    from implicit_frost_composition import codec
    if len(raw)<104 or raw[:8]!=codec(project): raise ValueError('Foreign implicit Frost root native revision')
    header=struct.unpack('<16i',raw[-96:-32]); values=struct.unpack('<4d',raw[-32:])
    expected=[4,project.nodes,int(project.solute),1,hysteresis(project),6,1,0]
    if list(header[:8])!=expected or list(header[8:])!=expected:
        raise ValueError('Foreign implicit Frost root native domain/witness')
    if values[:2]!=values[2:] or not all(map(math.isfinite,values)):
        raise ValueError('Invalid implicit Frost root diagnostic values')
    return values[:2]


def parent_macro(reference, project):
    from experimental_project import inspect
    from snow_undrained_source_guard import checkpoint_parent
    from original_output_thermal import render_macro
    from frost_calendar_state import selection as calendar_selection
    if calendar_selection(project.input_directory,project.original_output) is not None:
        from frost_calendar_output import render_macro
    report=inspect(project.input_directory)
    text=render_macro(checkpoint_parent(reference,{'swhyst':hysteresis(project),'et':report['selectors']['SWETR']},project),project)
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    low=text.index(begin);high=text.index(end,low)+len(end);body=text[low:high]
    anchor='      use MOD_grid, only: numnod'
    if body.count(anchor)!=1:raise ValueError('Changed qualified native parent imports')
    body=body.replace(anchor,'      use hybrid_implicit_pond_event_state,only:assert_no_implicit_pond_event\n'+anchor,1)
    matches=list(re.finditer(r'(?m)^([ \t]*)if \(restoring\) then$',body))
    if len(matches)!=1:raise ValueError('Changed qualified native pending-event owner')
    anchor=matches[0].group()
    body=body.replace(anchor,matches[0][1]+'call assert_no_implicit_pond_event()\n'+anchor,1)
    return text[:low]+body+text[high:]


def validate_source(bundle, project, reference):
    if (bundle/(STATE+'.f90')).read_text(encoding='cp1252')!=source(project.solute,hysteresis(project)):
        raise ValueError('Foreign actual implicit Frost root provider source')
    actual=(bundle/'macropore.f90').read_text(encoding='cp1252')
    if restore_macro(actual,project)!=parent_macro(reference,project):
        raise ValueError('Foreign complete actual implicit Frost native parent')
