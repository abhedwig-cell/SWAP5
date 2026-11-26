"""Keep original pending pre-start dates on bounded implicit/analytical water."""
ANCHOR="if(ioutdatint/=1+count(outdatint>0d0.and.outdatint<t1900-1d-8))error stop 'Inconsistent original interval date pointer'"
GUARD="""! Original TimeControl initializes ioutdatint=1 and advances it only
! when its actual selected date equals the completed day. An initial date
! before the immutable TSTART therefore remains pending; never advance it.
if(outdatint(1)>0d0.and.outdatint(1)<original_output_start_clock-1d-8)then
 if(ioutdatint/=1)error stop 'Inconsistent original pending initial interval date pointer'
else
 """+ANCHOR+"\nend if"


def selected(project):
    from frost_boundary_state_calendar import selection
    item=selection(project.input_directory,project.original_output)
    return bool(item and item['kind']=='water'
                and ((item['implicit']==1 and item['bottom'] in (5,8)) or item.get('analytical_frost_models')))


def source(text):
    if text.count(ANCHOR)!=1:raise ValueError('Foreign implicit plate original interval date guard')
    return text.replace(ANCHOR,GUARD,1)


def original_source(text):
    if text.count(GUARD)!=1:raise ValueError('Foreign implicit plate pending initial date guard')
    original=text.replace(GUARD,ANCHOR,1)
    if source(original)!=text:raise ValueError('Foreign implicit plate complete interval guard inverse')
    return original


def render_integral(text,project):
    return source(text) if selected(project) else text


def validate(bundle,project,reference):
    if not selected(project):return
    from pathlib import Path
    from frost_calendar_output import selection
    from original_output_thermal import render_integral as parent
    original=(Path(reference)/'build/swap-selected/integral.f90').read_text(encoding='cp1252')
    expected=source(parent(original,None,selection(project)))
    actual=(Path(bundle)/'integral.f90').read_text(encoding='cp1252')
    if actual!=expected:raise ValueError('Foreign complete implicit water plate interval source')
    original_source(actual)
