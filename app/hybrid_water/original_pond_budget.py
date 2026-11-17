"""Shared renderer for the already admitted original linear pond correction."""


def render(source):
    edits=(
        ("      if (dabs(runots) < 1.0d-6) then",
         "      if (dabs(runots) < 1.0d-6 .and. .not.(swdra/=2 .and. rsro>=1d-3 .and. &\n"
         "          dabs(rsroexp-1d0)<1d-6)) then"),
        ("else if (dabs(runots) >= 1.0d-6 .AND. swdra /= 2 .AND. dabs(rsroexp-1.0d0) < 1.0d-6) then",
         "else if (swdra /= 2 .AND. rsro>=1d-3 .AND. dabs(rsroexp-1.0d0) < 1.0d-6) then"))
    for old,new in edits:
        if source.count(old)!=1:raise ValueError('Changed original linear pond conservation anchor')
        source=source.replace(old,new,1)
    return source
