! Same-platform bounded disk adapter. Existing FMR/kernel restore owns water.
module mod_age_joint_restart_file
  use iso_fortran_env,only:real64,int64,int32,int8,iostat_end
  use ieee_arithmetic,only:ieee_is_finite
  use mod_transaction_reference,only:transaction_state_t
  use mod_kernel_transactions,only:kernel_committed_state_t
  use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t
  use mod_fmr_serialized_reference_backend,only:fmr_b110_physical_state_t,fmr_b110_temporal_indicator_state_t, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_committed_restart,only:fmr_committed_restart_bundle_t,fmr_export_committed_restart, &
       fmr_restore_committed_restart,FMR_RESTART_OK
  use mod_b111_age_tracer_substep,only:b111_age_tracer_substep_forcing_t
  use mod_fmr_b111_age_route,only:age_state_t,age_parameter_vector, &
       reconstruct_age_trusted,AGE_OK
  use mod_fmr_b111_age_joint_application,only:age_joint_states_match,JOINT_OK,JOINT_INVALID
  use mod_solute_compartment_state,only:solute_compartment_state_t
  use mod_b111_surface_age_owner,only:surface_age_owner_t
  implicit none
  private
  character(8),parameter::MAGIC='S5AJ0001'
  integer,parameter::MAX_BYTES=10485760
  public::write_age_joint_restart_file,read_age_joint_restart_file,crc32
contains
  subroutine write_age_joint_restart_file(path,column,template,water_parameter_id,water,chemical,status,surface_owner)
    character(*),intent(in)::path
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    integer(int64),intent(in)::water_parameter_id
    type(kernel_committed_state_t),intent(in)::water
    type(age_state_t),intent(in)::chemical
    integer,intent(out)::status
    type(surface_age_owner_t),intent(in),optional::surface_owner
    type(fmr_committed_restart_bundle_t)::b
    type(b111_age_tracer_substep_forcing_t)::p
    type(solute_compartment_state_t)::s
    real(real64),allocatable::theta(:),v(:),derivative(:)
    real(real64)::time
    integer(int64)::id,revision
    integer::u,io,mode,n
    logical::ok,has_history
    status=JOINT_INVALID
    if(column%state_handle/=1)return
    if(.not.age_joint_states_match(water,chemical,surface_owner))return
    call fmr_export_committed_restart([column],[template],[water],water_parameter_id,b,ok,io)
    if(.not.ok.or.io/=FMR_RESTART_OK)return
    call chemical%configuration(p,id);v=age_parameter_vector(p)
    if(.not.allocated(v))return
    call chemical%snapshot(time,theta,s,revision)
    n=size(theta);mode=-1;has_history=.false.
    select type(q=>b%records(1)%physical_state)
    type is(fmr_b110_physical_state_t)
      mode=0;allocate(derivative(0))
    type is(fmr_b110_temporal_indicator_state_t)
      mode=1;call q%temporal_history_snapshot(derivative,has_history)
      if(.not.has_history)then
        if(allocated(derivative))deallocate(derivative)
        allocate(derivative(0))
      end if
    end select
    if(mode<0)return
    open(newunit=u,file=path,access='stream',form='unformatted',status='replace',iostat=io)
    if(io/=0)return
    writing: block
      associate(r=>b%records(1))
        write(u,iostat=io)MAGIC,b%schema_version,b%parameter_set_identity, &
             r%schema_version,r%kernel_schema_version,r%column_id,r%parameter_ref,r%forcing_handle, &
             r%template_identity,r%lineage_id,r%revision,r%committed_time,r%time_bound, &
             mode,n,has_history
        if(io/=0)exit writing
        select type(q=>r%physical_state)
        class is(fmr_b110_physical_state_t)
          write(u,iostat=io)q%pressure_head,q%water_content,q%ponding_depth,q%groundwater_level
        end select
        if(io/=0)exit writing
        if(has_history)write(u,iostat=io)derivative
        if(io/=0)exit writing
        write(u,iostat=io)id,revision,time,size(v),v,theta,s%age_amount
      end associate
    end block writing
    close(u)
    if(io/=0)return
    call append_crc(path,io)
    if(io==0)status=JOINT_OK
  end subroutine

  subroutine read_age_joint_restart_file(path,column,template,water_parameter_id,chemical_parameter_id,p, &
       water,chemical,status,surface_owner)
    character(*),intent(in)::path
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    integer(int64),intent(in)::water_parameter_id,chemical_parameter_id
    type(b111_age_tracer_substep_forcing_t),intent(in)::p
    type(kernel_committed_state_t),intent(inout)::water
    type(age_state_t),intent(inout)::chemical
    integer,intent(out)::status
    type(surface_age_owner_t),intent(in),optional::surface_owner
    type(fmr_committed_restart_bundle_t)::b
    type(kernel_committed_state_t)::temporary,water_trial(1)
    type(fmr_b110_physical_state_t)::physical
    type(age_state_t)::chemical_trial
    real(real64),allocatable::theta(:),amount(:),derivative(:),v(:),expected(:)
    real(real64)::time
    integer(int64)::id,revision
    integer(int32)::checksum
    integer::u,io,mode,n,count
    integer(int8)::extra
    character(8)::tag
    logical::ok,has_history
    status=JOINT_INVALID
    if(column%state_handle/=1)return
    if(water%ready())return
    if(chemical%ready())return
    if(.not.allocated(p%dz_cm))return
    expected=age_parameter_vector(p)
    if(.not.allocated(expected))return
    if(.not.all(ieee_is_finite(expected)))return
    call check_crc(path,io)
    if(io/=0)return
    open(newunit=u,file=path,access='stream',form='unformatted',status='old',iostat=io)
    if(io/=0)return
    allocate(b%records(1))
    ! All decoding remains tentative. Every exit reaches the common close.
    decoding: block
      associate(r=>b%records(1))
        read(u,iostat=io)tag,b%schema_version,b%parameter_set_identity, &
             r%schema_version,r%kernel_schema_version,r%column_id,r%parameter_ref,r%forcing_handle, &
             r%template_identity,r%lineage_id,r%revision,r%committed_time,r%time_bound, &
             mode,n,has_history
        if(io/=0)exit decoding
        io=1
        if(tag/=MAGIC.or.n/=size(p%dz_cm).or.n<1.or.n>4096.or.(mode/=0.and.mode/=1))exit decoding
        if(mode==0.and.has_history)exit decoding
        physical%active_nodes=n
        allocate(physical%pressure_head(n),physical%water_content(n),theta(n),amount(n))
        read(u,iostat=io)physical%pressure_head,physical%water_content,physical%ponding_depth,physical%groundwater_level
        if(io/=0)exit decoding
        if(has_history)then
          allocate(derivative(n));read(u,iostat=io)derivative
          if(io/=0)exit decoding
          io=1
          if(.not.all(ieee_is_finite(derivative)))exit decoding
        end if
        if(mode==1)then
          if(has_history)then
            call fmr_new_b110_temporal_indicator_committed_state(temporary,1_int64,physical,0.0_real64,ok,derivative)
          else
            call fmr_new_b110_temporal_indicator_committed_state(temporary,1_int64,physical,0.0_real64,ok)
          end if
          io=1
          if(.not.ok)exit decoding
          call temporary%snapshot(r%physical_state,ok)
          if(.not.ok)exit decoding
        else
          allocate(r%physical_state,source=physical)
        end if
        read(u,iostat=io)id,revision,time,count
        if(io/=0)exit decoding
        io=1
        if(id/=chemical_parameter_id.or.count/=size(expected))exit decoding
        allocate(v(count));read(u,iostat=io)v,theta,amount,checksum
        if(io/=0)exit decoding
        io=1
        if(.not.all(ieee_is_finite(v)))exit decoding
        if(any(abs(v-expected)>0.0_real64))exit decoding
        read(u,iostat=io)extra
        if(io/=iostat_end)then
          io=1;exit decoding
        end if
        call fmr_restore_committed_restart(b,water_parameter_id,[column],[template],water_trial,ok,io)
        if(.not.ok.or.io/=FMR_RESTART_OK)then
          io=1;exit decoding
        end if
        call reconstruct_age_trusted(p,id,revision,time,theta,amount,chemical_trial,io)
        if(io/=AGE_OK)exit decoding
        io=1
        if(.not.age_joint_states_match(water_trial(1),chemical_trial,surface_owner))exit decoding
        io=0
      end associate
    end block decoding
    close(u)
    if(io/=0)return
    water=water_trial(1);chemical=chemical_trial;status=JOINT_OK
  end subroutine

  function crc32(bytes) result(crc)
    integer(int8),intent(in)::bytes(:)
    integer(int32)::crc
    integer::i,j
    crc=not(0_int32)
    do i=1,size(bytes)
      crc=ieor(crc,iand(int(bytes(i),int32),int(z'FF',int32)))
      do j=1,8
        if(btest(crc,0))then
          crc=ieor(shiftr(crc,1),int(z'EDB88320',int32))
        else
          crc=shiftr(crc,1)
        end if
      end do
    end do
    crc=not(crc)
  end function

  subroutine append_crc(path,status)
    character(*),intent(in)::path
    integer,intent(out)::status
    integer(int8),allocatable::bytes(:)
    integer::u,n,io
    integer(int32)::crc
    status=1
    inquire(file=path,size=n,iostat=io)
    if(io/=0.or.n<1.or.n>MAX_BYTES-4)return
    allocate(bytes(n))
    open(newunit=u,file=path,access='stream',form='unformatted',status='old',action='readwrite',iostat=io)
    if(io/=0)return
    read(u,iostat=io)bytes
    if(io==0)then
      crc=crc32(bytes);write(u,pos=n+1,iostat=io)crc
    end if
    close(u)
    if(io==0)status=0
  end subroutine

  subroutine check_crc(path,status)
    character(*),intent(in)::path
    integer,intent(out)::status
    integer(int8),allocatable::bytes(:)
    integer::u,n,io
    integer(int32)::actual,expected
    status=1
    inquire(file=path,size=n,iostat=io)
    if(io/=0.or.n<12.or.n>MAX_BYTES)return
    allocate(bytes(n-4))
    open(newunit=u,file=path,access='stream',form='unformatted',status='old',action='read',iostat=io)
    if(io/=0)return
    read(u,iostat=io)bytes,expected
    close(u)
    if(io/=0)return
    actual=crc32(bytes)
    if(actual==expected)status=0
  end subroutine
end module
