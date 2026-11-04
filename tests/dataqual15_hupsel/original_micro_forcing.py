"""Read-only complete original microscopic root inputs on accepted day584 leaves."""
import original_oxygen_forcing as owner

owner.USE+='''use mod_RWU_micro,only:ch_m=>M_table,ch_k=>K_table,ch_pp=>PP,ch_pl=>PL, &
 ch_rr=>RootRadius,ch_kr=>Kroot,ch_a0=>Lstem_A0,ch_a1=>Lstem_A1,ch_half=>PLhalf,ch_camp=>CampA, &
 ch_tol=>Tol_2,ch_newton=>myTolX,ch_conv=>TolConv,ch_ntrial=>Ntrial,ch_oxygen=>swO2ECT,ch_reduction=>swTypeTred
use variables,only:ch_ksat=>ksatfit
use MOD_re_global,only:ch_combined=>alptot,ch_salt=>alpsol
'''
owner.DECL+='integer,save::ch_micro=0,ch_tables=0\ninteger::ch_j\n'
owner.BLOCK+='''      if(chrono_day==584)then
         if(ch_micro==0)then
            open(newunit=ch_micro,file='original_micro_inputs.dat',status='replace')
            open(newunit=ch_tables,file='original_micro_tables.dat',status='replace')
            do ch_i=1,34
               ch_lay=ch_layer(ch_i)
               do ch_j=1,430
                  write(ch_tables,'(*(es25.17e3,1x))')real(ch_i,8),real(ch_j,8), &
                   ch_m(ch_j,ch_lay),ch_k(ch_j,ch_lay),ch_ksat(ch_lay)
               end do
            end do
         end if
         do ch_i=1,34
            write(ch_micro,'(*(es25.17e3,1x))')583d0+chrono_clock,dt,real(ch_i,8), &
             real(chrono_nodes,8),chrono_ptra,ch_rr,ch_kr,ch_a0,ch_a1,1d0/ch_half,ch_camp, &
             ch_tol,ch_newton,ch_conv,real(ch_ntrial,8),real(ch_oxygen,8),real(ch_reduction,8), &
             chrono_start_h(ch_i),ch_dz(ch_i),chrono_lrv(ch_i),ch_combined(ch_i), &
             chrono_qrot(ch_i),ch_pp,ch_pl
         end do
      end if
'''

if __name__=='__main__':owner.main()
