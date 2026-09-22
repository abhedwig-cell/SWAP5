using Ribasim
using JuMP
import BasicModelInterface as BMI

const DAY = 86400.0
const AREA = 1_000_000.0
const SEGMENT = 21600.0
const ENDPOINTS = [21600.0, 43200.0, 64800.0, 86400.0]
const ALLOCATION_TOL = 0.05
const VOLUME_TOL = 0.05
const LEVEL_TOL = 5.0e-8

const ROOT_FIRST_NEXT = [
    (40.0, 7.995200961071983),
    (40.0, 15.979613076541273),
    (40.0, 19.962546470305938),
]
const EXTERNAL_FIRST_NEXT = [
    (27.995200960183805, 20.0),
    (35.979613075653106, 20.0),
    (39.96254646941776, 20.0),
]

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function priority_index(priorities, priority::Int)
    idx = findfirst(==(Int32(priority)), priorities)
    isnothing(idx) && error("demand priority $priority not present")
    return idx
end

function allocation_model(model)
    models = model.integrator.p.p_independent.allocation.allocation_models
    require(length(models) == 1, "expected one allocation model")
    return only(models)
end

function user_id(model, node_id::Int)
    return Ribasim.NodeID(:UserDemand, node_id, model.integrator.p.p_independent)
end

function shadow_allocated(model, node_id::Int, priority::Int)::Float64
    am = allocation_model(model)
    id = user_id(model, node_id)
    return JuMP.value(am.problem[:user_demand_allocated][id, Int32(priority)]) * am.scaling.flow
end

function applied_allocated(model, node_id::Int, priority::Int)::Float64
    (; user_demand, allocation) = model.integrator.p.p_independent
    id = user_id(model, node_id)
    idx = priority_index(allocation.demand_priorities_all, priority)
    return user_demand.allocated[id.idx, idx]
end

function apply_user_demand_shadow!(model)::Nothing
    (; p_independent) = model.integrator.p
    (; user_demand, allocation) = p_independent
    am = allocation_model(model)
    (; problem, scaling, node_ids_in_subnetwork) = am
    flow = problem[:flow]
    node_allocated = problem[:user_demand_allocated]

    for id in node_ids_in_subnetwork.user_demand_ids_subnetwork
        link_alloc = user_demand.inflow_link_allocated[id.idx]
        inflow_links = user_demand.inflow_links[id.idx]
        require(length(link_alloc) == length(inflow_links), "UserDemand link-allocation shape mismatch")
        for (i, link_metadata) in enumerate(inflow_links)
            link_alloc[i] = max(0.0, JuMP.value(flow[link_metadata.link]) * scaling.flow)
        end

        for (priority_idx, priority) in enumerate(allocation.demand_priorities_all)
            user_demand.has_demand_priority[id.idx, priority_idx] || continue
            user_demand.allocated[id.idx, priority_idx] =
                max(0.0, JuMP.value(node_allocated[id, priority]) * scaling.flow)
        end
    end
    return nothing
end

function cumulative_user_inflow(model, node_id::Int)::Float64
    id = user_id(model, node_id)
    return BMI.get_value_ptr(model, "user_demand.cumulative_inflow")[id.idx]
end

function basin_level(model)::Float64
    (; p_independent) = model.integrator.p
    id = Ribasim.NodeID(:Basin, 2, p_independent)
    return BMI.get_value_ptr(model, "basin.level")[id.idx]
end

function check_case(
        root::AbstractString,
        model_name::AbstractString;
        root_priority::Int,
        external_priority::Int,
        expected_initial_root::Float64,
        expected_initial_external::Float64,
        expected_next,
        expected_root_volume::Float64,
        expected_external_volume::Float64,
    )
    path = joinpath(root, "generated_testmodels", model_name, "ribasim.toml")
    require(isfile(path), "$model_name was not generated")
    model = BMI.initialize(Ribasim.Model, path)

    # First physical segment: the normal t=0 saveat-aligned allocation is applied by Ribasim.
    BMI.update_until(model, ENDPOINTS[1])
    require(isapprox(applied_allocated(model, 3, root_priority) * DAY, expected_initial_root; atol=ALLOCATION_TOL, rtol=0.0), "$model_name initial root application differs")
    require(isapprox(applied_allocated(model, 4, external_priority) * DAY, expected_initial_external; atol=ALLOCATION_TOL, rtol=0.0), "$model_name initial external application differs")

    for segment in 1:3
        boundary = ENDPOINTS[segment]

        # Counterfactual coupling seam:
        # solve from the accepted current physical state without output recording,
        # then explicitly apply only UserDemand allocation state.
        Ribasim.update_allocation!(model.integrator, SEGMENT; record=false)

        shadow_root = shadow_allocated(model, 3, root_priority) * DAY
        shadow_external = shadow_allocated(model, 4, external_priority) * DAY
        exp_root, exp_external = expected_next[segment]

        require(isapprox(shadow_root, exp_root; atol=ALLOCATION_TOL, rtol=0.0), "$model_name shadow root differs at boundary $boundary")
        require(isapprox(shadow_external, exp_external; atol=ALLOCATION_TOL, rtol=0.0), "$model_name shadow external differs at boundary $boundary")

        apply_user_demand_shadow!(model)

        applied_root = applied_allocated(model, 3, root_priority) * DAY
        applied_external = applied_allocated(model, 4, external_priority) * DAY
        require(isapprox(applied_root, exp_root; atol=ALLOCATION_TOL, rtol=0.0), "$model_name explicit root apply failed at boundary $boundary")
        require(isapprox(applied_external, exp_external; atol=ALLOCATION_TOL, rtol=0.0), "$model_name explicit external apply failed at boundary $boundary")

        println(
            "RIBASIM_REAL_19K_APPLY model=$model_name boundary_s=$boundary " *
            "shadow_root_m3_day=$shadow_root shadow_external_m3_day=$shadow_external " *
            "applied_root_m3_day=$applied_root applied_external_m3_day=$applied_external",
        )

        BMI.update_until(model, ENDPOINTS[segment + 1])
    end

    root_volume = cumulative_user_inflow(model, 3)
    external_volume = cumulative_user_inflow(model, 4)
    total_volume = root_volume + external_volume
    final_level = basin_level(model)
    storage_gain = AREA * (final_level - 1.0)

    require(isapprox(root_volume, expected_root_volume; atol=VOLUME_TOL, rtol=0.0), "$model_name root physical volume differs from frozen 6-hour reference")
    require(isapprox(external_volume, expected_external_volume; atol=VOLUME_TOL, rtol=0.0), "$model_name external physical volume differs from frozen 6-hour reference")
    require(isapprox(total_volume, 24.512820430148427; atol=VOLUME_TOL, rtol=0.0), "$model_name total physical volume differs from frozen 6-hour reference")
    require(isapprox(final_level, 1.0000074871795697; atol=LEVEL_TOL, rtol=0.0), "$model_name final level differs from frozen 6-hour reference")
    require(isapprox(storage_gain, 7.487179569665159; atol=VOLUME_TOL, rtol=0.0), "$model_name storage gain differs from frozen 6-hour reference")
    require(isapprox(total_volume + storage_gain, 32.0; atol=VOLUME_TOL, rtol=0.0), "$model_name physical ledger does not close")

    println(
        "RIBASIM_REAL_19K_OBS model=$model_name root_supplied_m3=$root_volume " *
        "external_supplied_m3=$external_volume total_supplied_m3=$total_volume " *
        "final_level=$final_level storage_gain_m3=$storage_gain",
    )
    println("RIBASIM_REAL_19K_CASE=PASS model=$model_name")
    BMI.finalize(model)
    return (total=total_volume, level=final_level)
end

function main()
    length(ARGS) == 1 || error("usage: real_ribasim_explicit_userdemand_apply_bridge.jl <ribasim-root>")
    root = abspath(ARGS[1])

    root_first = check_case(
        root,
        "swap5_bmi_clock_root_first";
        root_priority=2,
        external_priority=3,
        expected_initial_root=32.0,
        expected_initial_external=0.0,
        expected_next=ROOT_FIRST_NEXT,
        expected_root_volume=19.015246367867107,
        expected_external_volume=5.49757406228132,
    )
    external_first = check_case(
        root,
        "swap5_bmi_clock_external_first";
        root_priority=3,
        external_priority=2,
        expected_initial_root=12.0,
        expected_initial_external=20.0,
        expected_next=EXTERNAL_FIRST_NEXT,
        expected_root_volume=14.50504727621437,
        expected_external_volume=10.007773153934059,
    )

    require(isapprox(root_first.total, external_first.total; atol=VOLUME_TOL, rtol=0.0), "priority reversal changed explicit-apply total")
    require(isapprox(root_first.level, external_first.level; atol=LEVEL_TOL, rtol=0.0), "priority reversal changed explicit-apply Basin endpoint")
    println("RIBASIM_REAL_19K_EXPLICIT_USERDEMAND_APPLY_SEAM=PASS")
end

main()
