using Ribasim
import BasicModelInterface as BMI

const DAY = 86400.0
const REQUEST = 0.0051
const TRANSFER_TOL = 1.0e-6
const MASS_TOL = 1.0e-8
const STORAGE_TOL = 1.0e-10
const STRICT_SHORTFALL = 1.0e-6

const CASES = [
    (id="C0_NO_POSITIVE_DRAINAGE", drainage=0.0),
    (id="C1_ONE_MM_POSITIVE_DRAINAGE", drainage=0.001),
    (id="C2_TEN_MM_POSITIVE_DRAINAGE", drainage=0.01),
]

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function only_value(values, label)
    require(length(values) == 1, "Q3C requires exactly one $label")
    return Float64(values[1])
end

value(model, name) = only_value(BMI.get_value_ptr(model, name), name)

function run_case(root::AbstractString, case)
    model = BMI.initialize(Ribasim.Model, joinpath(root, case.id, "ribasim.toml"))
    try
        initial_storage = value(model, "basin.storage")
        d0 = value(model, "basin.cumulative_drainage")
        i0 = value(model, "basin.cumulative_infiltration")

        BMI.update_until(model, DAY)
        require(isapprox(BMI.get_current_time(model), DAY; atol=1.0e-8, rtol=0.0),
            "$(case.id) endpoint mismatch")

        final_storage = value(model, "basin.storage")
        drainage = value(model, "basin.cumulative_drainage") - d0
        infiltration = value(model, "basin.cumulative_infiltration") - i0
        storage_change = final_storage - initial_storage
        residual = storage_change - drainage + infiltration

        require(abs(drainage - case.drainage) <= TRANSFER_TOL,
            "$(case.id) positive drainage was altered: $drainage")
        require(infiltration >= -STORAGE_TOL, "$(case.id) negative realized infiltration")
        require(infiltration < REQUEST - STRICT_SHORTFALL,
            "$(case.id) scarcity did not reduce infiltration request: $infiltration")
        require(final_storage >= -STORAGE_TOL, "$(case.id) negative final storage")
        require(abs(residual) <= MASS_TOL, "$(case.id) mass residual $residual")

        println("SW_RIB_SWM01_Q3C_CASE=$(case.id)")
        println("  POSITIVE_DRAINAGE_REQUEST_M3=$(case.drainage)")
        println("  REALIZED_POSITIVE_DRAINAGE_M3=$drainage")
        println("  NEGATIVE_INFILTRATION_REQUEST_M3=$REQUEST")
        println("  REALIZED_NEGATIVE_INFILTRATION_M3=$infiltration")
        println("  INITIAL_STORAGE_M3=$initial_storage")
        println("  FINAL_STORAGE_M3=$final_storage")
        println("  DIRECT_MASS_RESIDUAL_M3=$residual")
        println("  COUPLING_DISPOSITION=RECOMPOSITION_REQUIRED")
        println("SW_RIB_SWM01_Q3C_CASE_PASS=$(case.id)")
        return infiltration
    finally
        BMI.finalize(model)
    end
end

function main()
    length(ARGS) == 1 || error("usage: q3c_real_ribasim_mixed_scarcity.jl <model-root>")
    root = abspath(ARGS[1])
    realized = [run_case(root, case) for case in CASES]
    require(realized[2] > realized[1] + 1.0e-6,
        "C1 positive drainage did not materially increase feasible infiltration")
    require(realized[3] > realized[2] + 1.0e-5,
        "C2 positive drainage did not materially increase feasible infiltration")
    println("SW_RIB_SWM01_Q3C_POSITIVE_DRAINAGE_UNSCALED=PASS")
    println("SW_RIB_SWM01_Q3C_FEASIBLE_INFILTRATION_MONOTONIC=PASS")
    println("SW_RIB_SWM01_Q3C_MIXED_SIGN_SCARCITY=PASS")
end

main()
