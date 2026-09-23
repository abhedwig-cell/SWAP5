using Ribasim
import BasicModelInterface as BMI

const DAY = 86400.0
const RATE_TOL = 1.0e-12
const TRANSFER_TOL = 1.0e-6
const LEVEL_TOL = 1.0e-6
const MASS_TOL = 1.0e-8
const STORAGE_TOL = 1.0e-10
const STRICT_DIFFERENCE = 1.0e-6
const RDRAIN_DAY = 10.0
const RINFI_DAY = 20.0

const CASES = [
    (
        id = "X1_POSITIVE_DRAINAGE",
        initial_level = -0.5,
        gwl_cm = -40.0,
        expected_q_cm_day = 1.0,
        requested_m3 = 0.01,
        expected_final_level = -0.49,
        kind = :drainage,
    ),
    (
        id = "X2_NEGATIVE_INFILTRATION_SUFFICIENT",
        initial_level = -0.5,
        gwl_cm = -60.0,
        expected_q_cm_day = -0.5,
        requested_m3 = 0.005,
        expected_final_level = -0.505,
        kind = :infiltration,
    ),
    (
        id = "X3_NEGATIVE_INFILTRATION_AVAILABILITY_LIMITED",
        initial_level = -0.998,
        gwl_cm = -110.0,
        expected_q_cm_day = -0.51,
        requested_m3 = 0.0051,
        expected_final_level = NaN,
        kind = :limited_infiltration,
    ),
]

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function only_value(values, label)
    require(length(values) == 1, "Q3A requires exactly one $label")
    return Float64(values[1])
end

value(model, name) = only_value(BMI.get_value_ptr(model, name), name)

function swap_q_cm_day(level_m::Float64, gwl_cm::Float64)
    wl_cm = 100.0 * level_m
    effective = gwl_cm - wl_cm
    return effective > 0.0 ? effective / RDRAIN_DAY : effective / RINFI_DAY
end

function run_case(root::AbstractString, case)
    path = joinpath(root, case.id, "ribasim.toml")
    model = BMI.initialize(Ribasim.Model, path)
    try
        initial_level = value(model, "basin.level")
        initial_storage = value(model, "basin.storage")
        initial_drainage = value(model, "basin.cumulative_drainage")
        initial_infiltration = value(model, "basin.cumulative_infiltration")

        q_swap = swap_q_cm_day(initial_level, case.gwl_cm)
        require(abs(q_swap - case.expected_q_cm_day) <= RATE_TOL,
            "$(case.id) source-derived exchange drift: $q_swap")

        BMI.update_until(model, DAY)
        require(isapprox(BMI.get_current_time(model), DAY; atol=1.0e-8, rtol=0.0),
            "$(case.id) endpoint mismatch")

        final_level = value(model, "basin.level")
        final_storage = value(model, "basin.storage")
        direct_drainage =
            value(model, "basin.cumulative_drainage") - initial_drainage
        direct_infiltration =
            value(model, "basin.cumulative_infiltration") - initial_infiltration
        storage_change = final_storage - initial_storage
        mass_residual = storage_change - direct_drainage + direct_infiltration

        if case.kind == :drainage
            require(abs(direct_drainage - case.requested_m3) <= TRANSFER_TOL,
                "$(case.id) drainage mismatch $direct_drainage")
            require(abs(direct_infiltration) <= TRANSFER_TOL,
                "$(case.id) unexpected infiltration $direct_infiltration")
            require(abs(final_level - case.expected_final_level) <= LEVEL_TOL,
                "$(case.id) final level mismatch $final_level")
            disposition = "TRANSFER_MATCHES_REQUEST"
        elseif case.kind == :infiltration
            require(abs(direct_infiltration - case.requested_m3) <= TRANSFER_TOL,
                "$(case.id) infiltration mismatch $direct_infiltration")
            require(abs(direct_drainage) <= TRANSFER_TOL,
                "$(case.id) unexpected drainage $direct_drainage")
            require(abs(final_level - case.expected_final_level) <= LEVEL_TOL,
                "$(case.id) final level mismatch $final_level")
            disposition = "TRANSFER_MATCHES_REQUEST"
        else
            require(abs(direct_drainage) <= TRANSFER_TOL,
                "$(case.id) unexpected drainage $direct_drainage")
            require(direct_infiltration >= -STORAGE_TOL,
                "$(case.id) negative realized infiltration $direct_infiltration")
            require(direct_infiltration < case.requested_m3 - STRICT_DIFFERENCE,
                "$(case.id) availability limiter did not reduce request: $direct_infiltration")
            require(direct_infiltration <= initial_storage + STORAGE_TOL,
                "$(case.id) withdrew more than accepted starting storage")
            require(final_storage >= -STORAGE_TOL,
                "$(case.id) final storage became negative: $final_storage")
            disposition = "RECOMPOSITION_REQUIRED"
        end

        require(abs(mass_residual) <= MASS_TOL,
            "$(case.id) direct Ribasim mass residual $mass_residual")

        println("SW_RIB_SWM01_Q3A_CASE=$(case.id)")
        println("  Q_SWAP_REQUEST_CM_PER_DAY=$q_swap")
        println("  REQUESTED_TRANSFER_M3=$(case.requested_m3)")
        println("  REALIZED_DRAINAGE_M3=$direct_drainage")
        println("  REALIZED_INFILTRATION_M3=$direct_infiltration")
        println("  INITIAL_STORAGE_M3=$initial_storage")
        println("  FINAL_STORAGE_M3=$final_storage")
        println("  FINAL_LEVEL_M=$final_level")
        println("  DIRECT_MASS_RESIDUAL_M3=$mass_residual")
        println("  COUPLING_DISPOSITION=$disposition")
        println("SW_RIB_SWM01_Q3A_CASE_PASS=$(case.id)")
    finally
        BMI.finalize(model)
    end
end

function main()
    length(ARGS) == 1 || error("usage: q3a_real_ribasim_exchange.jl <model-root>")
    root = abspath(ARGS[1])
    for case in CASES
        run_case(root, case)
    end
    println("SW_RIB_SWM01_Q3A_SIGNED_EXCHANGE_AVAILABILITY=PASS")
end

main()
