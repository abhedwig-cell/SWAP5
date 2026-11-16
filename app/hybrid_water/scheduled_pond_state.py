"""Format identity for complete original top context with scheduled pond carry."""
POLICY = 'original-top-scheduled-pond-context-v1'
MAGICS = {
    (False, False): ('S5WPL036', 'S5WPS037', 'S5WPM038'),
    (True, False): ('S5CPL039', 'S5CPS040', 'S5CPM041'),
    (False, True): ('S5WEL042', 'S5WES043', 'S5WEM044'),
    (True, True): ('S5CEL045', 'S5CES046', 'S5CEM047'),
}
ALL_MAGICS = {name.encode() for values in MAGICS.values() for name in values}


def enabled(project):
    if not project.input_directory or project.macro:
        return False
    from experimental_project import inspect
    s = inspect(project.input_directory)['selectors']
    return bool(s['SWPONDMX'] == 1 and (s['SWHYST'] or s['SWSNOW']))
