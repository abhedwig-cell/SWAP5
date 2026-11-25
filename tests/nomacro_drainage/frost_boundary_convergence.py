"""Reject original positive trajectories which continued without convergence."""
import hashlib


def require_convergence(folder):
    files=[];failures=[]
    for path in folder.rglob('*'):
        if path.suffix.lower() not in ('.wrn','.war','.log','.err','.stdout'):continue
        raw=path.read_bytes();files.append(dict(path=str(path),sha256=hashlib.sha256(raw).hexdigest()))
        for line in raw.decode('cp1252',errors='replace').splitlines():
            if 'No convergence was reached' in line:failures.append(dict(path=str(path),line=line))
    assert files,'Missing actual original convergence diagnostics'
    assert not failures,('Original continued without Richards convergence',failures)
    return dict(status='ACTUAL_ORIGINAL_CONVERGENCE_DIAGNOSTICS_NO_FALLBACK',files=files,unconverged_continuations=0)


def historical_clock_source(original):
    """Read-only reconstruction of the superseded 056/0fa scientific artifact."""
    raw=original.replace(b'\r\n',b'\n')
    assert hashlib.sha256(raw).hexdigest()=='14403e7f9b0a9434388b62fb00c4ef672ac004f7d54ab3c8fbbb8fdd5364b472'
    text=raw.decode('cp1252')
    edits=[('      get_dtEvent = min(dtEventEOD, dtEventPrint)',
            '      if(abs(dtEventPrint-dtEventEOD)<=dtCrit)dtEventPrint=dtEventEOD\n'
            '      get_dtEvent = min(dtEventEOD, dtEventPrint)'),
           ('         fldecdt = .FALSE.\n         return',
            '         fldecdt = .FALSE.\n         dtEvent=get_dtevent()\n'
            '         if(dt+dtCrit>dtevent)dt=dtevent\n         return')]
    for before,after in edits:
        assert text.count(before)==1;text=text.replace(before,after,1)
    return text.encode('cp1252')
