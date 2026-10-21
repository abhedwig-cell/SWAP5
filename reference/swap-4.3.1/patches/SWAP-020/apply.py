"""Exact-byte bounded reference transform; never edits the authority archive."""
from pathlib import Path
import hashlib

HERE = Path(__file__).resolve().parent
PINS = {
    'management_soil.f90': '0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b',
    'wofost_soil_watern.f90': 'b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722',
}
FIELDS = ['nh4_old', 'nh4_end', 'no3_old', 'no3_end', 'organic_old', 'organic_end',
          'nh4_sources', 'no3_sources', 'organic_sources', 'nh4_uptake', 'no3_uptake',
          'nh4_out', 'no3_out', 'denitrification', 'volatilisation', 'mineralisation',
          'nitrification', 'nh4_top_requested', 'no3_top_requested', 'nh4_top_actual',
          'no3_top_actual', 'nh4_unmet', 'no3_unmet', 'nh4_tau', 'no3_tau']


def digest(b):
    return hashlib.sha256(b).hexdigest()


def replace_once(raw, old, new):
    if raw.count(old) != 1:
        raise ValueError('nonunique original source anchor ' + repr(old[:70]))
    return raw.replace(old, new, 1)


def transform(sources):
    for p, h in PINS.items():
        if digest(sources[p]) != h:
            raise ValueError('incorrect original preimage ' + p)
    result = dict(sources)
    raw = sources['management_soil.f90']
    newline = '\r\n' if b'\r\n' in raw else '\n'
    s = raw.decode('cp1252').replace('\r\n', '\n')
    s = replace_once(s, '      integer :: stat! ,imat',
        '      real(8) :: top_n_actual(2), top_n_unmet(2), top_n_tau(2)\n'
        '      integer :: bounded_status, bounded_unit\n'
        '      integer :: stat! ,imat')
    anchor = '      if (FlNuptJuvenil) then\n'
    pos = s.index(anchor)
    insertion = '''      top_n_actual = Wflux_inTop * [cNH4N_top,cNO3N_top]
      top_n_unmet = 0d0
      top_n_tau = dt_WSN
      if (Wflux_inTop < 0d0 .and. .not.fl_cropcalendar) then
         call Wofost_SoilWaterN_Negative(dz_WSN,dt_WSN,WFrac_t,WFrac_t0, &
              Wflux_out,Wflux_transp,Wflux_inBot,Wflux_inTop,Wflux_inLat, &
              0d0,RateConNitrif,ProdRate0,SorpCoef,cNH4N_seep,cNH4N_top, &
              cNH4N_lat,cNH4_t0,cNH4_t,cNH4_av,top_n_actual(1), &
              top_n_unmet(1),top_n_tau(1),bounded_status)
         if (bounded_status /= 0) call swap_error('SWAP-020','Unsupported NH4 negative aggregate')
         NsupplyNH4N = 0d0
         ProdRate0 = .5d0*(WFrac_t+WFrac_t0)*RateConNitrif*cNH4_av
         call Wofost_SoilWaterN_Negative(dz_WSN,dt_WSN,WFrac_t,WFrac_t0, &
              Wflux_out,Wflux_transp,Wflux_inBot,Wflux_inTop,Wflux_inLat, &
              0d0,RateConDenitr,ProdRate0,0d0,cNO3N_seep,cNO3N_top, &
              cNO3N_lat,cNO3_t0,cNO3_t,cNO3_av,top_n_actual(2), &
              top_n_unmet(2),top_n_tau(2),bounded_status)
         if (bounded_status /= 0) call swap_error('SWAP-020','Unsupported NO3 negative aggregate')
         NsupplyNO3N = 0d0
      else
'''
    s = s[:pos] + insertion + s[pos:]
    s = replace_once(s, '      Nsupply = ( NsupplyNH4N + NsupplyNO3N ) * dz_WSN',
                       '      end if ! SWAP-020 bounded fallow branch\n\n'
                       '      Nsupply = ( NsupplyNH4N + NsupplyNO3N ) * dz_WSN')
    s = replace_once(s, '      Call Wofost_SoilBalanceCheck',
        '      Call Wofost_SoilBalanceCheck(top_n_actual)\n'
        "      open(newunit=bounded_unit,file='bounded_n_book.csv',status='unknown',position='append')\n"
        "      write(bounded_unit,'(a11,25(\",\",es25.16))') date, &\n"
        '           NH4_old,NH4_end,NO3_old,NO3_end, &\n'
        '           NFOM_old+NBio_old+NHum_old,NFOM_end+NBio_end+NHum_end, &\n'
        '           NH4N_amend+NH4N_cres+NH4_inlat+NH4_inbot, &\n'
        '           NO3N_amend+NO3N_cres+NO3_inlat+NO3_inbot, &\n'
        '           NFOM_add+NFOM_cres+NHum_add+NHum_cres, &\n'
        '           NH4_upt,NO3_upt,NH4_out,NO3_out,NO3_denitr,NH4N_volat, &\n'
        '           NH4_miner,NH4_nitrif, &\n'
        '           Wflux_inTop*cNH4N_top*dt_WSN,Wflux_inTop*cNO3N_top*dt_WSN, &\n'
        '           top_n_actual*dt_WSN,top_n_unmet,top_n_tau\n'
        '      close(bounded_unit)')
    result['management_soil.f90'] = s.replace('\n', newline).encode('cp1252')
    raw = sources['wofost_soil_balancecheck.f90']
    nl = b'\r\n' if b'\r\n' in raw else b'\n'
    raw = replace_once(raw, b'   subroutine wofost_soilbalancecheck',
                           b'   subroutine wofost_soilbalancecheck(top_n_actual)')
    raw = replace_once(raw, b'      integer :: fn', b'      real(8), intent(in) :: top_n_actual(2)' + nl + b'      integer :: fn')
    raw = replace_once(raw, b'cNH4N_top  * Wflux_inTop * dt_WSN', b'top_n_actual(1) * dt_WSN')
    raw = replace_once(raw, b'cNO3N_top * Wflux_inTop * dt_WSN', b'top_n_actual(2) * dt_WSN')
    result['wofost_soil_balancecheck.f90'] = raw
    raw = sources['wofost_soil_watern.f90']
    result['wofost_soil_watern.f90'] = raw + nl + (HERE/'negative_boundary.f90').read_bytes().replace(b'\n', nl)
    return result
