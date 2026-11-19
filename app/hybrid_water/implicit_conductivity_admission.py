"""Public admission boundary for the qualified implicit transport composition."""

AGE_REFUSAL='Implicit AGE is not qualified: retained surface age has no owner after complete pond evaporation; use the separately qualified SWKIMPL0 AGE route'


def require_transport(project):
    if not project.input_directory or not project.age or project.macro:return
    from experimental_project import inspect
    if inspect(project.input_directory)['selectors']['SWKIMPL']==1:
        raise ValueError(AGE_REFUSAL)
