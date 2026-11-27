"""Opt-in post-event private-state seam; SWTILL input admission stays closed.

This component does not serialize an uninitialized pre-event working allocation.
The caller owns physical BDENS/MvG/water state and must restore that separately.
No scientific tillage trajectory is qualified by this component alone.
"""
import hashlib

ORIGINAL_SHA='731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486'
INTEGERS=('Ntill','iTill','Ntypes','i_n_model','iRedist','MaxNumSoilHo','MaxNumSoilCP')
INTEGER_ARRAYS={'Type_Tillage':'Ntill','iType_Tillage':'Ntypes','iTT1':'Ntill','iTT2':'Ntill'}
REAL_ARRAYS={'Date_tillage':'Ntill+1','Z_tillage':'Ntill','I_tillage':'Ntill','TAB_Rho_tillage':'Ntypes','TAB_Rho_cons':'Ntypes','TAB_K_R_cons':'Ntypes','Rho_tillage':'MaxNumSoilHo','Rho_cons':'MaxNumSoilHo','K_R_cons':'MaxNumSoilHo'}
MATCH_ARRAYS={'TAB_Rho_match':'Ntypes','TAB_N_match':'Ntypes','Rho_match':'MaxNumSoilHo','N_match':'MaxNumSoilHo','Slope_match':'MaxNumSoilHo'}
TYPE='hybrid_tillage_post_event_state'


def declarations():
    lines=['   ! Explicit post-event checkpoint; no reader or physics activation.',
           '   type, public :: '+TYPE,'      integer :: schema = 1',
           '      integer :: '+', '.join(n+' = 0' for n in INTEGERS),
           '      real(8) :: Max_Z_tillage = 0d0']
    for kind,names in [('integer',INTEGER_ARRAYS),('real(8)',{**REAL_ARRAYS,**MATCH_ARRAYS})]:
        for name in names:lines.append('      '+kind+', allocatable :: '+name+'(:)')
    return '\n'.join(lines+['   end type '+TYPE,'   public :: hybrid_tillage_capture_post_event, hybrid_tillage_restore_post_event',
        '   public :: hybrid_tillage_write_post_event, hybrid_tillage_read_post_event',''])


def routines():
    lines=['   logical function hybrid_tillage_valid(s) result(ok)',
           '      use, intrinsic :: ieee_arithmetic, only: ieee_is_finite',
           '      type('+TYPE+'), intent(in) :: s','      ok = .false.',
           '      if (s%schema /= 1) return',
           '      if (s%Ntill < 1 .or. s%Ntill > 100000 .or. s%Ntypes < 1 .or. s%Ntypes > 100000) return',
           '      if (s%iTill < 2 .or. s%iTill > s%Ntill+1) return',
           '      if (s%i_n_model < 1 .or. s%i_n_model > 3 .or. s%iRedist < 0 .or. s%iRedist > 2) return',
           '      if (s%MaxNumSoilHo < 1 .or. s%MaxNumSoilHo > NumLay) return',
           '      if (s%MaxNumSoilCP < 1 .or. s%MaxNumSoilCP > NumNod) return',
           '      if (.not.ieee_is_finite(s%Max_Z_tillage)) return']
    for name,size in {**INTEGER_ARRAYS,**REAL_ARRAYS}.items():
        lines += ['      if (.not.allocated(s%'+name+')) return','      if (size(s%'+name+') /= s%'+size+') return']
    for name in REAL_ARRAYS:lines.append('      if (.not.all(ieee_is_finite(s%'+name+'))) return')
    lines += ['      if (s%Ntill > 1) then',
              '         if (any(s%Date_tillage(2:s%Ntill) < s%Date_tillage(1:s%Ntill-1))) return',
              '      end if',
              '      if (any(s%Type_Tillage < 1) .or. any(s%Type_Tillage > s%Ntill)) return',
              '      if (any(s%iTT1 < 0) .or. any(s%iTT2 < s%iTT1) .or. any(s%iTT2 > s%Ntypes)) return',
              '      if (s%i_n_model == 3) then']
    for name,size in MATCH_ARRAYS.items():
        lines += ['         if (.not.allocated(s%'+name+')) return','         if (size(s%'+name+') /= s%'+size+') return',
                  '         if (.not.all(ieee_is_finite(s%'+name+'))) return']
    lines += ['      end if','      ok = .true.','   end function hybrid_tillage_valid','',
              '   subroutine hybrid_tillage_capture_post_event(s, ok)',
              '      type('+TYPE+'), intent(out) :: s','      logical, intent(out) :: ok',
              '      ok = .false.','      if (swtill /= 1) return',
              '      if (iTill < 2 .or. iTill > Ntill+1) return']
    for name in INTEGERS+('Max_Z_tillage',):lines.append('      s%'+name+' = '+name)
    for name,size in {**INTEGER_ARRAYS,**REAL_ARRAYS}.items():
        lines += ['      if (.not.allocated('+name+')) return','      if (size('+name+') < '+size+') return','      s%'+name+' = '+name+'(1:'+size+')']
    lines.append('      if (i_n_model == 3) then')
    for name,size in MATCH_ARRAYS.items():
        lines += ['         if (.not.allocated('+name+')) return','         if (size('+name+') < '+size+') return','         s%'+name+' = '+name+'(1:'+size+')']
    lines += ['      end if','      ok = hybrid_tillage_valid(s)','   end subroutine hybrid_tillage_capture_post_event','',
              '   subroutine hybrid_tillage_restore_post_event(s, ok)',
              '      type('+TYPE+'), intent(in) :: s','      type('+TYPE+') :: staged','      logical, intent(out) :: ok',
              '      ok = .false.','      if (swtill /= 1) return',
              '      if (.not.hybrid_tillage_valid(s)) return',
              '      staged = s ! Allocate all incoming storage before modifying module state.',
              '      ! All checks precede mutation. Allocatable assignment deep-copies.',
              '      ! Only defined live prefixes are stored; no undefined horizon tails.']
    for name in INTEGERS+('Max_Z_tillage',):lines.append('      '+name+' = s%'+name)
    for name in {**INTEGER_ARRAYS,**REAL_ARRAYS}:lines.append('      call move_alloc(staged%'+name+', '+name+')')
    lines.append('      if (i_n_model == 3) then')
    for name in MATCH_ARRAYS:lines.append('         call move_alloc(staged%'+name+', '+name+')')
    lines += ['      end if','      ok = .true.','   end subroutine hybrid_tillage_restore_post_event','']
    lines += codec()
    return '\n'.join(lines)+ '\n'


def codec():
    """Whole owned stream only; host still owns integrity and physical binding."""
    header=['s%schema',*( 's%'+name for name in INTEGERS),'s%Max_Z_tillage']
    lines=['   subroutine hybrid_tillage_write_post_event(unit, binding, s, ok)',
        '      integer, intent(in) :: unit','      character(len=64), intent(in) :: binding',
        '      type('+TYPE+'), intent(in) :: s','      logical, intent(out) :: ok','      integer :: io',
        '      ok = .false.','      if (.not.hybrid_tillage_valid(s)) return',
        "      if (verify(binding,'0123456789abcdef') /= 0) return",
        '      if (storage_size(s%Ntill) /= 32 .or. storage_size(s%Max_Z_tillage) /= 64) return',
        "      write(unit,iostat=io) 'SW5TIL01', '"+ORIGINAL_SHA+"', binding, "+', '.join(header),
        '      if (io /= 0) return']
    for name in {**INTEGER_ARRAYS,**REAL_ARRAYS}:
        lines += ['      write(unit,iostat=io) s%'+name,'      if (io /= 0) return']
    lines.append('      if (s%i_n_model == 3) then')
    for name in MATCH_ARRAYS:lines+=['         write(unit,iostat=io) s%'+name,'         if (io /= 0) return']
    lines += ['      end if','      ok = .true.','   end subroutine hybrid_tillage_write_post_event','',
        '   subroutine hybrid_tillage_read_post_event(unit, expected_binding, s, ok)',
        '      use, intrinsic :: ieee_arithmetic, only: ieee_is_finite',
        '      use, intrinsic :: iso_fortran_env, only: iostat_end',
        '      integer, intent(in) :: unit','      character(len=64), intent(in) :: expected_binding',
        '      type('+TYPE+'), intent(out) :: s','      logical, intent(out) :: ok',
        '      type('+TYPE+') :: staged','      character(len=8) :: magic',
        '      character(len=64) :: source_hash, binding','      character(len=1) :: trailer','      integer :: io',
        '      ok = .false.',
        '      read(unit,iostat=io) magic, source_hash, binding, '+', '.join(h.replace('s%','staged%') for h in header),
        '      if (io /= 0) return',"      if (magic /= 'SW5TIL01') return",
        "      if (source_hash /= '"+ORIGINAL_SHA+"') return",
        '      if (binding /= expected_binding) return',
        "      if (verify(expected_binding,'0123456789abcdef') /= 0) return",
        '      if (storage_size(staged%Ntill) /= 32 .or. storage_size(staged%Max_Z_tillage) /= 64) return',
        '      if (staged%schema /= 1) return',
        '      if (staged%Ntill < 1 .or. staged%Ntill > 100000 .or. staged%Ntypes < 1 .or. staged%Ntypes > 100000) return',
        '      if (staged%iTill < 2 .or. staged%iTill > staged%Ntill+1) return',
        '      if (staged%i_n_model < 1 .or. staged%i_n_model > 3) return',
        '      if (staged%iRedist < 0 .or. staged%iRedist > 2) return',
        '      if (staged%MaxNumSoilHo < 1 .or. staged%MaxNumSoilHo > NumLay) return',
        '      if (staged%MaxNumSoilCP < 1 .or. staged%MaxNumSoilCP > NumNod) return',
        '      if (.not.ieee_is_finite(staged%Max_Z_tillage)) return']
    for name,size in {**INTEGER_ARRAYS,**REAL_ARRAYS}.items():
        lines += ['      allocate(staged%'+name+'(staged%'+size+'),stat=io)','      if (io /= 0) return',
                  '      read(unit,iostat=io) staged%'+name,'      if (io /= 0) return']
    lines.append('      if (staged%i_n_model == 3) then')
    for name,size in MATCH_ARRAYS.items():
        lines += ['         allocate(staged%'+name+'(staged%'+size+'),stat=io)','         if (io /= 0) return',
                  '         read(unit,iostat=io) staged%'+name,'         if (io /= 0) return']
    lines += ['      end if','      if (.not.hybrid_tillage_valid(staged)) return',
        '      read(unit,iostat=io) trailer','      if (io /= iostat_end) return',
        '      s = staged','      ok = .true.','   end subroutine hybrid_tillage_read_post_event','']
    return lines


def source(original):
    if hashlib.sha256(original).hexdigest()!=ORIGINAL_SHA:
        raise ValueError('Foreign original tillage source; qualified B1 patches require a separate explicit contract')
    text=original.decode('cp1252');decl='   public :: DoTillage\r\n';body='   contains\r\n'
    if text.count(decl)!=1 or text.count(body)!=1:raise ValueError('Changed original tillage ownership seam')
    declaration=declarations().replace('\n','\r\n');routine=routines().replace('\n','\r\n')
    result=text.replace(decl,decl+declaration,1).replace(body,body+routine,1)
    if result.replace(decl+declaration,decl,1).replace(body+routine,body,1)!=text:
        raise ValueError('Incomplete literal original tillage inverse')
    return result.encode('cp1252')
