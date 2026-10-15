program test_surface_process
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_b111_surface_supply
 use mod_b111_pond_solute_exchange,only:b111_pond_solute_result_t
 use historical_surface_oracle
 implicit none
 type(surface_supply_t)::s,bad,saved
 type(b111_pond_solute_result_t)::r
 real(real64)::dt,c,transfer,remaining
 integer::i,status
 do i=1,150
  dt=real(i,real64)/256d0
  s=surface_supply_t(1_int64,0_int64,0d0,dt,0.25d0,0.25d0,0.125d0,0.375d0)
  if(mod(i,3)==1)then
   s%rain_rate=0.5d0;s%irrigation_rate=0d0;s%rain_c=0.25d0
  else if(mod(i,3)==2)then
   s%rain_rate=0d0;s%irrigation_rate=0.5d0;s%irrigation_c=0.25d0
  end if
  saved=s
  call evaluate_surface_supply(s,0d0,dt,-0.5d0,r,status)
  call require(status==0,'valid mixture')
  call literal_surface(0d0,s%rain_rate,s%rain_c,s%irrigation_rate,s%irrigation_c,-0.5d0,0d0,dt,c,transfer,remaining)
  call require(r%pond_concentration==c.and.r%soil_transfer==transfer.and.r%mass_after==remaining,'literal surface formula')
  call require(r%mass_after==0d0.and.r%soil_transfer==0.125d0*dt,'units and full supply balance')
  call require(s%rain_rate==saved%rain_rate.and.s%rain_c==saved%rain_c.and.s%t1==saved%t1,'input nonmutation')
 end do
 do i=1,14
  bad=s
  select case(i)
  case(1)
   bad%rain_rate=-1d0
  case(2)
   bad%rain_c=-1d0
  case(3)
   bad%irrigation_rate=ieee_value(0d0,ieee_quiet_nan)
  case(4)
   bad%rain_rate=huge(0d0);bad%irrigation_rate=huge(0d0)
  case(5)
   bad%rain_c=huge(0d0)
  case(6)
   bad%t1=bad%t0
  case(7)
   bad%source_id=0
  case(8)
   bad%revision=-1
  case(9)
   bad%rain_rate=1d-6;bad%irrigation_rate=0d0
  case(10)
   bad%rain_rate=1d-7;bad%irrigation_rate=0d0
  case(11)
   bad%t1=1d-200
  case(12)
   bad%t1=1001d0
  case(13)
   bad%t0=ieee_value(0d0,ieee_quiet_nan)
  case(14)
   bad%irrigation_c=-1d0
  end select
  call require(.not.surface_supply_valid(bad),'invalid input')
 end do
 call evaluate_surface_supply(s,0d0,dt,0.5d0,r,status)
 call require(status/=0,'exfiltration excluded')
 call evaluate_surface_supply(s,0d0,dt,-0.25d0,r,status)
 call require(status/=0,'unmatched accepted flux excluded')
 ! This finite mismatch passed the old relative-rate tolerance but exceeds
 ! the hard integrated water budget over the1000-day bounded window.
 s=surface_supply_t(1_int64,0_int64,0d0,1000d0,5d5,5d5,0.125d0,0.375d0)
 call evaluate_surface_supply(s,0d0,1000d0,-1d6+1d-7,r,status)
 call require(status/=0,'large finite near-match cannot violate absolute water budget')
 s=surface_supply_t(1_int64,0_int64,0d0,dt,0.25d0,0.25d0,0.125d0,0.375d0)
 call evaluate_surface_supply(s,0d0,dt,-0.5d0+1d-14,r,status)
 call require(status/=0,'near-match rejected without hidden water source')
 s%rain_rate=0d0;s%irrigation_rate=0d0
 call evaluate_surface_supply(s,0d0,dt,0d0,r,status)
 call require(status==0.and.r%soil_transfer==0d0,'zero supply hiatus')
 s%rain_rate=2d-6
 call evaluate_surface_supply(s,0d0,dt,-2d-6,r,status)
 call require(status==0,'just above historical infiltration threshold')
 print '(A)','SURFACE_LITERAL_150_UNITS_BALANCE_INVALID_CUTOFF=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print '(A)','FAIL '//label
   error stop 1
  end if
 end subroutine
end program
