from support.fgc41_whole_window_acceptance_harness import *

class P:
    def __init__(self,fail=None): self.fail=fail; self.events=[]
    def preflight(self,*a): self.events.append("preflight"); return self.fail!="preflight"
    def publish(self,*a): self.events.append("publish"); return self.fail!="publish"
    def discard(self,*a): self.events.append("discard")
    def preflight_finalize_time_step(self,*a): self.events.append("preflight"); return self.fail!="preflight"
    def finalize_time_step(self,*a): self.events.append("publish"); return self.fail!="publish"
    def invalidate_for_retry(self): self.events.append("invalidate")
    def commit_prepared(self,*a): self.events.append("publish"); return self.fail!="publish"
    def abort_prepared(self): self.events.append("abort")

def ident(): return WindowIdentity(7,3,10.0,11.0)

def test_success_publishes_once_after_all_preflights():
    s,m,l=P(),P(),P(); r=accept_whole_window(object(),ident(),s,m,l)
    assert r.status==AcceptanceStatus.OK and r.published
    assert s.events==["preflight","publish"] and m.events==["preflight","publish"] and l.events==["preflight","publish"]

def test_each_preflight_failure_publishes_nothing_and_requests_fresh_retry():
    for who in range(3):
        ps=[P(),P(),P()]; ps[who].fail="preflight"
        r=accept_whole_window(object(),ident(),ps[0],ps[1],ps[2])
        assert not r.published and r.request_smaller_window
        assert all("publish" not in p.events for p in ps)
        assert "discard" in ps[0].events and "invalidate" in ps[1].events and "abort" in ps[2].events

def test_invalid_identity_never_touches_participants():
    s,m,l=P(),P(),P(); r=accept_whole_window(object(),WindowIdentity(0,3,10,11),s,m,l)
    assert r.status==AcceptanceStatus.INVALID_REQUEST
    assert not s.events and not m.events and not l.events

def test_post_publication_failure_is_not_reported_as_retryable_rollback():
    s,m,l=P(),P("publish"),P(); r=accept_whole_window(object(),ident(),s,m,l)
    assert r.status==AcceptanceStatus.MODFLOW_PUBLICATION_FAILED
    assert not r.request_smaller_window and "discard" not in s.events and "abort" not in l.events
