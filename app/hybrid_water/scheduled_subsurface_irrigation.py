"""Bounded original water-only scheduled subsurface irrigation input."""
POLICY = 'original-water-scheduled-subsurface-irrigation-v1'


def enabled(project):
    if not project.input_directory or project.macro:
        return False
    from experimental_project import crop_entries, one, switches
    from pathlib import Path
    directory = Path(project.input_directory)
    text = (directory/'swap.swp').read_text(encoding='cp1252')
    if switches(text).get('SWCROP') != 1:
        return False
    for name, _ in crop_entries(text):
        crop = directory/(name if name.lower().endswith('.crp') else name+'.crp')
        body = crop.read_text(encoding='cp1252')
        if one(body, 'SCHEDULE', r'[+-]?\d+') == '1' and one(body, 'ISUAS', r'[+-]?\d+') == '2':
            return True
    return False


def render_irrigation(source):
    # Both scalar and interval inputs join here, before the original grid walk.
    # Preserve all original allocation/rate equations and complete module state.
    anchor = '               ! determine layer number where SSDI takes place'
    boundary = source.index('      subroutine read_irrigation_fixed()')
    scheduled, fixed = source[:boundary], source[boundary:]
    if scheduled.count(anchor) != 1:
        raise ValueError('Changed original scheduled subsurface depth input anchor')
    return scheduled.replace(anchor,
        "               if(numnod<1)error stop 'Invalid scheduled subsurface irrigation profile'\n"
        "               if(ir_z(1)<ir_z(2).or.any(ir_z<zbotcp(numnod))) &\n"
        "                  error stop 'Invalid scheduled subsurface irrigation depth interval/profile'\n"
        + anchor) + fixed
