using Ribasim
using JuMP
import BasicModelInterface as BMI

const DAY = 86400.0
const ACCEPTED_LEVEL = 1.000007990372381
const STORAGE_EXCESS = 7.990372381083688
const RIVER_FORCING = 8.000042512171305
const ROOT_MEMORY = 39.99037238108369
const ROOT_ALPHA_ONE = 31.990329868912383

const ALLOC_TOL = 0.05
const FACTOR_TOL = 1.0e-6
const STORAGE_TOL = 0.05
const FORCING_TOL = 0.01

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function inspect_case(
        path::AbstractString,
        label::AbstractString;
        infiltration_m3_day::Float64,
        fix_alpha_one::Bool,
    )
    model = BMI.initialize(Ribasim.Model, path)
    (; p_independent) = model.integrator.p
    allocation = p_independent.allocation
    require(length(allocation.allocation_models) == 1, "expected one allocation model")
    am = only(allocation.allocation_models)

    basin_id = Ribasim.NodeID(:Basin, 2, p_independent)
    root_id = Ribasim.NodeID(:UserDemand, 3, p_independent)
    external_id = Ribasim.NodeID(:UserDemand, 4, p_independent)

    level = BMI.get_value_ptr(model, "basin.level")
    require(length(level) == 1, "expected one Basin level")
    require(isapprox(level[1], ACCEPTED_LEVEL; atol=5.0e-12, rtol=0.0), "$label accepted initial level mismatch")

    infiltration = BMI.get_value_ptr(model, "basin.infiltration")
    require(length(infiltration) == 1, "expected one Basin infiltration value")
    infiltration[1] = infiltration_m3_day / DAY

    alpha_var = am.problem[:low_storage_factor][basin_id]
    if fix_alpha_one
        JuMP.fix(alpha_var, 1.0; force=true)
    end

    Ribasim.update_allocation!(model)

    alpha = JuMP.value(alpha_var)
    storage_change = JuMP.value(am.problem[:basin_storage_change][basin_id]) * am.scaling.storage
    root_alloc = JuMP.value(am.problem[:user_demand_allocated][root_id, Int32(2)]) * am.scaling.flow * DAY
    external_alloc = JuMP.value(am.problem[:user_demand_allocated][external_id, Int32(3)]) * am.scaling.flow * DAY
    implicit_negative = am.implicit_negative_forcing_volume[basin_id]

    println(
        "RIBASIM_REAL_20H6_LP label=$label " *
        "infiltration_m3_day=$infiltration_m3_day " *
        "implicit_negative_forcing_m3=$implicit_negative " *
        "low_storage_factor=$alpha storage_change_m3=$storage_change " *
        "root_alloc_m3_day=$root_alloc external_alloc_m3_day=$external_alloc"
    )

    BMI.finalize(model)
    return (
        alpha=alpha,
        storage_change=storage_change,
        root=root_alloc,
        external=external_alloc,
        implicit_negative=implicit_negative,
    )
end

function main()
    length(ARGS) == 1 || error("usage: real_ribasim_20h6_next_boundary_memory.jl <ribasim.toml>")
    path = abspath(ARGS[1])
    require(isfile(path), "Ribasim input missing")

    control = inspect_case(
        path,
        "elevated_control_no_river";
        infiltration_m3_day=0.0,
        fix_alpha_one=false,
    )
    require(abs(control.implicit_negative) <= FORCING_TOL, "control implicit forcing is nonzero")
    require(isapprox(control.alpha, 1.0; atol=FACTOR_TOL, rtol=0.0), "control alpha is not 1")
    require(isapprox(control.storage_change, -STORAGE_EXCESS; atol=STORAGE_TOL, rtol=0.0), "control accepted storage memory not released")
    require(isapprox(control.root, ROOT_MEMORY; atol=ALLOC_TOL, rtol=0.0), "control root allocation differs from memory reference")
    require(isapprox(control.external, 0.0; atol=ALLOC_TOL, rtol=0.0), "control external allocation is nonzero")

    free = inspect_case(
        path,
        "elevated_with_river_free_alpha";
        infiltration_m3_day=RIVER_FORCING,
        fix_alpha_one=false,
    )
    require(isapprox(free.implicit_negative, RIVER_FORCING; atol=FORCING_TOL, rtol=0.0), "River forcing did not reach allocation LP")
    require(isapprox(free.alpha, 0.0; atol=FACTOR_TOL, rtol=0.0), "free-alpha River factor did not collapse to 0")
    require(isapprox(free.storage_change, -STORAGE_EXCESS; atol=STORAGE_TOL, rtol=0.0), "accepted storage memory changed under free-alpha forcing")
    require(isapprox(free.root, ROOT_MEMORY; atol=ALLOC_TOL, rtol=0.0), "free-alpha root allocation lost accepted storage memory")
    require(isapprox(free.external, 0.0; atol=ALLOC_TOL, rtol=0.0), "free-alpha external allocation is nonzero")

    fixed = inspect_case(
        path,
        "elevated_with_river_alpha_fixed_one";
        infiltration_m3_day=RIVER_FORCING,
        fix_alpha_one=true,
    )
    require(isapprox(fixed.implicit_negative, RIVER_FORCING; atol=FORCING_TOL, rtol=0.0), "fixed-alpha River forcing did not reach LP")
    require(isapprox(fixed.alpha, 1.0; atol=FACTOR_TOL, rtol=0.0), "fixed-alpha factor is not 1")
    require(isapprox(fixed.storage_change, -STORAGE_EXCESS; atol=STORAGE_TOL, rtol=0.0), "fixed-alpha accepted storage memory changed")
    require(isapprox(fixed.root, ROOT_ALPHA_ONE; atol=ALLOC_TOL, rtol=0.0), "fixed-alpha root allocation differs from memory minus River forcing")
    require(isapprox(fixed.external, 0.0; atol=ALLOC_TOL, rtol=0.0), "fixed-alpha external allocation is nonzero")

    require(isapprox(free.root, control.root; atol=ALLOC_TOL, rtol=0.0), "current River forcing changed allocation despite free alpha")
    require(free.root - fixed.root > 7.9, "alpha intervention did not expose nearly full current River forcing")

    println(
        "RIBASIM_REAL_20H6_NEXT_BOUNDARY_MEMORY_FORECAST_SEPARATION=PASS " *
        "control_root=$(control.root) free_root=$(free.root) fixed_root=$(fixed.root) " *
        "free_alpha=$(free.alpha) storage_change_m3=$(free.storage_change)"
    )
end

main()
