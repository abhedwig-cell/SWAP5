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

function basin_level(model)
    values = BMI.get_value_ptr(model, "basin.level")
    require(length(values) == 1, "Q1B requires exactly one Basin")
    return Float64(values[1])
end

function run_case(root::AbstractString, case)
    path = joinpath(root, case.id, "ribasim.toml")
    model = BMI.initialize(Ribasim.Model, path)
    try
        initial_level = basin_level(model)
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
        # Constant 1 m2 Basin profile: Delta storage [m3] equals Delta level [m].
        realized_supply = final_level - initial_level
        expected_storage_change = case.expected_supply
        mass_residual = (final_level - initial_level) - realized_supply

        require(
            abs(final_level - case.expected_final_level) <= LEVEL_TOL,
            "$(case.id) final level mismatch ribasim=$final_level expected=$(case.expected_final_level)",
        )
        require(
            abs(realized_supply - case.expected_supply) <= SUPPLY_TOL,
            "$(case.id) realized supply mismatch ribasim=$realized_supply expected=$(case.expected_supply)",
        )
        require(
            realized_supply <= case.max_supply + SUPPLY_TOL,
            "$(case.id) exceeded supply capacity: $realized_supply > $(case.max_supply)",
        )
        require(
            abs((final_level - initial_level) - expected_storage_change) <= SUPPLY_TOL,
            "$(case.id) storage change mismatch",
        )
        require(
            abs(mass_residual) <= MASS_TOL,
            "$(case.id) mass residual $mass_residual",
        )

        println("SW_RIB_SWM01_Q1B_CASE=$(case.id)")
        println("  INITIAL_LEVEL_M=$initial_level")
        println("  FINAL_LEVEL_M=$final_level")
        println("  REALIZED_SUPPLY_M3=$realized_supply")
        println("  MAX_SUPPLY_M3=$(case.max_supply)")
        println("  EXPECTED_SUPPLY_M3=$(case.expected_supply)")
        println("  MASS_RESIDUAL_M3=$mass_residual")
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
