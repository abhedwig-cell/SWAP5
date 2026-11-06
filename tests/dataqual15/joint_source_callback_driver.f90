! Interface/lifetime control only; the physical composition uses real native drainage.
program joint_source_callback_driver
 use iso_fortran_env,only:real64
 use mod_b110_source_sink_provider
 implicit none
 type(b110_source_sink_provider_t)::provider
 real(real64),target::drainage(1,4)=.25d0,irrigation(4)=.1d0,root(4)=0d0
 real(real64)::head(4)=[-1d0,2d0,-3d0,4d0],theta(4)=.3d0,source(4),sink(4)
 character(32)::argument
 logical::refuse
 call get_command_argument(1,argument);refuse=trim(argument)=='refuse'
 call bind_b110_source_sink_provider(provider,drainage,irrigation,root)
 call provider%evaluate(head,theta,source,sink)
 if(any(source/=.1d0).or.any(sink/=.25d0))error stop 'incumbent fixed source changed'
 provider%current_drainage=>candidate_rate
 call provider%evaluate(head,theta,source,sink)
 if(any(source/=.1d0).or.any(sink/=[1d0,0d0,3d0,0d0]))error stop 'callback candidate not consumed'
 if(any(drainage/=.25d0))error stop 'candidate rate mutated bound worker drainage'
 call bind_b110_source_sink_provider(provider,drainage,irrigation,root)
 if(associated(provider%current_drainage))error stop 'callback escaped bind lifetime'
 call provider%evaluate(head,theta,source,sink)
 if(any(sink/=.25d0))error stop 'next binding retained candidate source'
 print '(a)','SCOPED_SOURCE_CALLBACK_AND_UNMUTATED_BINDING_PASS'
contains
 subroutine candidate_rate(h,water,q,ok)
  real(real64),intent(in)::h(:),water(:)
  real(real64),intent(out)::q(:,:)
  logical,intent(out)::ok
  q(1,:)=max(0d0,-h);ok=.not.refuse.and.size(water)==size(h)
 end subroutine
end program
