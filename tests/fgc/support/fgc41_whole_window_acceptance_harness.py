from __future__ import annotations
from dataclasses import dataclass
from enum import IntEnum
from typing import Any, Protocol

class AcceptanceStatus(IntEnum):
    OK=0; INVALID_REQUEST=1; SWAP_PREFLIGHT_FAILED=2; MODFLOW_PREFLIGHT_FAILED=3
    LEDGER_PREFLIGHT_FAILED=4; LINEAGE_MISMATCH=5; MODFLOW_PUBLICATION_FAILED=6
    SWAP_PUBLICATION_FAILED=7; LEDGER_PUBLICATION_FAILED=8

@dataclass(frozen=True)
class WindowIdentity:
    coupling_id:int; candidate_revision:int; t0:float; t1:float
    def valid(self)->bool:
        return self.coupling_id>0 and self.candidate_revision>=0 and self.t1>self.t0

@dataclass
class AcceptanceResult:
    status:AcceptanceStatus=AcceptanceStatus.INVALID_REQUEST
    published:bool=False; request_smaller_window:bool=False; failure_stage:str="request"

class SwapPublicationParticipant(Protocol):
    def preflight(self,candidate:Any,identity:WindowIdentity)->bool: ...
    def publish(self,candidate:Any,identity:WindowIdentity)->bool: ...
    def discard(self,candidate:Any)->None: ...

class ModflowTimestepParticipant(Protocol):
    def preflight_finalize_time_step(self,identity:WindowIdentity)->bool: ...
    def finalize_time_step(self,identity:WindowIdentity)->bool: ...
    def invalidate_for_retry(self)->None: ...

class LedgerPublicationParticipant(Protocol):
    def preflight(self,identity:WindowIdentity)->bool: ...
    def commit_prepared(self,identity:WindowIdentity)->bool: ...
    def abort_prepared(self)->None: ...

def accept_whole_window(candidate:Any, identity:WindowIdentity, swap:SwapPublicationParticipant,
                        modflow:ModflowTimestepParticipant, ledger:LedgerPublicationParticipant)->AcceptanceResult:
    r=AcceptanceResult()
    if candidate is None or not identity.valid(): return r
    if not swap.preflight(candidate,identity):
        _abort(candidate,swap,modflow,ledger); return _fail(r,AcceptanceStatus.SWAP_PREFLIGHT_FAILED,"swap-preflight",True)
    if not modflow.preflight_finalize_time_step(identity):
        _abort(candidate,swap,modflow,ledger); return _fail(r,AcceptanceStatus.MODFLOW_PREFLIGHT_FAILED,"modflow-preflight",True)
    if not ledger.preflight(identity):
        _abort(candidate,swap,modflow,ledger); return _fail(r,AcceptanceStatus.LEDGER_PREFLIGHT_FAILED,"ledger-preflight",True)
    # Publication point. No ordinary scientific/validation decision is permitted below this line.
    if not modflow.finalize_time_step(identity):
        return _fail(r,AcceptanceStatus.MODFLOW_PUBLICATION_FAILED,"modflow-publication",False)
    if not swap.publish(candidate,identity):
        return _fail(r,AcceptanceStatus.SWAP_PUBLICATION_FAILED,"swap-publication",False)
    if not ledger.commit_prepared(identity):
        return _fail(r,AcceptanceStatus.LEDGER_PUBLICATION_FAILED,"ledger-publication",False)
    r.status=AcceptanceStatus.OK; r.published=True; r.failure_stage="none"; return r

def _abort(candidate,swap,modflow,ledger):
    swap.discard(candidate); ledger.abort_prepared(); modflow.invalidate_for_retry()

def _fail(r,status,stage,retry):
    r.status=status; r.failure_stage=stage; r.request_smaller_window=retry; return r
