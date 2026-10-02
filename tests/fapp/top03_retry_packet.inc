 subroutine bounded_retry_packet(origin,interval,imposed_head,output,top_sum,bottom_sum,complete,attempts,rejected,iterations,max_residual)
 type(soil_water_solve_request_t),intent(in)::origin
 real(real64),intent(in)::interval,imposed_head
 type(soil_water_solve_request_t),intent(out)::output
 real(real64),intent(out)::top_sum,bottom_sum,max_residual
 logical,intent(out)::complete
 integer,intent(out)::attempts,rejected,iterations
 type(soil_water_solve_request_t)::current,next_state,saved
 real(real64)::elapsed,duration,transfer,bottom,residual,storage_begin,ledger
 integer::step_iterations
 logical::ok
 saved=origin;current=origin;output=origin
 elapsed=0;duration=interval/2;top_sum=0;bottom_sum=0;attempts=0;rejected=0;iterations=0;max_residual=0;complete=.false.
 storage_begin=sum(origin%base_state%water_content*dz)+origin%base_state%ponding_depth
 do while(elapsed<interval-1e-15_real64)
  duration=min(duration,interval-elapsed)
  if(duration<origin%numerical%min_step_duration.or.attempts>=2000)exit
  attempts=attempts+1
  call retry_step(current,duration,next_state,transfer,bottom,ok,step_iterations,residual,imposed_head)
  iterations=iterations+step_iterations
  if(.not.ok)then
   rejected=rejected+1;duration=duration/2;cycle
  end if
  current=next_state;top_sum=top_sum+transfer;bottom_sum=bottom_sum+bottom
  elapsed=elapsed+duration;duration=min(interval,2*duration);max_residual=max(max_residual,residual)
 end do
 ledger=sum(current%base_state%water_content*dz)+current%base_state%ponding_depth-storage_begin+top_sum-bottom_sum
 if(abs(ledger)>1e-10_real64)error stop 'packet prefix mass'
 complete=elapsed>=interval-1e-15_real64
 if(complete)then
  output%base_state=current%base_state
 else
  top_sum=0;bottom_sum=0;max_residual=0
 end if
 if(any(origin%base_state%pressure_head/=saved%base_state%pressure_head).or. &
    any(origin%base_state%water_content/=saved%base_state%water_content).or. &
    origin%base_state%ponding_depth/=saved%base_state%ponding_depth)error stop 'packet origin changed'
 end subroutine
