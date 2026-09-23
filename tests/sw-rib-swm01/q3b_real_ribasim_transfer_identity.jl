using Ribasim
import BasicModelInterface as BMI

const DAY = 86400.0
const TRANSFER_TOL = 1.0e-6
const LEVEL_TOL = 1.0e-6
const MASS_TOL = 1.0e-8
const STORAGE_TOL = 1.0e-10
const STRICT_DIFFERENCE = 1.0e-6

const CASES = [
    (id="T1_INCOMING_SPLIT", initial=-0.5, drainage=0.005, runoff=0.004, infiltration=0.0, top=0.0, final=-0.491, limited=false),
    (id="T2_OUTGOING_SPLIT", initial=-0.5, drainage=0.0, runoff=0.0, infiltration=0.004, top=0.003, final=-0.507, limited=false),
    (id="T3_MIXED_IDENTITIES", initial=-0.5, drainage=0.005, runoff=0.002, infiltration=0.003, top=0.001, final=-0.497, limited=false),
    (id="T4_TOP_INUNDATION_AVAILABILITY_LIMITED", initial=-0.998, drainage=0.0, runoff=0.0, infiltration=0.0, top=0.0051, final=NaN, limited=true),
]

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function only_value(values, label)
    require(length(values) == 1, "Q3B requires exactly one $label")
    return Float64(values[1])
end

value(model, name) = only_value(BMI.get_value_ptr(model, name), name)

function pump_cumulative(model)
    values = model.integrator.u.pump
    require(length(values) == 1, "Q3B requires exactly one Pump cumulative-flow state")
    return Float64(values[1])
end

function run_case(root::AbstractString, case)
    model = BMI.initialize(Ribasim.Model, joinpath(root, case.id, "ribasim.toml"))
    try
        initial_level = value(model, "basin.level")
        initial_storage = value(model, "basin.storage")
        d0 = value(model, "basin.cumulative_drainage")
        r0 = value(model, "basin.cumulative_surface_runoff")
        i0 = value(model, "basin.cumulative_infiltration")
        p0 = pump_cumulative(model)

        require(abs(initial_level - case.initial) <= 1.0e-10, "$(case.id) initial level drift")

        BMI.update_until(model, DAY)
        require(isapprox(BMI.get_current_time(model), DAY; atol=1.0e-8, rtol=0.0), "$(case.id) endpoint mismatch")

        final_level = value(model, "basin.level")
        final_storage = value(model, "basin.storage")
        drainage = value(model, "basin.cumulative_drainage") - d0
        runoff = value(model, "basin.cumulative_surface_runoff") - r0
        infiltration = value(model, "basin.cumulative_infiltration") - i0
        top = pump_cumulative(model) - p0
        storage_change = final_storage - initial_storage
        residual = storage_change - drainage - runoff + infiltration + top

        require(abs(drainage - case.drainage) <= TRANSFER_TOL, "$(case.id) drainage aggregate mismatch $drainage")
        require(abs(runoff - case.runoff) <= TRANSFER_TOL, "$(case.id) runoff mismatch $runoff")
        require(abs(infiltration - case.infiltration) <= TRANSFER_TOL, "$(case.id) lower infiltration mismatch $infiltration")
        require(abs(residual) <= MASS_TOL, "$(case.id) mass residual $residual")

        disposition = "TRANSFER_IDENTITIES_REALIZED"
        if case.limited
            require(top >= -STORAGE_TOL, "$(case.id) negative top transfer")
            require(top < case.top - STRICT_DIFFERENCE, "$(case.id) top availability limiter did not reduce request: $top")
            require(top <= initial_storage + STORAGE_TOL, "$(case.id) top transfer exceeds starting storage")
            require(final_storage >= -STORAGE_TOL, "$(case.id) negative final storage")
            disposition = "RECOMPOSITION_REQUIRED"
        else
            require(abs(top - case.top) <= TRANSFER_TOL, "$(case.id) top transfer mismatch $top")
            require(abs(final_level - case.final) <= LEVEL_TOL, "$(case.id) final level mismatch $final_level")
        end

        println("SW_RIB_SWM01_Q3B_CASE=$(case.id)")
        println("  REALIZED_DRAINAGE_AGGREGATE_M3=$drainage")
        println("  REALIZED_SURFACE_RUNOFF_M3=$runoff")
        println("  REALIZED_LOWER_INFILTRATION_M3=$infiltration")
        println("  REALIZED_TOP_INUNDATION_M3=$top")
        println("  FINAL_LEVEL_M=$final_level")
        println("  FINAL_STORAGE_M3=$final_storage")
        println("  DIRECT_MASS_RESIDUAL_M3=$residual")
        println("  COUPLING_DISPOSITION=$disposition")
        println("SW_RIB_SWM01_Q3B_CASE_PASS=$(case.id)")
    finally
        BMI.finalize(model)
    end
end

function main()
    length(ARGS) == 1 || error("usage: q3b_real_ribasim_transfer_identity.jl <model-root>")
    root = abspath(ARGS[1])
    for case in CASES
        run_case(root, case)
    end
    println("SW_RIB_SWM01_Q3B_REAL_RIBASIM_TRANSFER_IDENTITIES=PASS")
end

main()
