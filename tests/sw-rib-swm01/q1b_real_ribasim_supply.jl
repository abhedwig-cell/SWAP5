using Ribasim
import BasicModelInterface as BMI

const DAY = 86400.0
const LEVEL_TOL = 1.0e-6
const SUPPLY_TOL = 1.0e-6
const MASS_TOL = 1.0e-8
const INITIAL_TOL = 1.0e-10

const CASES = [
    (
        id = "B1_ALREADY_ABOVE_SUPPLY_TARGET",
        initial_level = -0.1,
        max_supply = 0.3,
        expected_supply = 0.0,
        expected_final_level = -0.1,
    ),
    (
        id = "B2_CAPACITY_SUFFICIENT",
        initial_level = -0.4,
        max_supply = 0.3,
        expected_supply = 0.2,
        expected_final_level = -0.2,
    ),
    (
        id = "B3_CAPACITY_LIMITED",
        initial_level = -0.4,
        max_supply = 0.1,
        expected_supply = 0.1,
        expected_final_level = -0.3,
    ),
]

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function only_value(values, label)
    require(length(values) == 1, "Q1B requires exactly one $label")
    return Float64(values[1])
end

basin_level(model) = only_value(BMI.get_value_ptr(model, "basin.level"), "Basin level")
basin_storage(model) = only_value(BMI.get_value_ptr(model, "basin.storage"), "Basin storage")
pump_cumulative(model) = only_value(model.integrator.u.pump, "Pump cumulative-flow state")

function run_case(root::AbstractString, case)
    path = joinpath(root, case.id, "ribasim.toml")
    model = BMI.initialize(Ribasim.Model, path)
    try
        initial_level = basin_level(model)
        initial_storage = basin_storage(model)
        initial_pump = pump_cumulative(model)

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
        direct_supply = pump_cumulative(model) - initial_pump
        storage_change = final_storage - initial_storage
        direct_mass_residual = storage_change - direct_supply

        require(
            abs(final_level - case.expected_final_level) <= LEVEL_TOL,
            "$(case.id) final level mismatch ribasim=$final_level expected=$(case.expected_final_level)",
        )
        require(
            abs(direct_supply - case.expected_supply) <= SUPPLY_TOL,
            "$(case.id) direct supply mismatch ribasim=$direct_supply expected=$(case.expected_supply)",
        )
        require(
            direct_supply <= case.max_supply + SUPPLY_TOL,
            "$(case.id) exceeded supply capacity: $direct_supply > $(case.max_supply)",
        )
        require(
            abs(storage_change - case.expected_supply) <= SUPPLY_TOL,
            "$(case.id) storage change mismatch $storage_change",
        )
        require(
            abs(direct_mass_residual) <= MASS_TOL,
            "$(case.id) direct mass residual $direct_mass_residual",
        )

        println("SW_RIB_SWM01_Q1B_CASE=$(case.id)")
        println("  INITIAL_LEVEL_M=$initial_level")
        println("  FINAL_LEVEL_M=$final_level")
        println("  STORAGE_CHANGE_M3=$storage_change")
        println("  DIRECT_PUMP_SUPPLY_M3=$direct_supply")
        println("  MAX_SUPPLY_M3=$(case.max_supply)")
        println("  EXPECTED_SUPPLY_M3=$(case.expected_supply)")
        println("  DIRECT_MASS_RESIDUAL_M3=$direct_mass_residual")
        println("SW_RIB_SWM01_Q1B_CASE_PASS=$(case.id)")
    finally
        BMI.finalize(model)
    end
end

function main()
    length(ARGS) == 1 || error("usage: q1b_real_ribasim_supply.jl <model-root>")
    root = abspath(ARGS[1])
    for case in CASES
        run_case(root, case)
    end
    println("SW_RIB_SWM01_Q1B_REAL_RIBASIM_SUPPLY=PASS")
end

main()
