! Explicit input-owner fixture only. The entire oxygenstress implementation
! is compiled unchanged from its hash-verified B1.11 source carrier.
module MOD_arrays
  integer,parameter::macp=5,matab=4
end module
module MOD_grid
  integer,parameter::numnod=4
  integer::layer(4)=1
  real(8)::dz(4)=[10.d0,20.d0,30.d0,40.d0],ztopcp(4)=0.d0,zbotcp(4)=0.d0
end module
module parameters
  real(8),parameter::pi=3.1415926535897932384626433832795d0
end module
module doln
  logical::do_ln_trans=.false.
end module
module atmosphere_interface
  real(8)::tav=20.d0
end module
module plant_interface
  real(8)::max_resp_factor=2.d0,q10_root=2.d0,c_mroot=1.d-5,f_senes=1.d0
end module
module MOD_cropdevelopment
  real(8)::q10_microbial=2.d0,specific_resp_humus=1.d-6,rootradius_m=.0002d0,srl=1000.d0
  real(8)::wroot_node_top(4)=[1.d0,.8d0,.6d0,.4d0]
  real(8)::campbell_h100=-100.d0,campbell_h500=-500.d0,gfp_h100=-100.d0
end module
module MOD_texture_orgmat
  real(8)::orgmat(1)=.02d0,psand(1)=.6d0,bdens(1)=1300.d0
end module
module MOD_SoilTemperature
  real(8)::tsoil(4)=[20.d0,18.d0,16.d0,14.d0]
end module
module variables
  real(8)::theta(4)=.3d0,h(4)=-100.d0,dimoca(4)=0.d0
end module
module MOD_MvG
  integer::swsophy=0,iHWCKmodel(1)=1,numtablay(1)=4
  real(8)::cofgen(24,4)=0.d0,sptab(7,4,4)=0.d0
contains
  real(8) function watcon(node,head)
    integer,intent(in)::node
    real(8),intent(in)::head
    ! The fixture supplies a unimodal analytical MvG owner view. No thermal,
    ! waterfilm, MICRO, MACRO, microbial or SOLVE algebra is stubbed.
    watcon=cofgen(1,node)+(cofgen(2,node)-cofgen(1,node))* &
         (1.d0+(cofgen(4,node)*abs(min(0.d0,head)))**cofgen(6,node))**(-cofgen(7,node))
  end function
end module
subroutine swap_error(location,message)
  character(*),intent(in)::location,message
  print *, 'B111_SOURCE_ERROR ',location,message
  error stop 1
end subroutine
