module swap_exchange

   type :: swap_input

      !sequence

      ! start and finish time; typically a single day is to be considered, which means Tend = Tstart!!!
      ! units: days since 1900-01-01
      real(8)                             :: tstart, tend

      ! weather data
      ! units:                               oC    oC    kPa  m/s   mm/d  -    mm/d   kJ/m2/d
      real(8)                             :: tmin, tmax, hum, wind, rain, wet, etref, rad

      ! crop variables from external crop
      ! cropheight, rooting depth and lai of external crop; overwrites value of dummy crop
      ! units                                cm  cm     m2/m2
      real(8)                             :: ch, zroot, lai

      ! yes (1) or no (0) crop present
      integer(8)                          :: icrop

      ! yes (1) or no (0) use externally provided PTRANS and PEVAP
      integer(8)                          :: ipet

      ! units:                               mm/d    mm/d
      real(8)                             :: ptrans, pevap

      ! irrigation: fixed option; daily amounts
      integer(8)                          :: swirfix        ! 0: no irigation today; 1: irrigation current day
      real(8)                             :: irdate         ! current date in t1900 units
      real(8)                             :: irdepth        ! mm (per day)
      integer(8)                          :: irtype

      ! SSDI irrigation: fixed option; daily amounts
      integer(8)                          :: swssdi         ! 0: no irigation today; 1: irrigation current day
      real(8)                             :: ssdi_date      ! current date in t1900 units
      real(8)                             :: ssdi_rate_f    ! mm/h
      real(8)                             :: ssdi_amount_f  ! mm
      integer(8)                          :: ssdi_node

      !!!character(len = 32)                 :: swapfilename
      
   end type

   type :: swap_output

      !sequence
      real(8)                             :: tstart, tend

      ! actual number of nodes of whole oil profile; also actual length of return arrays
      integer(8)                          :: numnodes

      ! Potential and actual daily transpiration
      real(8)                             :: tpot, tact

      ! Potential and actual daily soil evaporation
      real(8)                             :: epot, eact

      ! for error handling
      integer(8)                          :: ierrorcode

      ! Actual groundwater level
      real(8)                             :: gwl

      ! return arrays: thickness of all soil layers, and per layer:
      ! volumetric water content, root water uptake, soil temperature, water fluxes (integrated), drain fluxes (integrated, alle levels summed)
      real(8), dimension(501)             :: dz
      real(8), dimension(501)             :: h
      real(8), dimension(501)             :: wc
      real(8), dimension(501)             :: rwu
      real(8), dimension(501)             :: tsoil
      real(8), dimension(501)             :: q
      real(8), dimension(501)             :: qdra

      real(8)                             :: igird    ! actual amount of irrigation (cm; per day)
      real(8)                             :: iqssdi   ! actual amount of SSDI irrigation (cm; per day)

   end type
   
end module swap_exchange

subroutine SWAP_4_DFF(iCaller, iTask, toswap, fromswap) 

! This is needed in case a swap.dll is to be constructed
!DEC$ IF (linux==0)
!dec$ attributes dllexport :: SWAP_4_DFF
!DEC$ END IF

use MOD_arrays, only: fillen
use swap_exchange

implicit none

interface
   subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap, worker, trial_mass, interval)
      use swap_exchange
      use MOD_arrays, only: fillen
