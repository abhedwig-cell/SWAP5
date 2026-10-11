program test_ppa_micro04_horizon_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_root_micro_matric_flux_table, only: micro_matric_flux_table_t, evaluate_micro_matric_flux_table, MICRO_TABLE_OK
  use mod_fmr_micro_mvg_table_binding, only: fmr_build_micro_mvg_tables, fmr_micro_horizon_map_valid
  implicit none
  type(b110_default_mvg_parameters_t) :: hydraulics
  type(micro_matric_flux_table_t), allocatable :: per_node(:), mapped(:), rejected(:)
  real(real64) :: cofgen(24,4), m0, k0, m1, k1
  integer :: node, status
  logical :: ok

  cofgen=0.0_real64
  do node=1,4
    cofgen(1,node)=0.032_real64
    cofgen(2,node)=0.423_real64
    cofgen(3,node)=4.75_real64+0.5_real64*real(node-1,real64)
    cofgen(4,node)=0.0135_real64
    cofgen(5,node)=0.365_real64
    cofgen(6,node)=1.455_real64
    cofgen(7,node)=1.0_real64-1.0_real64/cofgen(6,node)
    cofgen(8,node)=cofgen(4,node)
    cofgen(10,node)=cofgen(3,node)
    cofgen(11,node)=0.999_real64
    cofgen(12,node)=0.99_real64*cofgen(3,node)
    cofgen(22,node)=-1.0e6_real64
    cofgen(23,node)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hydraulics,cofgen)
  call fmr_build_micro_mvg_tables(hydraulics,per_node,ok)
  if(.not.ok.or..not.allocated(per_node)) error stop 1
  if(.not.fmr_micro_horizon_map_valid([1,1,3,3],4)) error stop 2
  call fmr_build_micro_mvg_tables(hydraulics,mapped,ok,[1,1,3,3])
  if(.not.ok.or..not.allocated(mapped)) error stop 3
  call compare(1,1)
  call compare(2,1)
  call compare(3,3)
  call compare(4,3)
  call evaluate_micro_matric_flux_table(per_node(2),-100.0_real64,m0,k0,status)
  if(status/=MICRO_TABLE_OK) error stop 4
  call evaluate_micro_matric_flux_table(mapped(2),-100.0_real64,m1,k1,status)
  if(status/=MICRO_TABLE_OK.or.k0==k1.or.m0==m1) error stop 5
  call fmr_build_micro_mvg_tables(hydraulics,rejected,ok,[1,1,2,3])
  if(ok.or.allocated(rejected)) error stop 6
  call fmr_build_micro_mvg_tables(hydraulics,rejected,ok,[1,1,3])
  if(ok.or.allocated(rejected)) error stop 7
  print '(a,2es24.16)', 'MICRO04_MAPPED_NODE2_M_K=',m1,k1
  print '(a)', 'MICRO04_HORIZON_FIRST_NODE_SELECTION=PASS'
contains
  subroutine compare(mapped_node,source_node)
    integer,intent(in)::mapped_node,source_node
    real(real64)::matric_a,conductivity_a,matric_b,conductivity_b
    integer::s
    call evaluate_micro_matric_flux_table(mapped(mapped_node),-100.0_real64,matric_a,conductivity_a,s)
    if(s/=MICRO_TABLE_OK) error stop 8
    call evaluate_micro_matric_flux_table(per_node(source_node),-100.0_real64,matric_b,conductivity_b,s)
    if(s/=MICRO_TABLE_OK) error stop 9
    if(matric_a/=matric_b.or.conductivity_a/=conductivity_b) error stop 10
  end subroutine
end program
