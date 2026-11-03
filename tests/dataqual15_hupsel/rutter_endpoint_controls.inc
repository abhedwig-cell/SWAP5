 subroutine incomplete_endpoint_control(w,b)
  type(kernel_committed_state_t),intent(inout)::w
  real(real64),intent(in)::b
  type(kernel_candidate_state_t)::candidate
  type(kernel_result_t)::event
  type(kernel_diagnostics_t)::diagnostics
  integer(int64)::revision
  if(b>=.002d0)return
  revision=w%current_revision()
  call backend%run_canopy_capacity_event(column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,.005d0,b, &
    cfg%numerical,event,candidate,diagnostics)
  call require(.not.event%completed.and..not.candidate%ready(),'incomplete immutable source window refuses event')
  call require(w%current_revision()==revision,'incomplete source refuses without publication')
 end subroutine

 subroutine endpoint_controls(w,c,b)
  type(kernel_committed_state_t),intent(inout)::w
  type(matrix_solute_state_t),intent(inout)::c
  real(real64),intent(in)::b
  type(kernel_candidate_state_t)::candidate,stale
  type(kernel_result_t)::event
  type(kernel_diagnostics_t)::diagnostics
  type(fmr_logical_column_t)::wrong_column
  class(transaction_state_t),allocatable::raw
  real(real64)::before_canopy,expected,time
  integer(int64)::revision
  logical::ok
  integer::code
  call w%snapshot(raw,ok);call require(ok,'event origin snapshot')
  select type(q=>raw)
  type is(fmr_b110_black_evaporation_state_t)
   before_canopy=q%rutter%canopy_storage()
  class default
   error stop 'wrong event origin type'
  end select
  call require(before_canopy>.005d0,'wet discriminating event fixture')
  expected=before_canopy-.005d0;revision=w%current_revision()
  call write_pond_thermal_restart(trim(endpoint)//'.event-before',column,cfg%tiles(1)%template,670001_int64, &
    cfg%tiles(1)%parameters,w,c,code);call require(code==0,'event origin full typed serialization')
  wrong_column=column;wrong_column%column_id=column%column_id+1
  call backend%run_canopy_capacity_event(wrong_column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,.005d0,b, &
    cfg%numerical,event,candidate,diagnostics)
  call require(.not.event%completed.and..not.candidate%ready(),'event wrong column refuses')
  call backend%run_canopy_capacity_event(column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,.005d0,b-.0001d0, &
    cfg%numerical,event,candidate,diagnostics)
  call require(.not.event%completed.and..not.candidate%ready(),'event wrong endpoint refuses')
  call backend%run_canopy_capacity_event(column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,-1d0,b, &
    cfg%numerical,event,candidate,diagnostics)
  call require(.not.event%completed.and..not.candidate%ready(),'negative event capacity refuses')
  call backend%run_canopy_capacity_event(column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w, &
    ieee_value(0d0,ieee_quiet_nan),b,cfg%numerical,event,candidate,diagnostics)
  call require(.not.event%completed.and..not.candidate%ready(),'NaN event capacity refuses under FPE traps')
  call backend%run_canopy_capacity_event(column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,.005d0,b, &
    cfg%numerical,event,candidate,diagnostics)
  call require(event%completed.and.event%mass%complete.and.candidate%ready(),'actual wet owner event')
  call require(abs(event%mass%total_out-expected)<1d-14.and.abs(event%mass%residual)<1d-10,'actual event stock/export')
  stale=candidate
  call backend%discard_trial_candidate(candidate,diagnostics)
  call write_pond_thermal_restart(trim(endpoint)//'.event-rollback',column,cfg%tiles(1)%template,670001_int64, &
    cfg%tiles(1)%parameters,w,c,code);call require(code==0,'rolled back full owner serialization')
  call backend%run_canopy_capacity_event(column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,.005d0,b, &
    cfg%numerical,event,candidate,diagnostics)
  call require(event%completed,'resample same current event origin')
  call backend%commit_trial_candidate(w,candidate,diagnostics,ok,code)
  call require(ok.and.code==0.and.w%current_revision()==revision+1,'one accepted event revision')
  call w%current_time(time,ok);call require(ok.and.time==b,'event does not advance physical time')
  call backend%commit_trial_candidate(w,stale,diagnostics,ok,code)
  call require(.not.ok.and.code==KERNEL_COMMIT_STATUS_STALE_REVISION,'stale actual owner event refuses')
  call backend%discard_trial_candidate(stale,diagnostics)
  call backend%run_canopy_capacity_event(column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,.005d0,b, &
    cfg%numerical,event,candidate,diagnostics)
  call require(.not.event%completed.and..not.candidate%ready(),'consumed hydraulic origin cannot export twice')
  call write_pond_thermal_restart(trim(endpoint)//'.event-after',column,cfg%tiles(1)%template,670001_int64, &
    cfg%tiles(1)%parameters,w,c,code);call require(code==0,'accepted full owner serialization')
  print '(a)','ACTUAL_RUTTER_ENDPOINT_EXPORT_ROLLBACK_LINEAGE_SOURCE_WINDOW_AND_STALE_CONTROLS_PASS'
 end subroutine
