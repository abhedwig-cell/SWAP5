"""Bound existing explicit analytical constitutive models to undrained Frost."""
import hashlib,math,re,struct
from pathlib import Path
POLICY='existing-explicit-analytical-frost-undrained-boundary58-state-calendar-v1'
NATIVE='frost_analytical_native'

def model_domain(active,values):
    if values['SWKIMPL']!=0 or values['SWHYST']!=0:return None
    rows=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
    if len(rows)!=1 or re.fullmatch(r'[+-]?[0-9]+(?:[ \t]+[+-]?[0-9]+)*[ \t]*',rows[0]) is None:return None
    models=list(map(int,rows[0].split()))
    if not models or all(x==1 for x in models) or any(x not in (1,3,4,5,6,7,8,9,10,11) for x in models):return None
    tables=list(re.finditer(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[ \t]*\n',active))
    if len(tables)!=1:return None
    layers=[]
    for line in active[tables[0].end():].splitlines():
        if not line.strip():break
        fields=line.split()
        if len(fields)!=4:break
        try:sub,soil,nodes=int(fields[0]),int(fields[1]),int(fields[3]);depth=float(fields[2].replace('D','e').replace('d','e'))
        except ValueError:return None
        if sub!=len(layers)+1 or soil<1 or nodes<1 or not math.isfinite(depth) or depth<=0:return None
        layers.append(soil)
    if not layers or set(layers)!=set(range(1,max(layers)+1)):return None
    count=max(layers)
    if len(models)==1:models=models*count
    if len(models)!=count:return None
    vapor=re.findall(r'(?mi)^[ \t]*SWVAPOR[ \t]*=[ \t]*([^\r\n]*)',active)
    if len(vapor)>1 or not vapor and any(x>=8 for x in models):return None
    if vapor:
        if re.fullmatch(r'[+-]?[0-9]+(?:[ \t]+[+-]?[0-9]+)*[ \t]*',vapor[0]) is None:return None
        flags=list(map(int,vapor[0].split()))
        if any(x!=0 for x in flags) or any(x>=8 for x in models) and len(flags)!=count:return None
    return models

def selected(project):
    from frost_undrained_state import selected as parent
    item=parent(project)
    return item if item and item.get('analytical_frost_models') else None

def codec(item):
    if not item.get('analytical_frost_models') or item['implicit']!=0 or item['hysteresis']!=0:raise ValueError('Foreign original analytical Frost codec domain')
    return b'S5UAC001' if item['kind']=='cde' else b'S5UAW001'

def native_source(item):
    if item['bottom'] not in (5,8) or item['implicit']!=0 or item['hysteresis']!=0:raise ValueError('Foreign analytical Frost native source domain')
    text=Path(__file__).with_name(NATIVE+'.f90').read_text(encoding='cp1252')
    if text.count('swbotb/=5')!=1:raise ValueError('Foreign analytical Frost native boundary anchor')
    return text.replace('swbotb/=5','swbotb/='+str(item['bottom']),1)

def native_domain(raw,item,nodes):
    if raw[:8]!=codec(item):raise ValueError('Foreign analytical Frost native codec')
    models=item['analytical_frost_models'];expected=[2,nodes,len(models),int(item['kind']=='cde'),item['bottom'],*models]
    header=struct.pack('<'+str(len(expected))+'i',*expected)
    if raw.count(header+header)!=1:raise ValueError('Foreign or incomplete original analytical Frost per-layer native model witness')
    return expected

def validate_candidate(raw,project):
    item=selected(project)
    if item is None:raise ValueError('Missing actual analytical Frost candidate domain')
    native_domain(raw,item,project.nodes)

def metadata(item):
    folder=Path(__file__).parent
    return dict(policy=POLICY,models=item['analytical_frost_models'],native_header_version=2,native_header_integers=5+len(item['analytical_frost_models']),original_scalar_model_replication=True,active_vapor=False,new_physical_state=False,physical_equations_changed=False,generated_native_lf_sha256=hashlib.sha256(native_source(item).encode('cp1252')).hexdigest(),providers={n:hashlib.sha256((folder/n).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for n in ['frost_analytical_composition.py',NATIVE+'.f90']})

def render_macro(text,project):
    item=selected(project)
    if item is None:return text
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    if text.count(begin)!=1 or text.count(end)!=1:raise ValueError('Ambiguous actual analytical Frost native owner')
    low=text.index(begin);high=text.index(end,low)+len(end);body=text[low:high]
    anchors=re.findall(r'(?m)^      use MOD_grid, only: numnod(?:,dz)?$',body)
    if len(anchors)!=1:raise ValueError('Foreign original analytical Frost native grid import')
    body=body.replace(anchors[0],anchors[0]+'\n      use hybrid_frost_analytical_native,only:frost_analytical_domain_checkpoint',1)
    for flag in ['.true.','.false.']:
        anchor='        call snow_output_calendar_checkpoint(unit,'+flag+')'
        if body.count(anchor)!=1:raise ValueError('Foreign original analytical Frost Snow native anchor')
        body=body.replace(anchor,'        call frost_analytical_domain_checkpoint(unit,'+flag+')\n'+anchor,1)
    return native_source(item)+'\n'+text[:low]+body+text[high:]

def write_provider(output,project):
    item=selected(project)
    if item is not None:(Path(output)/(NATIVE+'.f90')).write_text(native_source(item),encoding='cp1252')

def validate(bundle,project):
    item=selected(project)
    if item is None:return
    expected=native_source(item);bundle=Path(bundle)
    if (bundle/(NATIVE+'.f90')).read_text(encoding='cp1252')!=expected:raise ValueError('Foreign complete analytical Frost native provider')
    text=(bundle/'macropore.f90').read_text(encoding='cp1252')
    if not text.startswith(expected+'\n') or text.count(expected)!=1:raise ValueError('Foreign compiled analytical Frost native provider')
    for flag in ['.true.','.false.']:
        if text.count('        call frost_analytical_domain_checkpoint(unit,'+flag+')')!=1:raise ValueError('Missing actual analytical Frost native model witness')
