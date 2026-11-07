"""Run a real, isolated MODFLOW corrector from the same groundwater origin."""

from pathlib import Path
import math


def solve_cell(directory, executable, initial_head, interface_m3):
    import flopy

    directory = Path(directory)
    duration = 0.5
    rate = interface_m3 / duration
    simulation = flopy.mf6.MFSimulation(sim_name="andelst_cell", exe_name=str(executable),
                                         sim_ws=str(directory))
    simulation.simulation_data.float_characters = 25
    simulation.simulation_data.float_precision = 17
    flopy.mf6.ModflowTdis(simulation, time_units="DAYS", nper=1, perioddata=[(duration, 1, 1.0)])
    flopy.mf6.ModflowIms(simulation, outer_dvclose=1e-12, inner_dvclose=1e-13,
                       rcloserecord=[1e-13, "STRICT"])
    cell = flopy.mf6.ModflowGwf(simulation, modelname="cell", save_flows=True)
    flopy.mf6.ModflowGwfdis(cell, nlay=1, nrow=1, ncol=1, delr=1.0, delc=1.0, top=0.0, botm=-1.0)
    flopy.mf6.ModflowGwfic(cell, strt=initial_head)
    flopy.mf6.ModflowGwfnpf(cell, icelltype=0, k=1.0)
    flopy.mf6.ModflowGwfsto(cell, iconvert=0, ss=0.15, transient={0: True}, save_flows=True)
    flopy.mf6.ModflowGwfwel(cell, stress_period_data={0: [((0, 0, 0), rate)]}, save_flows=True)
    flopy.mf6.ModflowGwfoc(cell, head_filerecord="cell.hds", budget_filerecord="cell.cbc",
                          saverecord=[("HEAD", "ALL"), ("BUDGET", "ALL")])
    simulation.write_simulation(silent=True)
    success, _ = simulation.run_simulation(silent=True, report=True)
    if not success:
        raise RuntimeError(f"MODFLOW 6 failed in {directory}")
    head = float(cell.output.head().get_data().item())
    budget = cell.output.budget()
    exchange = float(budget.get_data(text="WEL")[0]["q"].sum()) * duration
    storage = float(budget.get_data(text="STO-SS")[0].sum()) * duration
    if not math.isclose(head, initial_head + interface_m3/0.15, abs_tol=1e-10, rel_tol=0):
        raise RuntimeError("Native MODFLOW head disagrees with confined one-cell storage control")
    return head, exchange, storage
