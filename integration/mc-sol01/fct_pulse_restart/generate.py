"""Reuse the qualified numerical sources; extend only executable fixture I/O."""
import runpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
PREVIOUS=HERE.parent/'fct_reactive'
def sources():
    g=runpy.run_path(str(PREVIOUS/'generate.py'));parts=g['sources']()
    prefix=parts.pop('joint_driver.f90').decode().split(' do i=1,4\n')[0]
    prefix=prefix.replace(' use iso_fortran_env',' use mod_research_restart_bridge\n use iso_fortran_env',1)
    declarations=' type(kernel_committed_state_t)::loaded_water\n type(research_chemical_t)::loaded_chem\n character(1024)::mode,input_path,output_path\n integer::stop_window\n'
    prefix=prefix.replace(' call get_command_argument(1,arg)',declarations+' call get_command_argument(1,arg)',1)
    prefix=prefix.replace(' column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE',
        ' column%state_handle=1;column%parameter_ref=1;column%forcing_handle=1\n column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE',1)
    parts['disk_driver.f90']=(prefix+(HERE/'disk_body.inc').read_text()).encode()
    return parts
