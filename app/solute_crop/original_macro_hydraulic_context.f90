! Isolated preparation dependencies for exact archived model1 procedures.
! Unsupported scientific branches terminate; they never return substitute values.
module DoublePrec
 use iso_fortran_env,only:dp=>real64
end module
module SHPvariables
 integer::iLayer=0
end module
module doln
 logical::do_ln_trans=.false.
end module
module MOD_SoilTemperature
 use MOD_arrays,only:macp
 real(8)::tsoil(macp)=0d0
end module
module MOD_drain
 use MOD_arrays,only:madr
 integer::swdtyp(madr)=0
end module
module MOD_RIA
 use DoublePrec
contains
 real(dp) function WCRIA(h)
 real(dp),intent(in)::h
 error stop 'unsupported RIA in original macro preparation'
 end function
 real(dp) function RIAderivative(h)
 real(dp),intent(in)::h
 error stop 'unsupported RIA in original macro preparation'
 end function
 subroutine SingleKcomponents(h,t,k,a,b,c,d)
 real(dp),intent(in)::h,t
 real(dp),intent(out)::k,a,b,c,d
 error stop 'unsupported RIA in original macro preparation'
 end subroutine
 subroutine RIAKDerivativeFromState()
 error stop 'unsupported RIA in original macro preparation'
 end subroutine
 logical function RIAStencilCrossesBoundary()
 error stop 'unsupported RIA in original macro preparation'
 end function
end module
module WC_K_models_04_11
contains
 real(8) function functionvalue_04_11(task,node,models,cofgen,head,wc,temp)
 integer,intent(in)::task,node,models(:)
 real(8),intent(in)::cofgen(:,:),head
 real(8),optional,intent(in)::wc,temp
 error stop 'unsupported PDI in original macro preparation'
 end function
end module
subroutine EvalTabulatedFunction(a,b,c,d,e,f,g,h,i,j,k,l)
 integer::a,b,c,d,e,f,h(*),l
 real(8)::g(*),i,j,k
 error stop 'unsupported tables in original macro preparation'
end subroutine
subroutine swap_warning(name,message)
 character(*),intent(in)::name,message
 print '(a)',trim(name)//': '//trim(message)
 error stop 'unexpected warning in original macro preparation'
end subroutine
