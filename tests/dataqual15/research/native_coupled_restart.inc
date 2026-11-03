! New same-platform research schema; original S5WM0001 is never reinterpreted.
subroutine write_native_coupled_restart(path,binding,state,status)
 character(*),intent(in)::path,binding
 type(native_coupled_state_t),intent(in)::state
 integer,intent(out)::status
 integer::u,io,bytes_count
 integer(int8),allocatable::bytes(:)
 integer(c_int32_t)::crc
 status=1
 if(len_trim(binding)/=64.or..not.valid_native_snapshot(state))return
 open(newunit=u,file=path//'.pending',status='replace',access='stream',form='unformatted',action='readwrite',iostat=io)
 if(io/=0)return
 write(u,iostat=io)'S5NC0001',binding(1:64),state%model_id,int(size(state%head),int32), &
  int(state%macro%num_domains,int32),state%revision,state%time
 if(io==0)write(u,iostat=io)state%head,state%theta,state%area_dz,state%matrix_temperature,state%macro_temperature, &
  state%macro%icp_bottom_domain,state%macro%sorptivity,state%macro%theta_sorption_ref,state%macro%absorption_time, &
  state%macro%volume_domain_cp,state%macro%water_domain_cp,state%macro%dynamic_volume_cp
 if(io==0)then
  inquire(unit=u,size=bytes_count);allocate(bytes(bytes_count));read(u,pos=1,iostat=io)bytes
  if(io==0)then
   crc=native_crc(bytes,int(bytes_count,c_size_t));write(u,pos=bytes_count+1,iostat=io)crc
  end if
 end if
 close(u)
 if(io/=0)return
 status=int(native_publish(path//'.pending'//c_null_char,path//c_null_char))
end subroutine
subroutine read_native_coupled_restart(path,binding,state,status)
 character(*),intent(in)::path,binding
 type(native_coupled_state_t),intent(inout)::state
 integer,intent(out)::status
 type(native_coupled_state_t)::candidate
 integer::u,io,bytes_count
 integer(int32)::n,nd
 integer(int8),allocatable::bytes(:)
 integer(c_int32_t)::crc
 character(8)::magic
 character(64)::stored_binding
 logical::ok
 status=1
 if(len_trim(binding)/=64)return
 open(newunit=u,file=path,status='old',access='stream',form='unformatted',action='read',iostat=io)
 if(io/=0)return
 inquire(unit=u,size=bytes_count)
 if(bytes_count<164.or.bytes_count>10485760)then;close(u);return;end if
 allocate(bytes(bytes_count-4));read(u,iostat=io)bytes
 if(io==0)read(u,iostat=io)crc
 if(io/=0)then;close(u);return;end if
 if(native_crc(bytes,int(size(bytes),c_size_t))/=crc)then;close(u);return;end if
 read(u,pos=1,iostat=io)magic,stored_binding,candidate%model_id,n,nd,candidate%revision,candidate%time
 if(io/=0)then;close(u);return;end if
 if(magic/='S5NC0001'.or.stored_binding/=binding.or.candidate%model_id/=NATIVE_COUPLED_MODEL_ID.or. &
  n<1.or.n>10000.or.nd<1.or.nd>64)then;close(u);return;end if
 ! Fixed header160 + payload(5*n + 6*nd*n) real64 + nd int32 + CRC4.
 if(int(bytes_count,int64)/=164_int64+8_int64*(5_int64*n+6_int64*nd*n)+4_int64*nd)then;close(u);return;end if
 allocate(candidate%head(n),candidate%theta(n),candidate%area_dz(n),candidate%matrix_temperature(n),candidate%macro_temperature(nd,n))
 call candidate%macro%initialize(int(nd),int(n),ok)
 if(.not.ok)then;close(u);return;end if
 read(u,iostat=io)candidate%head,candidate%theta,candidate%area_dz,candidate%matrix_temperature,candidate%macro_temperature, &
  candidate%macro%icp_bottom_domain,candidate%macro%sorptivity,candidate%macro%theta_sorption_ref,candidate%macro%absorption_time, &
  candidate%macro%volume_domain_cp,candidate%macro%water_domain_cp,candidate%macro%dynamic_volume_cp
 close(u)
 if(io/=0)return
 if(.not.valid_native_snapshot(candidate))return
 state=candidate;status=0
end subroutine
logical function valid_native_snapshot(state)result(ok)
 type(native_coupled_state_t),intent(in)::state
 integer::n,nd
 ok=.false.
 if(state%model_id/=NATIVE_COUPLED_MODEL_ID.or.state%revision<0)return
 if(.not.ieee_is_finite(state%time).or..not.state%macro%ready())return
 if(.not.allocated(state%head).or..not.allocated(state%theta).or..not.allocated(state%area_dz).or. &
  .not.allocated(state%matrix_temperature).or..not.allocated(state%macro_temperature))return
 n=state%macro%num_nodes;nd=state%macro%num_domains
 if(size(state%head)/=n.or.size(state%theta)/=n.or.size(state%area_dz)/=n.or.size(state%matrix_temperature)/=n)return
 if(any(shape(state%macro_temperature)/=[nd,n]))return
 if(any(.not.ieee_is_finite(state%head)).or.any(.not.ieee_is_finite(state%theta)).or. &
  any(.not.ieee_is_finite(state%area_dz)).or.any(.not.ieee_is_finite(state%matrix_temperature)).or. &
  any(.not.ieee_is_finite(state%macro_temperature)))return
 if(any(.not.ieee_is_finite(state%macro%sorptivity)).or.any(.not.ieee_is_finite(state%macro%theta_sorption_ref)).or. &
  any(.not.ieee_is_finite(state%macro%absorption_time)).or.any(.not.ieee_is_finite(state%macro%volume_domain_cp)).or. &
  any(.not.ieee_is_finite(state%macro%water_domain_cp)).or.any(.not.ieee_is_finite(state%macro%dynamic_volume_cp)))return
 if(any(state%theta<0d0).or.any(state%area_dz<=0d0).or.any(state%macro%absorption_time<0d0).or. &
  any(state%macro%water_domain_cp<0d0).or.any(state%macro%volume_domain_cp<0d0))return
 if(any(state%macro%water_domain_cp>state%macro%volume_domain_cp+1d-10))return
 ok=.true.
end function
