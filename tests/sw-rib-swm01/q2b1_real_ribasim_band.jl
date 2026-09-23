using Ribasim
import BasicModelInterface as BMI

const DAY = 86400.0
const LEVEL_TOL = 1.0e-6
const FLOW_TOL = 1.0e-6
const MASS_TOL = 1.0e-8
const INITIAL_TOL = 1.0e-10

const CASES = [
    (
        id = "M1_BELOW_BAND_ADEQUATE",
        initial_level = -0.4,
        max_supply = 0.2,
        max_discharge = 0.2,
        expected_supply = 0.1,
        expected_discharge = 0.0,
        expected_final_level = -0.3,
    ),
    (
        id = "M2_BELOW_BAND_LIMITED",
        initial_level = -0.4,
        max_supply = 0.05,
        max_discharge = 0.2,
        expected_supply = 0.05,
        expected_discharge = 0.0,
        expected_final_level = -0.35,
    ),
    (
        id = "M3_INSIDE_BAND",
        initial_level = -0.25,
        max_supply = 0.2,
        max_discharge = 0.2,
        expected_supply = 0.0,
        expected_discharge = 0.0,
        expected_final_level = -0.25,
    ),
    (
        id = "M4_ABOVE_BAND_ADEQUATE",
        initial_level = -0.1,
        max_supply = 0.2,
        max_discharge = 0.2,
        expected_supply = 0.0,
        expected_discharge = 0.1,
        expected_final_level = -0.2,
    ),
    (
        id = "M5_ABOVE_BAND_LIMITED",
        initial_level = -0.1,
        max_supply = 0.2,
        max_discharge = 0.05,
        expected_supply = 0.0,
        expected_discharge = 0.05,
        expected_final_level = -0.15,
    ),
]

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function only_value(values, label)
    require(length(values) == 1, "Q2B1 requires exactly one $label")
    return Float64(values[1])
end

basin_level(model) = only_value(BMI.get_value_ptr(model, "basin.level"), "Basin level")
basin_storage(model) = only_value(BMI.get_value_ptr(model, "basin.storage"), "Basin storage")

function pump_cumulative_pair(model)
    values = model.integrator.u.pump
    require(length(values) == 2, "Q2B1 requires exactly two Pump cumulative-flow states")
    # Pump static rows are sorted by node_id in the pinned Ribasim release.
    # Node 2 is supply and node 4 is discharge.
    return Float64(values[1]), Float64(values[2])
end

function run_case(root::AbstractString, case)
    path = joinpath(root, case.id, "ribasim.toml")
    model = BMI.initialize(Ribasim.Model, path)
    try
        initial_level = basin_level(model)
        initial_storage = basin_storage(model)
        initial_supply, initial_discharge = pump_cumulative_pair(model)

        require(
            isapprox(initial_level, case.initial_level; atol=INITIAL_TOL, rtol=0.0),
            "$(case.id) initial level drift: $initial_level",
        )

        BMI.update_until(model, DAY)
        require(
            isapprox(BMI.get_current_time(model), DAY; atol=1.0e-8, rtol=0.0),
            "$(case.id) endpoint mismatch",
        )

        final_level = basin_level(model)
        final_storage = basin_storage(model)
        final_supply, final_discharge = pump_cumulative_pair(model)
        direct_supply = final_supply - initial_supply
        direct_discharge = final_discharge - initial_discharge
        storage_change = final_storage - initial_storage
        mass_residual = storage_change - direct_supply + direct_discharge

        require(
            abs(final_level - case.expected_final_level) <= LEVEL_TOL,
            "$(case.id) level mismatch ribasim=$final_level expected=$(case.expected_final_level)",
        )
        require(
            abs(direct_supply - case.expected_supply) <= FLOW_TOL,
            "$(case.id) supply mismatch $direct_supply expected=$(case.expected_supply)",
        )
        require(
            abs(direct_discharge - case.expected_discharge) <= FLOW_TOL,
            "$(case.id) discharge mismatch $direct_discharge expected=$(case.expected_discharge)",
        )
        require(direct_supply <= case.max_supply + FLOW_TOL, "$(case.id) supply capacity exceeded")
        require(direct_discharge <= case.max_discharge + FLOW_TOL, "$(case.id) discharge capacity exceeded")
        require(
            !(direct_supply > FLOW_TOL && direct_discharge > FLOW_TOL),
            "$(case.id) simultaneous management supply and discharge",
        )
        require(abs(mass_residual) <= MASS_TOL, "$(case.id) mass residual $mass_residual")

        println("SW_RIB_SWM01_Q2B1_CASE=$(case.id)")
        println("  INITIAL_LEVEL_M=$initial_level")
        println("  FINAL_LEVEL_M=$final_level")
        println("  DIRECT_SUPPLY_M3=$direct_supply")
        println("  DIRECT_DISCHARGE_M3=$direct_discharge")
        println("  STORAGE_CHANGE_M3=$storage_change")
        println("  DIRECT_MASS_RESIDUAL_M3=$mass_residual")
        println("SW_RIB_SWM01_Q2B1_CASE_PASS=$(case.id)")
    finally
        BMI.finalize(model)
    end
end

function main()
    length(ARGS) == 1 || error("usage: q2b1_real_ribasim_band.jl <model-root>")
    root = abspath(ARGS[1])
    for case in CASES
        run_case(root, case)
    end
    println("SW_RIB_SWM01_Q2B1_REAL_RIBASIM_BAND=PASS")
end

main()
