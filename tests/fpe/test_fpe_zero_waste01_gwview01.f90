program test_fpe_zero_waste01_gwview01
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none

  type :: gwview_binding_t
    integer(int64) :: groundwater_cell_id = 0_int64
    integer :: package_slot = 0
    integer :: modflow_node_id = 0
  end type gwview_binding_t

  type :: gwview_term_t
    integer :: status = 0
    logical :: valid = .false.
    integer(int64) :: groundwater_cell_id = 0_int64
    integer(int64) :: coupling_id = 0_int64
    integer(int64) :: groundwater_service_id = 0_int64
    integer(int64) :: groundwater_lineage_id = 0_int64
    integer(int64) :: groundwater_origin_revision = -1_int64
    real(real64) :: cell_area_m2 = 0.0_real64
    real(real64) :: reference_head_m = 0.0_real64
    real(real64) :: q_u_at_reference_m_per_s = 0.0_real64
    real(real64) :: dq_u_dh_per_s = 0.0_real64
    real(real64) :: reference_volume_flux_m3_per_day = 0.0_real64
    real(real64) :: hcof_m2_per_day = 0.0_real64
    real(real64) :: rhs_m3_per_day = 0.0_real64
  end type gwview_term_t

  integer :: n, reps, rep, i
  integer(int64) :: c0, c1, rate
  character(len=32) :: arg
  type(gwview_binding_t), allocatable :: bindings(:), tmp_bindings(:)
  type(gwview_term_t), allocatable :: terms(:), tmp_terms(:)
  integer(int64), allocatable :: cell_ids(:), tmp_ids(:)
  integer(int64), allocatable :: out_cell_ids(:), out_binding_ids(:), out_term_ids(:)
  integer, allocatable :: out_slots(:), out_nodes(:)
  real(real64), allocatable :: out_hcof(:), out_rhs(:)
  real(real64) :: old_s, direct_s, checksum

  call get_command_argument(1,arg); read(arg,*) n
  if(n<=0) error stop 'GWVIEW01 invalid n'
  reps=max(1,100000/max(1,n))

  allocate(bindings(n),terms(n),cell_ids(n))
  allocate(out_cell_ids(n),out_binding_ids(n),out_term_ids(n),out_slots(n),out_nodes(n),out_hcof(n),out_rhs(n))
  do i=1,n
    cell_ids(i)=100000_int64+int(i,int64)
    bindings(i)%groundwater_cell_id=cell_ids(i)
    bindings(i)%package_slot=i
    bindings(i)%modflow_node_id=i
    terms(i)%groundwater_cell_id=cell_ids(i)
    terms(i)%hcof_m2_per_day=real(i,real64)*1.0e-6_real64
    terms(i)%rhs_m3_per_day=-real(i,real64)*2.0e-6_real64
  end do

  call system_clock(c0,rate)
  do rep=1,reps
    if(allocated(tmp_bindings)) deallocate(tmp_bindings)
    if(allocated(tmp_terms)) deallocate(tmp_terms)
    if(allocated(tmp_ids)) deallocate(tmp_ids)
    allocate(tmp_bindings(n),tmp_terms(n),tmp_ids(n))
    tmp_bindings=bindings
    tmp_terms=terms
    tmp_ids=cell_ids
    do i=1,n
      out_cell_ids(i)=tmp_ids(i)
      out_binding_ids(i)=tmp_bindings(i)%groundwater_cell_id
      out_slots(i)=tmp_bindings(i)%package_slot
      out_nodes(i)=tmp_bindings(i)%modflow_node_id
      out_term_ids(i)=tmp_terms(i)%groundwater_cell_id
      out_hcof(i)=tmp_terms(i)%hcof_m2_per_day
      out_rhs(i)=tmp_terms(i)%rhs_m3_per_day
    end do
  end do
  call system_clock(c1)
  old_s=real(c1-c0,real64)/real(rate,real64)

  call system_clock(c0)
  do rep=1,reps
    do i=1,n
      out_cell_ids(i)=cell_ids(i)
      out_binding_ids(i)=bindings(i)%groundwater_cell_id
      out_slots(i)=bindings(i)%package_slot
      out_nodes(i)=bindings(i)%modflow_node_id
      out_term_ids(i)=terms(i)%groundwater_cell_id
      out_hcof(i)=terms(i)%hcof_m2_per_day
      out_rhs(i)=terms(i)%rhs_m3_per_day
    end do
  end do
  call system_clock(c1)
  direct_s=real(c1-c0,real64)/real(rate,real64)

  checksum=real(out_cell_ids(n)+out_binding_ids(n)+out_term_ids(n),real64)+out_hcof(n)+out_rhs(n)
  write(*,'(A,I0,A,I0,A,ES16.8,A,ES16.8,A,F12.6,A,ES16.8)') &
       'GWVIEW01,n=',n,',reps=',reps,',current_seconds=',old_s,',direct_seconds=',direct_s, &
       ',ratio=',direct_s/old_s,',checksum=',checksum
end program
