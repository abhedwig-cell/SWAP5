"""Explicit compatibility for the complete original external irrigation reader."""
POLICY='original-external-fixed-irrigation-v1'


def enabled(project):
    if not project.input_directory or project.macro:return False
    from experimental_project import inspect
    selected=inspect(project.input_directory)['selectors']
    return selected['SWIRFIX']==1 and selected.get('SWIRGFIL')==1


def render_irrigation(source, *, allow_chemical_subsurface=False):
    grid='         use MOD_grid,      only: zbotcp'
    zone="               call rdfdor('ir_z',-100.0d0, 0.0d0, ir_z, 2, 2)          ! cm\n            end if"
    if source.count(grid)!=1 or source.count(zone)!=1:raise ValueError('Changed original irrigation depth input anchor')
    source=source.replace(grid,grid+', numnod')
    condition='swirgfil==1.or.swsolu>0' if allow_chemical_subsurface else 'swirgfil==1'
    source=source.replace(zone,zone+"\n"
        f"            if({condition})then\n"
        "               if(numnod<1)error stop 'Invalid fixed subsurface irrigation profile'\n"
        "               if(ir_z(1)<ir_z(2).or.any(ir_z<zbotcp(numnod))) &\n"
        "                  error stop 'Invalid fixed subsurface irrigation depth interval/profile'\n"
        "            end if")
    anchor="         if (swsolu > 0) call rdfdor ('irconc',0.d0,1000.d0,irconc,mairg,ifnd)"
    if source.count(anchor)!=1:raise ValueError('Changed original irrigation solute input anchor')
    if allow_chemical_subsurface:return source
    return source.replace(anchor,anchor+"\n"
        "         if(swirgfil==1.and.swsolu>0.and.any(irtype(1:ifnd)==2)) &\n"
        "            error stop 'Unsupported fixed subsurface solute irrigation'")
