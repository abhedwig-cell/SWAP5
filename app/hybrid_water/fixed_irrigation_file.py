"""Explicit compatibility for the complete original external irrigation reader."""
POLICY='original-external-fixed-irrigation-v1'


def enabled(project):
    if not project.input_directory or project.macro:return False
    from experimental_project import inspect
    selected=inspect(project.input_directory)['selectors']
    return selected['SWIRFIX']==1 and selected.get('SWIRGFIL')==1


def render_irrigation(source):
    anchor="         if (swsolu > 0) call rdfdor ('irconc',0.d0,1000.d0,irconc,mairg,ifnd)"
    if source.count(anchor)!=1:raise ValueError('Changed original irrigation solute input anchor')
    return source.replace(anchor,anchor+"\n"
        "         if(swirgfil==1.and.swsolu>0.and.any(irtype(1:ifnd)==2)) &\n"
        "            error stop 'Unsupported fixed subsurface solute irrigation'")
