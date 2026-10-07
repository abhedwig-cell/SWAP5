module mod_fmr_bartholomeus_contract
  use iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_bartholomeus_activation
  use mod_bartholomeus_parameter_contract
  use mod_root_oxygen_reproduction_response, only: root_oxygen_reproduction_parameters_t
  implicit none
  private
  type, public :: fmr_bartholomeus_parameters_t
    type(fmr_bartholomeus_selection_t) :: selection
    type(BartholomeusImmutableDataset) :: soil
    type(BartholomeusCropParameters) :: crop
    real(real64) :: specific_root_length_m_kg = 0.0_real64
    type(root_oxygen_reproduction_parameters_t), allocatable :: reproduction
  end type
  public :: valid_fmr_bartholomeus_parameters, matches_bartholomeus_hydraulic_owner, &
       matches_reproduction_hydraulic_owner
contains
  logical function matches_bartholomeus_hydraulic_owner(parameters,cofgen,dz_cm) result(ok)
    type(fmr_bartholomeus_parameters_t),intent(in)::parameters
    real(real64),intent(in)::cofgen(:,:),dz_cm(:)
    integer::i,n
    real(real64)::expected(6),actual(6)
    ok=.false.;n=size(dz_cm)
    if(.not.allocated(parameters%soil%soil)) return
    if(size(parameters%soil%soil)/=n .or. size(cofgen,1)<7 .or. size(cofgen,2)/=n) return
    do i=1,n
      expected=[cofgen(2,i),dz_cm(i)*0.01_real64,cofgen(4,i)*0.01_real64, &
           cofgen(6,i)-1.0_real64,cofgen(7,i)+1.0_real64, &
           (cofgen(2,i)-cofgen(1,i))*0.01_real64*cofgen(4,i)*cofgen(6,i)*cofgen(7,i)]
      associate(p=>parameters%soil%soil(i))
        actual=[p%saturated_water_content,p%depth_m,p%waterfilm_alpha_per_pa, &
             p%waterfilm_n_minus_1,p%waterfilm_m_plus_1,p%waterfilm_capac_term]
        if(abs(p%waterfilm_gen_n-cofgen(6,i))>0.0_real64) return
      end associate
      if(any(.not.ieee_is_finite(expected)) .or. any(.not.ieee_is_finite(actual))) return
      if(any(abs(expected-actual)>0.0_real64)) return
    end do
    ok=.true.
  end function
  logical function valid_fmr_bartholomeus_parameters(parameters,active_nodes) result(ok)
    type(fmr_bartholomeus_parameters_t),intent(in)::parameters
    integer,intent(in)::active_nodes
    integer::route,wmode
    call select_fmr_bartholomeus_route(parameters%selection,route,wmode)
    ok=.false.
    if(route==FMR_BARTHOLOMEUS_DISABLED) then
      ok=.not.allocated(parameters%reproduction)
      return
    end if
    if(route==FMR_BARTHOLOMEUS_ACTIVE) then
      if(allocated(parameters%reproduction)) return
      if(.not.ieee_is_finite(parameters%specific_root_length_m_kg)) return
      if(parameters%specific_root_length_m_kg<=0) return
      if(.not.ieee_is_finite(1.0_real64/parameters%specific_root_length_m_kg)) return
      ok=validate_bartholomeus_parameters(parameters%soil,parameters%crop,active_nodes)
      return
    end if
    if(route==FMR_BARTHOLOMEUS_REPRODUCTION) then
      if(.not.allocated(parameters%reproduction)) return
      if(.not.parameters%reproduction%ready()) return
      ok=parameters%reproduction%active_nodes()==active_nodes
    end if
  end function

  logical function matches_reproduction_hydraulic_owner(parameters,cofgen,z_cm,dz_cm) result(ok)
    type(fmr_bartholomeus_parameters_t),intent(in)::parameters
    real(real64),intent(in)::cofgen(:,:),z_cm(:),dz_cm(:)
    integer::i,n
    real(real64)::bottom,tol
    ok=.false.
    if(.not.allocated(parameters%reproduction)) return
    if(.not.parameters%reproduction%ready()) return
    n=size(dz_cm)
    if(parameters%reproduction%active_nodes()/=n) return
    if(size(z_cm)/=n.or.size(cofgen,1)<2.or.size(cofgen,2)/=n) return
    tol=1024.0_real64*epsilon(1.0_real64)
    if(any(abs(parameters%reproduction%saturated_water_content-cofgen(2,:))>tol)) return
    if(any(abs(parameters%reproduction%z_cm-z_cm)>tol*max(1.0_real64,maxval(abs(z_cm))))) return
    if(any(abs(parameters%reproduction%dz_cm-dz_cm)>tol*max(1.0_real64,maxval(dz_cm)))) return
    bottom=0.0_real64
    do i=1,n
      bottom=bottom-dz_cm(i)
      if(abs(parameters%reproduction%zbotcp_cm(i)-bottom)>tol*max(1.0_real64,abs(bottom))) return
    end do
    ok=.true.
  end function
end module
