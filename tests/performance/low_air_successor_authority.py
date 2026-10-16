"""Exact default-OFF source projection; eligibility never grants admission."""
import hashlib,pathlib,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[2]
BASE='c591205c5e03f1c96c6488eb53c562265f749556'
CONTRACT='src/runtime/mod_canonical_contracts.f90'
RUNTIME='src/runtime/mod_canonical_interval_runtime.f90'
PATHS=(CONTRACT,RUNTIME)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def blob(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
def remove_once(text,block):
 if text.count(block)!=1:raise ValueError('missing or ambiguous exact proposal block')
 return text.replace(block,'')
def project_default_off(path,text):
 if path==CONTRACT:
  return remove_once(text,'    ! Opt-in proposal policy; every incumbent full/half acceptance gate still runs.\n    logical :: retain_accepted_step_proposal = .false.\n')
 if path!=RUNTIME:raise ValueError('unknown projection path')
 text=text.replace('TX_TEMPORAL_MODEL_CERTIFICATE, TX_TEMPORAL_EXTERNAL_FULL_HALF','TX_TEMPORAL_MODEL_CERTIFICATE')
 text=text.replace('transaction_t1, proposed_dt, proposal_factor','transaction_t1')
 text=text.replace('selector_valid, proposal_active','selector_valid')
 text=remove_once(text,'''    if (config%retain_accepted_step_proposal) then
      if (present(target_selector) .or. config%transaction%temporal_mode /= TX_TEMPORAL_EXTERNAL_FULL_HALF) then
        result%status = CANONICAL_STATUS_INVALID_REQUEST
        return
      end if
    end if

''')
 text=remove_once(text,'''    proposal_active = .false.
    proposed_dt = 0.0_real64
''')
 text=remove_once(text,'      if (proposal_active) transaction_t1 = min(interval%t1, cursor + proposed_dt)\n')
 text=remove_once(text,'''      if (config%retain_accepted_step_proposal .and. (proposal_active .or. tx%temporal_rejections > 0)) then
        proposal_factor = 2.0_real64
        ! Clamp before division: finite budget/tiny indicator must not overflow
        ! while calculating a proposal whose bounded factor is already known.
        if (tx%temporal_error > 0.0_real64) then
          if (tx%temporal_error > 0.2025_real64 * transaction_policy%temporal_tolerance) proposal_factor = &
               max(0.5_real64, min(2.0_real64, 0.9_real64 * sqrt(transaction_policy%temporal_tolerance / tx%temporal_error)))
        end if
        proposed_dt = tx%accepted_dt * proposal_factor
        proposal_active = ieee_is_finite(proposed_dt) .and. proposed_dt > 0.0_real64
      end if

''')
 return text

def verify_source():
 if git('diff','--name-only',BASE,'HEAD','--','src').splitlines()!=list(PATHS):raise ValueError('foreign production mutation')
 if git('status','--porcelain','--','src','reference'):raise ValueError('dirty production/reference')
 if git('rev-parse','HEAD:reference')!=git('rev-parse',BASE+':reference'):raise ValueError('reference mutation')
 proof={}
 for path in PATHS:
  old=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT).decode();new=(ROOT/path).read_text()
  if project_default_off(path,new)!=old:raise ValueError('change outside exact disabled proposal '+path)
  if git('rev-parse','HEAD:'+path)!=blob(new.encode()):raise ValueError('postimage drift')
  proof[path]={'preimage':blob(old.encode()),'postimage':blob(new.encode())}
 # No production component may consume the new field outside the verified seam.
 users={str(p.relative_to(ROOT))for p in (ROOT/'src').rglob('*.f90')if 'retain_accepted_step_proposal' in p.read_text().lower()}
 if users!=set(PATHS):raise ValueError('foreign proposal reader')
 return {'baseline':BASE,'changed_paths':list(PATHS),'proof':proof,'source_tree':git('rev-parse','HEAD:src'),'scope':'Exact default-OFF source compatibility only; ON algorithm and affected scientific/admission evidence separately mandatory.','admitted':False}
if __name__=='__main__':
 import json
 print(json.dumps(verify_source(),indent=2))
