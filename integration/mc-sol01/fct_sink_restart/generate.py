"""Compose admitted sink fixture and existing production restart bridge."""
import runpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
OLD=HERE.parent/'fct_pulse_restart'
def sources():
 g=runpy.run_path(str(HERE.parent/'fct_sinks/generate.py'));parts=g['sources']();replace=g['replace']
 prefix=parts.pop('joint_driver.f90').decode().split(' do i=1,4\n')[0]
 prefix=replace(prefix,' call get_command_argument(4,arg);read(arg,*)uptake',' call get_command_argument(8,arg);read(arg,*)uptake')
 prefix=replace(prefix,' use iso_fortran_env',' use mod_research_restart_bridge\n use iso_fortran_env')
 decl=' type(kernel_committed_state_t)::loaded_water\n type(research_chemical_t)::loaded_chem\n character(1024)::mode,input_path,output_path\n integer::stop_window\n'
 prefix=replace(prefix,' call get_command_argument(1,arg)',decl+' call get_command_argument(1,arg)')
 prefix=replace(prefix,' column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE',' column%state_handle=1;column%parameter_ref=1;column%forcing_handle=1\n column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE')
 body=(OLD/'disk_body.inc').read_text().replace('5(ES25.16E3','7(ES25.16E3')
 parts['disk_driver.f90']=(prefix+body).encode()
 parts['restart_bridge.f90']=(OLD/'mod_research_restart_bridge.f90').read_text().replace('mod_research_joint_reactive_fct','mod_research_joint_sink_fct').encode()
 return parts
