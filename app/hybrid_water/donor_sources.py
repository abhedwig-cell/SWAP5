"""Build-time transformations of the pinned SWAP 4.3.1 donor."""

import hashlib
import re


def replace(text, anchor, replacement):
    if text.count(anchor) != 1:
        raise ValueError(f"Expected a unique donor anchor: {anchor!r}")
    return text.replace(anchor, replacement)


def render_day_return(selected, out, *, nonmacro=False, solute_ledger=False):
    swap = (selected / "swap.f90").read_text(encoding="cp1252")
    swap = """module hybrid_day_window
  implicit none
  logical :: return_at_day_end = .false.
end module hybrid_day_window

""" + swap
    swap = replace(swap, "use MOD_swap_base,       only: pathwork,",
                   "use hybrid_day_window, only: return_at_day_end\n"
                   "use MOD_swap_base,       only: pathwork,")
    anchor = ("   end do\n\n!  Specific for exchange when called as DLL\n"
              "   if (iCaller == 2) call handle_exchange(29, flError)")
    swap = replace(swap, anchor, "      if (return_at_day_end .and. flDayEnd) return\n\n" + anchor)
    (out / "swap.f90").write_text(swap, encoding="cp1252")

    main = (selected / "swap_main.f90").read_text(encoding="cp1252")
    main = replace(main, "use MOD_swap_base, only: unit_log",
                   "use hybrid_day_window, only: return_at_day_end\n"
                   "use Variables, only: t1900, flrunend\n"
                   "use MOD_swap_base, only: unit_log")
    main = replace(main, "integer              :: iTask",
                   "integer              :: iTask, window\nreal(8)              :: window_start")
    anchor = ("   if (iCaller == 0) call swap(iCaller, iTask, tstart_in, tend_in)\n"
              "   !!!if (iCaller /= 0) call dummy(iTask)\n\n!  Close swap")
    main = replace(main, anchor, """   return_at_day_end = .true.
   do window = 1, 4
      window_start = t1900
      if (flrunend) error stop 'Donor ended before requested day'
      call swap(iCaller, iTask, tstart_in, tend_in)
      if (abs(t1900 - window_start - 1d0) > 1d-8) error stop 'Unexpected day boundary'
      write(*,'(a,i0,1x,f18.8)') 'HYBRID_DAY_RETURN ', window, t1900
   end do

!  Close swap""")
    (out / "swap_main.f90").write_text(main, encoding="cp1252")

    csv_source = (selected / "swap_csv_output.f90").read_text(encoding="cp1252")
    anchor = "   dstor_1    = wasrdm1 - iwasrdm1beg"
    csv_source = replace(csv_source, anchor, """   write(*,'(a,12(1x,es25.17e3))') 'HYBRID_STOCK_FLUX', &
      volact, pond, ssnow, sicact, wasrdm1, wasrdm2, &
      ivolbeg, ipondbeg, issnowbeg, isicbeg, iwasrdm1beg, iwasrdm2beg
   write(*,'(a,16(1x,es25.17e3))') 'HYBRID_EXTERNAL_FLUX', &
      igrai,isnrai,igsnow,igird,irunon,iqssdi,iqbup, &
      iintc,iruno,iqrot,iepd,ievap,isubl,iqdra,iQMpOutDrRap,iqbdo
""" + anchor)
    if nonmacro:
        csv_source=replace(csv_source,"volact, pond, ssnow, sicact, wasrdm1, wasrdm2, &",
                           "volact, pond, ssnow, sicact, 0d0, 0d0, &")
        csv_source=replace(csv_source,"ivolbeg, ipondbeg, issnowbeg, isicbeg, iwasrdm1beg, iwasrdm2beg",
                           "ivolbeg, ipondbeg, issnowbeg, isicbeg, 0d0, 0d0")
        csv_source=replace(csv_source,"iintc,iruno,iqrot,iepd,ievap,isubl,iqdra,iQMpOutDrRap,iqbdo",
                           "iintc,iruno,iqrot,iepd,ievap,isubl,iqdra,0d0,iqbdo")
    if solute_ledger:
        csv_source=replace(csv_source,"   dstor_1    = wasrdm1 - iwasrdm1beg","""   write(*,'(a,9(1x,es25.17e3))') 'HYBRID_SOLUTE_LEDGER', &
      sampro,sdstor,imsqprec,imsqirrig,imsqbot,imsqdra,imdectot,imrottot,sbaldev
   write(*,'(a,6(1x,es25.17e3))') 'HYBRID_UPTAKE', iptra,iqrot,iqreddry,iqredwet,iqredsol,iqredfrs
   dstor_1    = wasrdm1 - iwasrdm1beg""")
    (out / "swap_csv_output.f90").write_text(csv_source, encoding="cp1252")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def records(lines):
    return [line for line in lines if line.strip() and not line.startswith("*")]


def saved_names(text):
    return re.findall(r"^\s*[^!\n]+,\s*save\s*::\s*(\w+)\s*=", text,
                      flags=re.MULTILINE | re.IGNORECASE)


def render_checkpoint(build, output, checkpoint_day, days=2, *, runtime=False, nonmacro=False, solute_state=False, hydraulic_history=False, thermal_history=False):
    selected = build / "swap-selected"
    macro = (selected / "macropore.f90").read_text(encoding="cp1252")
    variables = (selected / "variables.f90").read_text(encoding="cp1252")
    fields = saved_names(macro.split("! --- Macropore variables", 1)[1].split("contains", 1)[0])
    fields.remove("bma")  # Fortran output unit belongs to the new process.
    shared = saved_names(variables.split("module MOD_swap_mp\n", 1)[1].split("end module", 1)[0])
    fields.remove("NumDm")  # Geometry from initialization is the header authority.
    fields += shared
    if len(fields) != len(set(name.lower() for name in fields)):
        raise ValueError("Duplicate macropore checkpoint fields")
    payload = ", &\n      ".join(", ".join(fields[i:i+4]) for i in range(0, len(fields), 4))
    codec = f"""
    subroutine hybrid_macro_checkpoint(restoring, clock, old_step, canopy_stock)
      use MOD_swap_mp
      use MOD_grid, only: numnod
      implicit none
      logical, intent(in) :: restoring
      real(8), intent(in) :: clock
      real(8), intent(inout) :: old_step, canopy_stock
      integer :: unit, ios, nodes, domains
      real(8) :: stored_clock
      character(8) :: magic
      character :: trailing

      if (restoring) then
        open(newunit=unit,file='../first/macro.bin',access='stream',form='unformatted', &
             status='old',action='read',iostat=ios)
        if (ios /= 0) error stop 'Missing macro checkpoint'
        read(unit,iostat=ios) magic, nodes, domains, stored_clock, old_step, canopy_stock
        if (ios /= 0) error stop 'Incomplete macro checkpoint header'
        if (magic /= 'S5MAC003' .or. nodes /= numnod .or. domains /= NumDm .or. &
            stored_clock /= clock) error stop 'Incompatible macro checkpoint'
        read(unit,iostat=ios) &
      {payload}
        if (ios /= 0) error stop 'Incomplete macro checkpoint payload'
        read(unit,iostat=ios) trailing
        if (.not. is_iostat_end(ios)) error stop 'Trailing macro checkpoint bytes'
      else
        open(newunit=unit,file='macro.bin',access='stream',form='unformatted', &
             status='new',action='write')
        write(unit) 'S5MAC003', numnod, NumDm, clock, old_step, canopy_stock
        write(unit) &
      {payload}
      end if
      close(unit)
      write(*,'(a,*(1x,z16.16))') 'HYBRID_MACRO_DOMAIN_BITS', &
        transfer(WaUnMpDm(1:NumDm), [0_8], NumDm)
    end subroutine hybrid_macro_checkpoint
"""
    if nonmacro:
        codec = """
    subroutine hybrid_macro_checkpoint(restoring, clock, old_step, canopy_stock)
      use MOD_grid, only: numnod
      use MOD_swap_base, only: swmacro
      use variables, only: t, iyear
      use ieee_arithmetic, only: ieee_is_finite
      implicit none
      logical, intent(in) :: restoring
      real(8), intent(in) :: clock
      real(8), intent(inout) :: old_step, canopy_stock
      integer :: unit,ios,nodes
      real(8) :: stored_clock
      character(8) :: magic
      character :: trailing
      if (swmacro/=0) error stop 'Nonmacro checkpoint requires absent macropores'
      if (restoring) then
        open(newunit=unit,file='../first/macro.bin',access='stream',form='unformatted', &
             status='old',action='read',iostat=ios)
        if(ios/=0) error stop 'Missing nonmacro checkpoint'
        read(unit,iostat=ios) magic,nodes,stored_clock,old_step,canopy_stock
        if(ios/=0) error stop 'Incomplete nonmacro checkpoint'
        if(magic/='S5NON006'.or.nodes/=numnod.or.stored_clock/=clock) error stop 'Foreign nonmacro checkpoint'
        read(unit,iostat=ios) t,iyear
        if(ios/=0) error stop 'Missing nonmacro seasonal clock'
        if(.not.ieee_is_finite(t)) error stop 'Nonfinite nonmacro seasonal clock'
        if(iyear<1.or.iyear>9999) error stop 'Invalid nonmacro calendar year'
        read(unit,iostat=ios) trailing
        if(.not.is_iostat_end(ios)) error stop 'Trailing nonmacro checkpoint bytes'
      else
        open(newunit=unit,file='macro.bin',access='stream',form='unformatted',status='new',action='write')
        write(unit) 'S5NON006',numnod,clock,old_step,canopy_stock
        write(unit) t,iyear
      end if
      close(unit)
    end subroutine hybrid_macro_checkpoint
"""
    if solute_state:
        if not nonmacro:raise ValueError('Solute auxiliary requires nonmacro mode')
        codec=codec.replace('S5NON006','S5HUP012')
        codec=replace(codec,"      use MOD_swap_base, only: swmacro",
                      "      use MOD_swap_base, only: swmacro\n      use MOD_solute, only: hybrid_solute_checkpoint\n      use MOD_irrigation,only:hybrid_irrigation_checkpoint\n      use MOD_wofost,only:hybrid_wofost_checkpoint")
        codec=replace(codec,"        read(unit,iostat=ios) trailing",
                      "        call hybrid_solute_checkpoint(unit,.true.)\n        call hybrid_irrigation_checkpoint(unit,.true.)\n        call hybrid_wofost_checkpoint(unit,.true.)\n        read(unit,iostat=ios) trailing")
        codec=replace(codec,"        write(unit) t,iyear",
                      "        write(unit) t,iyear\n        call hybrid_solute_checkpoint(unit,.false.)\n        call hybrid_irrigation_checkpoint(unit,.false.)\n        call hybrid_wofost_checkpoint(unit,.false.)")
    if hydraulic_history:
        if not nonmacro:raise ValueError('Hydraulic history requires absent macropores')
        # Hysteresis can change h/scanning state after the accepted Richards
        # solve. Recomputing theta/K/capacity from h during cold initialization
        # does not reproduce that accepted hydraulic carry. Keep the actual
        # active history, not an inverse constitutive reconstruction.
        fields='h(1:numnod),theta(1:numnod),k(1:numnod+1),kmean(1:numnod+1),dimoca(1:numnod),gwl,volact'
        codec=replace(codec,'      use variables, only: t, iyear',
                      '      use variables, only: t, iyear, h,theta,k,kmean,dimoca,gwl,volact')
        codec=replace(codec,'      use MOD_grid, only: numnod','      use MOD_grid, only: numnod,dz')
        old_magic='S5HUP012' if solute_state else 'S5NON006'
        new_magic='S5SHS013' if solute_state else 'S5NHS007'
        codec=codec.replace(old_magic,new_magic)
        codec=replace(codec,'        read(unit,iostat=ios) trailing',f"""        read(unit,iostat=ios) {fields}
        if(ios/=0)error stop 'Incomplete hysteresis hydraulic history'
        if(.not.all(ieee_is_finite([{fields}])))error stop 'Nonfinite hysteresis hydraulic history'
        if(any(theta(1:numnod)<0d0).or.any(k(1:numnod+1)<0d0).or.any(kmean(1:numnod+1)<0d0).or. &
           any(dimoca(1:numnod)<0d0).or.volact<0d0)error stop 'Invalid hysteresis hydraulic history'
        if(abs(sum(theta(1:numnod)*dz(1:numnod))-volact)>1d-10)error stop 'Unbalanced hysteresis water history'
        read(unit,iostat=ios) trailing""")
        anchor='        call hybrid_wofost_checkpoint(unit,.false.)' if solute_state else '        write(unit) t,iyear'
        codec=replace(codec,anchor,anchor+'\n        write(unit) '+fields)
    if thermal_history:
        if not nonmacro:raise ValueError('Snow thermal history requires absent macropores')
        # Under snow, the next top boundary uses the PREVIOUS accepted heacon
        # before DeVries computes the next coefficient. Native TSOIL alone is
        # therefore not a complete restart of this original boundary law.
        fields='heacon(1:numnod),heacap(1:numnod),tetop,tebot'
        codec=replace(codec,'      use variables, only: t, iyear',
                      '      use MOD_SoilTemperature,only:heacon,heacap,tetop,tebot\n      use variables, only: t, iyear')
        old_magic=('S5SHS013' if solute_state else 'S5NHS007') if hydraulic_history else ('S5HUP012' if solute_state else 'S5NON006')
        new_magic=('S5SMX015' if solute_state else 'S5NMX009') if hydraulic_history else ('S5SSN014' if solute_state else 'S5NSN008')
        codec=codec.replace(old_magic,new_magic)
        codec=replace(codec,'        read(unit,iostat=ios) trailing',f"""        read(unit,iostat=ios) {fields}
        if(ios/=0)error stop 'Incomplete snow thermal history'
        if(.not.all(ieee_is_finite([{fields}])))error stop 'Nonfinite snow thermal history'
        if(any(heacon(1:numnod)<=0d0).or.any(heacap(1:numnod)<=0d0))error stop 'Invalid snow thermal history'
        read(unit,iostat=ios) trailing""")
        if hydraulic_history:
            anchor='        write(unit) h(1:numnod),theta(1:numnod),k(1:numnod+1),kmean(1:numnod+1),dimoca(1:numnod),gwl,volact'
        else:
            anchor='        call hybrid_wofost_checkpoint(unit,.false.)' if solute_state else '        write(unit) t,iyear'
        codec=replace(codec,anchor,anchor+'\n        write(unit) '+fields)
    if runtime:
        codec = replace(codec, "../first/macro.bin", "macro-origin.bin")
    macro = replace(macro, "   contains\n", "   contains\n" + codec)
    (output / "macropore.f90").write_text(macro, encoding="cp1252")
    swap = (selected / "swap.f90").read_text(encoding="cp1252")
    swap = replace(swap, "only: macrostatevar, macropore",
                   "only: macrostatevar, macropore, hybrid_macro_checkpoint")
    swap = replace(swap, "logical :: flError", "logical :: flError\nreal(8), save :: checkpoint_canopy = -1d0")
    swap = replace(swap, "         if (swcrop == 1) call croprotation(2)",
                   """         if (swcrop == 1) call croprotation(2)
         if (checkpoint_canopy >= 0d0) then
           sicact = checkpoint_canopy
           checkpoint_canopy = -1d0
         end if""")
    swap = replace(swap, "   if (swmacro == 1) call MacroPore(1)",
                   "   if (swmacro == 1) call MacroPore(1)\n"
                   "   if (swmacro == 1 .and. fl_initialize) call hybrid_macro_checkpoint(.true., t1900, dtold, checkpoint_canopy)")
    swap = replace(swap, "gwl, gwlm1, dt, t1900", "gwl, gwlm1, dt, t1900, dtold, h, theta, pond, qrot")
    if runtime:
        swap = replace(swap, "fl_cropharvest, fl_cropharvestday",
                       "fl_cropharvest, fl_cropharvestday, sicact")
    else:
        swap = replace(swap, "only: meteo, interception_daily, peva, empreva, epond",
                       "only: meteo, interception_daily, peva, empreva, epond, nraidt, ptra, ptra_dry, ptra_wet, wfrac")
        swap = replace(swap, "fl_cropharvest, fl_cropharvestday", "fl_cropharvest, fl_cropharvestday, sicact, siccap, sw_inter")
        swap = replace(swap, "         call Meteo(3)", """         if (flDayStart .and. nint(t1900) == 35797) then
           write(*,*) "HYBRID_CANOPY", sicact, siccap, sw_inter
         end if
         call Meteo(3)""")
        swap = replace(swap, "use MOD_drain,           only: drain", "use MOD_drain,           only: drain, qdra")
        swap = replace(swap, "         if (.NOT.fldecdt) call SoilWater(2)", """         if (flDayStart .and. nint(t1900) == 35797 .and. .not. fldecdt) then
           write(*,'(a,*(1x,es25.17e3))') 'HYBRID_FIRST_INPUT', &
             nraidt, h(1:numnod), theta(1:numnod), qrot(1:numnod), sum(qdra(:,1:numnod), dim=1)
         end if
         if (.NOT.fldecdt) call SoilWater(2)""")
        swap = replace(swap, "!     calculate SoilWater rate/state variables",
                       """      if (t1900 >= 35797d0 .and. t1900 < 35799d0) then
        write(*,'(a,*(1x,es25.17e3))') 'HYBRID_ACCEPTED_TRAJECTORY', &
          t1900, dt, ptra, sicact, pond, h(1:numnod), theta(1:numnod), tsoil(1:numnod)
      end if
      if (flDayStart .and. nint(t1900) == 35797) then
        write(*,'(a,*(1x,es25.17e3))') 'HYBRID_FIRST_ACCEPTED', &
          t1900, dt, dtold, pond, gwl, epond, peva, ptra, ptra_dry, ptra_wet, wfrac, h(1:numnod), theta(1:numnod)
      end if
!     calculate SoilWater rate/state variables""")
    anchor = "   end do\n\n!  Specific for exchange when called as DLL"
    swap = replace(swap, anchor, """      if (swinco /= 3 .and. flDayEnd .and. t1900 == tstart + 2d0) then
        sw_end = 1
        call SoilWaterOutput(3)
        call hybrid_macro_checkpoint(.false., t1900, dtold, sicact)
        sw_end = 0
      end if
""" + anchor)
    if runtime:
        swap = replace(swap, "swinco /= 3 .and. flDayEnd .and. t1900 == tstart + 2d0",
                       "flDayEnd .and. t1900 == checkpoint_clock")
    else:
        clock = 35795 + checkpoint_day
        swap = swap.replace("35797", str(clock)).replace("35799", str(clock + days))
        swap = swap.replace("tstart + 2d0", f"tstart + {checkpoint_day}d0")
    if nonmacro:
        swap=replace(swap,"if (swmacro == 1 .and. fl_initialize) call hybrid_macro_checkpoint",
                          "if (swmacro == 0 .and. fl_initialize) call hybrid_macro_checkpoint")
    if solute_state:
        restore="   if (swmacro == 0 .and. fl_initialize) call hybrid_macro_checkpoint(.true., t1900, dtold, checkpoint_canopy)"
        swap=replace(swap,"use MOD_cropdevelopment, only: croprotation, cropdevelopment, reset_crop",
                     "use MOD_wofost,only:hybrid_apply_wofost\nuse MOD_cropdevelopment, only: croprotation, cropdevelopment, reset_crop")
        swap=replace(swap, "use MOD_irrigation,      only: irrigation, flirrigate",
                     "use MOD_irrigation,      only: irrigation, flirrigate, hybrid_apply_irrigation")
        swap=replace(swap,"         if (checkpoint_canopy >= 0d0) then",
                     "         call hybrid_apply_irrigation(fl_cropemergence)\n         call hybrid_apply_wofost(fl_cropemergence)\n         if (checkpoint_canopy >= 0d0) then")
        swap=replace(swap,restore,"")
        swap=replace(swap,"   if (swsolu > 0) call Solute(1)","   if (swsolu > 0) call Solute(1)\n"+restore)
    (output / "swap.f90").write_text(swap, encoding="cp1252")
    if runtime or checkpoint_day >= 365:
        source = (selected / "swapoutput.f90").read_text(encoding="cp1252")
        source = replace(source,
                         "                  if (.NOT. fl_cropcalendar) call swap_error ('read_ini', 'no crop information in ini-file')",
                         ("                  if (.NOT. fl_cropcalendar .and. rw == 1 .and. tstart >= 36160d0) exit\n"
                          "                  if (.NOT. fl_cropcalendar) call swap_error ('read_ini', 'no crop information in ini-file')"
                          if runtime else "                  if (.NOT. fl_cropcalendar .and. rw == 1) exit"))
        (output / "swapoutput.f90").write_text(source, encoding="cp1252")
    return fields


def render_no_macro_timecontrol(selected, output):
    """Use the configured daily proposal, independent of yesterday's event cut.

    This numerical policy changes no event cap, Newton test or step-rejection
    rule. It owns no new saved state: original TimeControl(2) applies DTMAX at
    every day start, including a native restart, before its original event cap.
    """
    source=(selected/'timecontrol.f90').read_text(encoding='cp1252')
    source=replace(source,'         dt = max(dt, dsqrt(dtmin*dtmax))',
                   '         dt = dtmax  ! SWAP5 configured-dtmax-daily-v1')
    (output/'timecontrol.f90').write_text(source,encoding='cp1252')
