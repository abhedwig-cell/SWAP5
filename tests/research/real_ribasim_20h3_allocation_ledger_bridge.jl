using Ribasim
using JuMP
import BasicModelInterface as BMI

const DAY = 86400.0
const INJECTION_M3_DAY = 7.999914667576883
const ALLOC_TOL = 0.05
const FORCE_TOL = 0.01
const STORAGE_TOL = 0.05
const ERROR_TOL = 0.05
const ALPHA_TOL = 1.0e-6

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function node_id(model, type::Symbol, id::Int)
    return Ribasim.NodeID(type, id, model.integrator.p.p_independent)
end

function allocation_model(model)
    models = model.integrator.p.p_independent.allocation.allocation_models
    require(length(models) == 1, "expected exactly one allocation model")
    return only(models)
end

function inspect_case(path::AbstractString, label::AbstractString; infiltration_m3_day::Float64, fix_alpha_one::Bool=false)
    model = BMI.initialize(Ribasim.Model, path)
    try
        infiltration = BMI.get_value_ptr(model, "basin.infiltration")
        require(length(infiltration) == 1, "$label expected one Basin infiltration value")
        infiltration[1] = infiltration_m3_day / DAY
        require(isapprox(infiltration[1] * DAY, infiltration_m3_day; atol=1.0e-10, rtol=0.0), "$label infiltration pointer write failed")

        am = allocation_model(model)
        problem = am.problem
        basin_id = node_id(model, :Basin, 2)
        root_id = node_id(model, :UserDemand, 3)
        external_id = node_id(model, :UserDemand, 4)

        alpha_var = problem[:low_storage_factor][basin_id]
        if fix_alpha_one
            JuMP.fix(alpha_var, 1.0; force=true)
        end

        Ribasim.update_allocation!(model)

        implicit_volume = am.implicit_negative_forcing_volume[basin_id]
        alpha = JuMP.value(alpha_var)
        storage_change = JuMP.value(problem[:basin_storage_change][basin_id]) * am.scaling.storage
        root_alloc = JuMP.value(problem[:user_demand_allocated][root_id, Int32(2)]) * am.scaling.flow * DAY
        ext_alloc = JuMP.value(problem[:user_demand_allocated][external_id, Int32(3)]) * am.scaling.flow * DAY

        level_errors = problem[:level_demand_error]
        lower_error = JuMP.value(level_errors[basin_id, Int32(1), :lower, :first]) * am.scaling.storage
        upper_error = JuMP.value(level_errors[basin_id, Int32(1), :upper, :first]) * am.scaling.storage
        level_error = lower_error + upper_error

        println(
            "RIBASIM_REAL_20H3_LP label=$label infiltration_m3_day=$infiltration_m3_day " *
            "implicit_negative_volume_m3=$implicit_volume low_storage_factor=$alpha " *
            "storage_change_m3=$storage_change level_error_m3=$level_error " *
            "root_alloc_m3_day=$root_alloc external_alloc_m3_day=$ext_alloc"
        )

        return (
            implicit_volume=implicit_volume,
            alpha=alpha,
            storage_change=storage_change,
            level_error=level_error,
            root_alloc=root_alloc,
            ext_alloc=ext_alloc,
        )
    finally
        BMI.finalize(model)
    end
end

function main()
    length(ARGS) == 1 || error("usage: real_ribasim_20h3_allocation_ledger_bridge.jl <ribasim-root>")
    root = abspath(ARGS[1])
    path = joinpath(root, "generated_testmodels", "swap5_bmi_clock_root_first", "ribasim.toml")
    require(isfile(path), "root-first model was not generated")

    control = inspect_case(path, "control"; infiltration_m3_day=0.0)
    injected = inspect_case(path, "injected_free"; infiltration_m3_day=INJECTION_M3_DAY)
    fixed = inspect_case(path, "injected_fixed_one"; infiltration_m3_day=INJECTION_M3_DAY, fix_alpha_one=true)

    require(isapprox(control.implicit_volume, 0.0; atol=FORCE_TOL, rtol=0.0), "control implicit forcing is nonzero")
    require(isapprox(control.root_alloc, 32.0; atol=ALLOC_TOL, rtol=0.0), "control root allocation differs")
    require(isapprox(control.ext_alloc, 0.0; atol=ALLOC_TOL, rtol=0.0), "control external allocation differs")
    require(isapprox(control.alpha, 1.0; atol=ALPHA_TOL, rtol=0.0), "control low_storage_factor is not one")
    require(isapprox(control.storage_change, 0.0; atol=STORAGE_TOL, rtol=0.0), "control storage change differs")
    require(isapprox(control.level_error, 0.0; atol=ERROR_TOL, rtol=0.0), "control LevelDemand error differs")

    require(isapprox(injected.implicit_volume, INJECTION_M3_DAY; atol=FORCE_TOL, rtol=0.0), "injected LP did not receive frozen negative forcing")
    require(isapprox(injected.root_alloc, 32.0; atol=ALLOC_TOL, rtol=0.0), "free-alpha injected root allocation differs")
    require(isapprox(injected.ext_alloc, 0.0; atol=ALLOC_TOL, rtol=0.0), "free-alpha injected external allocation differs")
    require(isapprox(injected.alpha, 0.0; atol=ALPHA_TOL, rtol=0.0), "free-alpha injected low_storage_factor is not zero")
    require(isapprox(injected.storage_change, 0.0; atol=STORAGE_TOL, rtol=0.0), "free-alpha injected storage change differs")
    require(isapprox(injected.level_error, 0.0; atol=ERROR_TOL, rtol=0.0), "free-alpha injected LevelDemand error differs")

    require(isapprox(fixed.implicit_volume, INJECTION_M3_DAY; atol=FORCE_TOL, rtol=0.0), "fixed-alpha LP did not receive frozen negative forcing")
    require(isapprox(fixed.root_alloc, 32.0 - INJECTION_M3_DAY; atol=ALLOC_TOL, rtol=0.0), "fixed-alpha root allocation does not expose infiltration cost")
    require(isapprox(fixed.ext_alloc, 0.0; atol=ALLOC_TOL, rtol=0.0), "fixed-alpha external allocation differs")
    require(isapprox(fixed.alpha, 1.0; atol=ALPHA_TOL, rtol=0.0), "fixed-alpha factor is not one")
    require(isapprox(fixed.storage_change, 0.0; atol=STORAGE_TOL, rtol=0.0), "fixed-alpha storage change differs")
    require(isapprox(fixed.level_error, 0.0; atol=ERROR_TOL, rtol=0.0), "fixed-alpha LevelDemand error differs")

    println("RIBASIM_REAL_20H3_LOW_STORAGE_FACTOR_FORECAST_MECHANISM=PASS")
end

main()
