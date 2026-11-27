"""Bind implicit analytical models to existing thermal and Frost state owners.

The EOF extension witnesses static configuration only. It never assigns physical
selectors, hydraulic parameters or stores during restore. Parent state layouts,
including the conserved CDE prefix, remain literal.
"""
import hashlib
from pathlib import Path
import re
import struct

POLICY='original-implicit-analytical-existing-state-composition-v1'
NATIVE='implicit_hydraulic_state_native'
FROST_NATIVE='implicit_frost_hydraulic_state_native'
TAG=b'S5IHX999'


def input_models(text,selectors,boundary,original_output=None):
    if original_output is False:return None
    fixed=dict(SWMACRO=0,SWKIMPL=1,SWSOPHY=0,SWHYST=0,
               SWHEA=1,SWCALT=2,SWBR=0,SWMETDETAIL=0)
    if any(selectors.get(k)!=v for k,v in fixed.items()):return None
    if (selectors.get('SWSOLU') not in (0,1) or selectors.get('SWSNOW') not in (0,1)
            or selectors.get('SWINCO') not in (1,2) or boundary.get('SWBOTB') not in (5,8)):
        return None
    frost=selectors.get('SWFROST')
    if frost==1:
        if (selectors.get('SWSNOW')!=1 or selectors.get('SWDRA') not in (0,1)
                or selectors.get('SWBBCFILE')!=0 or selectors.get('SWTOPBHEA')!=2):return None
    elif frost!=0 or selectors.get('SWDRA')!=1:return None
    active='\n'.join(line.split('!',1)[0] for line in text.splitlines()
                     if not line.lstrip().startswith('*'))
    # Original scalar replication is validated against the actual grid. Gardner
    # has its own literal derivative in MOD_MvG_functions.dhconduc.
    rows=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
    if len(rows)!=1 or re.fullmatch(r'[+-]?[0-9]+(?:[ \t]+[+-]?[0-9]+)*[ \t]*',rows[0]) is None:return None
    values=list(map(int,rows[0].split()))
    if any(v<1 or v>11 for v in values) or all(v==1 for v in values):return None
    return _models_from_grid(active,values)


def _models_from_grid(active,values):
    import math
    anchors=list(re.finditer(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[ \t]*\n',active))
    if len(anchors)!=1:return None
    layers=[]
    for line in active[anchors[0].end():].splitlines():
        if not line.strip():break
        fields=line.split()
        if len(fields)!=4:break
        try:sub,soil,nodes=int(fields[0]),int(fields[1]),int(fields[3]);depth=float(fields[2].replace('D','e').replace('d','e'))
        except ValueError:return None
        if sub!=len(layers)+1 or soil<1 or nodes<1 or not math.isfinite(depth) or depth<=0:return None
        layers.append(soil)
    if not layers or set(layers)!=set(range(1,max(layers)+1)):return None
    count=max(layers);models=values*count if len(values)==1 else values
    if len(models)!=count:return None
    vapor=re.findall(r'(?mi)^[ \t]*SWVAPOR[ \t]*=[ \t]*([^\r\n]*)',active)
    if any(v>=8 for v in models):
        if len(vapor)!=1:return None
        if re.fullmatch(r'[+-]?[0-9]+(?:[ \t]+[+-]?[0-9]+)*[ \t]*',vapor[0]) is None:return None
        flags=list(map(int,vapor[0].split()))
        if len(flags)!=count or any(v not in (0,1) for v in flags):return None
        if any(flag!=0 for model,flag in zip(models,flags) if model>=8):return None
    return models


def selected(project):
    if not project.input_directory or not project.original_output or project.macro or project.age:return None
    from experimental_project import switches,one
    folder=Path(project.input_directory);text=(folder/'swap.swp').read_text(encoding='cp1252');s=switches(text)
    boundary=s
    if s.get('SWBBCFILE')==1:
        name=one(text,'BBCFIL',r"'[^']+'").strip("'")
        boundary=switches((folder/(name if name.lower().endswith('.bbc') else name+'.bbc')).read_text(encoding='cp1252'))
    models=input_models(text,s,boundary,project.original_output)
    if models is None:return None
    partition=0
    if s['SWDRA']==1:
        name=one(text,'DRFIL',r"'[^']+'").strip("'");prefix=one(text,'PATHDRAIN',r"'[^']*'").strip("'").strip()
        partition=switches((folder/(prefix+name+'.dra')).read_text(encoding='cp1252')).get('SWDIVD')
        if partition not in (0,1) or project.solute and partition==0 or s['SWFROST']==1 and partition!=1:
            raise ValueError('Invalid original implicit drainage partition')
    result=dict(models=models,solute=s['SWSOLU'],snow=s['SWSNOW'],bottom=boundary['SWBOTB'],partition=partition)
    if s['SWFROST']==1:result.update(frost=1,drainage=s['SWDRA'])
    return result


def header(item,nodes):
    return [1,nodes,len(item['models']),item['solute'],1,0,item['snow'],item.get('frost',0),1,2,item.get('drainage',1),item['bottom'],item['partition'],*item['models']]


def native_provider(item):return FROST_NATIVE if item.get('frost') else NATIVE


def native_tag(item):return b'S5IFX001' if item.get('frost') else TAG


def metadata(project):
    item=selected(project)
    if item is None:return None
    folder=Path(__file__).parent;sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(policy=POLICY,**item,native_extension_tag=native_tag(item).decode(),native_extension_version=1,
                native_extension_bytes=8+8*len(header(item,project.nodes)),
                providers={n:sha(folder/n) for n in ['implicit_hydraulic_state.py',native_provider(item)+'.f90']},
                parent_state_layout_preserved=True,physical_equations_changed=False,new_physical_state=False)


def validate_candidate(raw,project):
    item=selected(project)
    if item is None:return
    values=header(item,project.nodes);packed=struct.pack('<'+str(len(values))+'i',*values)
    expected=native_tag(item)+packed+packed
    if not raw.endswith(expected):raise ValueError('Foreign or incomplete implicit hydraulic native extension')


def render_macro(text,item):
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    if text.count(begin)!=1 or text.count(end)!=1:raise ValueError('Ambiguous actual implicit hydraulic native owner')
    low=text.index(begin);high=text.index(end,low)+len(end);body=text[low:high]
    anchors=re.findall(r'(?m)^      use MOD_grid, only: numnod(?:,dz)?$',body)
    if len(anchors)!=1:raise ValueError('Foreign implicit hydraulic grid import')
    body=body.replace(anchors[0],anchors[0]+'\n      use '+native_provider(item)+',only:implicit_hydraulic_checkpoint',1)
    for flag,anchor in [('.true.','        read(unit,iostat=ios) trailing'),('.false.','      end if\n      close(unit)')]:
        if body.count(anchor)!=1:raise ValueError('Foreign implicit hydraulic EOF owner')
        body=body.replace(anchor,'        call implicit_hydraulic_checkpoint(unit,'+flag+')\n'+anchor,1)
    return text[:low]+body+text[high:]


def restore_macro(text,project):
    """Expose the literal parent to its own complete source validator."""
    item=selected(project)
    if item is None:return text
    original=text
    parts=['      use '+native_provider(item)+',only:implicit_hydraulic_checkpoint\n']
    parts+=['        call implicit_hydraulic_checkpoint(unit,'+flag+')\n' for flag in ['.true.','.false.']]
    for part in parts:
        if text.count(part)!=1:raise ValueError('Foreign complete implicit hydraulic native extension source')
        text=text.replace(part,'',1)
    if render_macro(text,item)!=original:raise ValueError('Incomplete implicit hydraulic source inverse')
    return text


def parent_native(raw,project):
    item=selected(project)
    if item is None:return raw
    validate_candidate(raw,project)
    return raw[:-(8+8*len(header(item,project.nodes)))]


def apply_build(output,project,patched):
    item=selected(project)
    if item is None:return patched
    name=native_provider(item)
    if name in patched:raise ValueError('Multiple implicit hydraulic native owners')
    (output/(name+'.f90')).write_bytes(Path(__file__).with_name(name+'.f90').read_bytes())
    macro=output/'macropore.f90';macro.write_text(render_macro(macro.read_text(encoding='cp1252'),item),encoding='cp1252')
    patched.insert(0,name)
    return patched


def validate(bundle,project,identity):
    expected=metadata(project)
    if identity.get('implicit_hydraulic_state')!=expected:raise ValueError('Foreign implicit hydraulic state policy')
    if expected is None:return
    name=native_provider(selected(project));path=Path(bundle)/(name+'.f90')
    if path.read_bytes().replace(b'\r\n',b'\n')!=Path(__file__).with_name(name+'.f90').read_bytes().replace(b'\r\n',b'\n'):
        raise ValueError('Foreign complete implicit hydraulic native provider')
    text=(Path(bundle)/'macropore.f90').read_text(encoding='cp1252')
    if text.count('      use '+name+',only:implicit_hydraulic_checkpoint')!=1:raise ValueError('Missing implicit hydraulic native import')
    for flag in ['.true.','.false.']:
        if text.count('        call implicit_hydraulic_checkpoint(unit,'+flag+')')!=1:raise ValueError('Missing implicit hydraulic native call')
