! Same-platform bounded disk adapter. Existing FMR/kernel restore owns water.
module mod_matrix_joint_restart_file
  use iso_fortran_env,only:real64,int64,int32,int8,iostat_end
  use ieee_arithmetic,only:ieee_is_finite
  use mod_transaction_reference,only:transaction_state_t
  use mod_kernel_transactions,only:kernel_committed_state_t
  use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t
  use mod_fmr_serialized_reference_backend,only:fmr_b110_physical_state_t,fmr_b110_temporal_indicator_state_t, &
       fmr_new_b110_temporal_indicator_committed_state,fmr_b110_boesten_evaporation_state_t, &
       fmr_new_b110_boesten_evaporation_committed_state
  use mod_restricted_surface_evaporation,only:boesten_evaporation_state_t
  use mod_fmr_committed_restart,only:fmr_committed_restart_bundle_t,fmr_export_committed_restart, &
       fmr_restore_committed_restart,FMR_RESTART_OK
  use mod_b111_reactive_solute_substep,only:b111_reactive_solute_substep_forcing_t
  use mod_fmr_b111_matrix_solute_route,only:matrix_solute_state_t,matrix_parameter_vector, &
       reconstruct_matrix_solute_trusted,MATRIX_OK
  use mod_fmr_b111_matrix_joint_application,only:matrix_joint_states_match,JOINT_OK,JOINT_INVALID
  use mod_solute_mobile_salt_state,only:mobile_salt_state_t
  use mod_solute_compartment_state,only:solute_compartment_state_t
  implicit none
  private
  character(8),parameter::MAGIC='S5MJ0001'
  character(8),parameter::SURFACE_MAGIC='S5MJ0002'
  character(8),parameter::BOESTEN_MAGIC='S5MJ0003'
  integer,parameter::MAX_BYTES=10485760
  public::write_matrix_joint_restart_file,read_matrix_joint_restart_file
contains
  subroutine write_matrix_joint_restart_file(path,column,template,water_parameter_id,water,chemical,status,allow_surface_mass)
    character(*),intent(in)::path
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    integer(int64),intent(in)::water_parameter_id
    type(kernel_committed_state_t),intent(in)::water
    type(matrix_solute_state_t),intent(in)::chemical
    integer,intent(out)::status
    logical,intent(in),optional::allow_surface_mass
    type(fmr_committed_restart_bundle_t)::b
    type(b111_reactive_solute_substep_forcing_t)::p
    type(mobile_salt_state_t)::m
    type(solute_compartment_state_t)::s
    type(boesten_evaporation_state_t)::pair
    real(real64),allocatable::theta(:),v(:),derivative(:)
    real(real64)::time
    integer(int64)::id,revision
    integer::u,io,mode,n
    logical::ok,has_history
    logical::surface_enabled
    character(8)::tag
    status=JOINT_INVALID
    if(column%state_handle/=1)return
    if(.not.matrix_joint_states_match(water,chemical))return
    call fmr_export_committed_restart([column],[template],[water],water_parameter_id,b,ok,io)
    if(.not.ok.or.io/=FMR_RESTART_OK)return
    call chemical%configuration(p,id);v=matrix_parameter_vector(p)
    if(.not.allocated(v))return
    call chemical%snapshot(time,theta,m,s,revision)
    surface_enabled=.false.
    if(present(allow_surface_mass))surface_enabled=allow_surface_mass
    ! V1 must never silently drop an unsupported physical store. Check before
    ! opening/replacing the caller's file. Surface V2 is an explicit contract.
    if(s%aquifer_mass/=0.0_real64.or.any(s%age_amount/=0.0_real64))return
    if(.not.ieee_is_finite(s%pond_mass))return
    if(s%pond_mass<0.0_real64.or.s%pond_mass>1.0e12_real64)return
    if(.not.surface_enabled.and.s%pond_mass/=0.0_real64)return
    tag=MAGIC
    if(surface_enabled)tag=SURFACE_MAGIC
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
    type is(fmr_b110_boesten_evaporation_state_t)
      if(.not.surface_enabled)return
      mode=2;tag=BOESTEN_MAGIC;pair=q%boesten_evaporation;allocate(derivative(0))
    end select
    if(mode<0)return
    open(newunit=u,file=path,access='stream',form='unformatted',status='replace',iostat=io)
    if(io/=0)return
    writing: block
      associate(r=>b%records(1))
        write(u,iostat=io)tag,b%schema_version,b%parameter_set_identity, &
             r%schema_version,r%kernel_schema_version,r%column_id,r%parameter_ref,r%forcing_handle, &
             r%template_identity,r%lineage_id,r%revision,r%committed_time,r%time_bound, &
             mode,n,has_history
        if(io/=0)exit writing
        select type(q=>r%physical_state)
        class is(fmr_b110_physical_state_t)
          write(u,iostat=io)q%pressure_head,q%water_content,q%ponding_depth,q%groundwater_level
        end select
        if(io/=0)exit writing
        if(mode==2)write(u,iostat=io)pair%spev,pair%saev
        if(io/=0)exit writing
        if(has_history)write(u,iostat=io)derivative
        if(io/=0)exit writing
        write(u,iostat=io)id,revision,time,size(v),v,theta,m%concentration_mg_cm3,m%mass_mg_cm2,s%sorbed_matrix_mass
        if(io/=0)exit writing
        if(surface_enabled)write(u,iostat=io)s%pond_mass
      end associate
    end block writing
    close(u)
    if(io/=0)return
    call append_crc(path,io)
    if(io==0)status=JOINT_OK
  end subroutine

  subroutine read_matrix_joint_restart_file(path,column,template,water_parameter_id,chemical_parameter_id,p, &
       water,chemical,status,allow_surface_mass)
    character(*),intent(in)::path
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    integer(int64),intent(in)::water_parameter_id,chemical_parameter_id
    type(b111_reactive_solute_substep_forcing_t),intent(in)::p
    type(kernel_committed_state_t),intent(inout)::water
    type(matrix_solute_state_t),intent(inout)::chemical
    integer,intent(out)::status
    logical,intent(in),optional::allow_surface_mass
    type(fmr_committed_restart_bundle_t)::b
    type(kernel_committed_state_t)::temporary,water_trial(1)
    type(fmr_b110_physical_state_t)::physical
    type(boesten_evaporation_state_t)::pair
    type(matrix_solute_state_t)::chemical_trial
    real(real64),allocatable::theta(:),concentration(:),dissolved(:),sorbed(:),derivative(:),v(:),expected(:)
    real(real64)::time,surface_mass
    integer(int64)::id,revision
    integer(int32)::checksum
    integer::u,io,mode,n,count
    integer(int8)::extra
    character(8)::tag
    logical::ok,has_history,surface_enabled
    status=JOINT_INVALID
    if(column%state_handle/=1)return
    if(water%ready())return
    if(chemical%ready())return
    surface_enabled=.false.
    if(present(allow_surface_mass))surface_enabled=allow_surface_mass
    if(.not.allocated(p%dz_cm))return
    expected=matrix_parameter_vector(p)
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
        if(tag/=MAGIC.and.tag/=SURFACE_MAGIC.and.tag/=BOESTEN_MAGIC)exit decoding
        if((tag==SURFACE_MAGIC.or.tag==BOESTEN_MAGIC).and..not.surface_enabled)exit decoding
        if((tag==BOESTEN_MAGIC).neqv.(mode==2))exit decoding
        if(n/=size(p%dz_cm).or.n<1.or.(mode/=0.and.mode/=1.and.mode/=2))exit decoding
        if(mode==0.and.has_history)exit decoding
        if(mode==2.and.has_history)exit decoding
        physical%active_nodes=n
        allocate(physical%pressure_head(n),physical%water_content(n),theta(n),concentration(n),dissolved(n),sorbed(n))
        read(u,iostat=io)physical%pressure_head,physical%water_content,physical%ponding_depth,physical%groundwater_level
        if(io/=0)exit decoding
        if(mode==2)then
          read(u,iostat=io)pair%spev,pair%saev
          if(io/=0)exit decoding
          io=1
          if(.not.all(ieee_is_finite([pair%spev,pair%saev])))exit decoding
          if(min(pair%spev,pair%saev)<0d0)exit decoding
        end if
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
        else if(mode==2)then
          call fmr_new_b110_boesten_evaporation_committed_state(temporary,1_int64,physical,pair,0d0,ok)
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
        allocate(v(count));read(u,iostat=io)v,theta,concentration,dissolved,sorbed
        if(io/=0)exit decoding
        surface_mass=0.0_real64
        if(tag==SURFACE_MAGIC.or.tag==BOESTEN_MAGIC)then
          read(u,iostat=io)surface_mass
          if(io/=0)exit decoding
          io=1
          if(.not.ieee_is_finite(surface_mass))exit decoding
          if(surface_mass<0.0_real64.or.surface_mass>1.0e12_real64)exit decoding
        end if
        read(u,iostat=io)checksum
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
        call reconstruct_matrix_solute_trusted(p,id,revision,time,theta,concentration,dissolved,sorbed,chemical_trial,io, &
          surface_mass=surface_mass)
        if(io/=MATRIX_OK)exit decoding
        io=1
        if(.not.matrix_joint_states_match(water_trial(1),chemical_trial))exit decoding
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
