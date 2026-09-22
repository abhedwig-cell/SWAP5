using Ribasim
using JuMP
import BasicModelInterface as BMI

const DAY = 86400.0
const SEGMENT = 21600.0
const ENDPOINTS = [21600.0, 43200.0, 64800.0, 86400.0]
const AREA = 1_000_000.0
const VOLUME_TOL = 0.05
const LEVEL_TOL = 5.0e-8
const ALLOCATION_TOL = 0.05

const REF_LEVEL = [
    1.0000039988002398,
    1.000005994903268,
    1.0000069906366162,
    1.0000074871795686,
]
const REF_TOTAL = [
    4.001199760004028,
    10.005096731410507,
    17.009363382977337,
    24.51282043070043,
]
const ROOT_FIRST_ROOT = [
    4.001199760004028,
    9.004947510764467,
    14.009817152853525,
    19.01524636786452,
]
const ROOT_FIRST_EXT = [
    0.0,
    1.0001492206460414,
    2.9995462301238116,
    5.497574062835911,
]
const EXTERNAL_FIRST_ROOT = [
    1.5004499100013697,
    5.002473005916709,
    9.504304836328377,
    14.505047276435288,
]
const EXTERNAL_FIRST_EXT = [
    2.5007498500022827,
    5.002623725382635,
    7.505058546427442,
    10.00777315393317,
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

function read_state(model)
    root = cumulative_user_inflow(model, 3)
    ext = cumulative_user_inflow(model, 4)
    level = basin_level(model)
    return (root=root, ext=ext, total=root+ext, level=level, storage=AREA*(level-1.0))
end

function check_reference(state, i::Int, root_ref, ext_ref, label::AbstractString)
    require(isapprox(state.root, root_ref[i]; atol=VOLUME_TOL, rtol=0.0), "$label root cumulative volume differs at endpoint $i")
    require(isapprox(state.ext, ext_ref[i]; atol=VOLUME_TOL, rtol=0.0), "$label external cumulative volume differs at endpoint $i")
    require(isapprox(state.total, REF_TOTAL[i]; atol=VOLUME_TOL, rtol=0.0), "$label total cumulative volume differs at endpoint $i")
    require(isapprox(state.level, REF_LEVEL[i]; atol=LEVEL_TOL, rtol=0.0), "$label Basin level differs at endpoint $i")
    expected_inflow = 32.0 * ENDPOINTS[i] / DAY
    require(isapprox(state.total + state.storage, expected_inflow; atol=VOLUME_TOL, rtol=0.0), "$label physical ledger does not close at endpoint $i")
end

function check_route_equivalence(native, explicit, i::Int, label::AbstractString)
    require(isapprox(native.root, explicit.root; atol=VOLUME_TOL, rtol=0.0), "$label root route difference at endpoint $i")
    require(isapprox(native.ext, explicit.ext; atol=VOLUME_TOL, rtol=0.0), "$label external route difference at endpoint $i")
    require(isapprox(native.total, explicit.total; atol=VOLUME_TOL, rtol=0.0), "$label total route difference at endpoint $i")
    require(isapprox(native.level, explicit.level; atol=LEVEL_TOL, rtol=0.0), "$label Basin-level route difference at endpoint $i")
end

function run_native(path::AbstractString, root_ref, ext_ref, label::AbstractString)
    model = BMI.initialize(Ribasim.Model, path)
    states = NamedTuple[]
    for (i, endpoint) in enumerate(ENDPOINTS)
        BMI.update_until(model, endpoint)
        state = read_state(model)
        check_reference(state, i, root_ref, ext_ref, "$label native")
        push!(states, state)
        println("RIBASIM_REAL_19L_NATIVE label=$label endpoint_s=$endpoint root_m3=$(state.root) external_m3=$(state.ext) total_m3=$(state.total) level=$(state.level) storage_gain_m3=$(state.storage)")
    end
    BMI.finalize(model)
    return states
end

function run_explicit(path::AbstractString, root_ref, ext_ref, label::AbstractString)
    model = BMI.initialize(Ribasim.Model, path)
    states = NamedTuple[]

    BMI.update_until(model, ENDPOINTS[1])
    state = read_state(model)
    check_reference(state, 1, root_ref, ext_ref, "$label explicit")
    push!(states, state)
    println("RIBASIM_REAL_19L_EXPLICIT label=$label endpoint_s=$(ENDPOINTS[1]) root_m3=$(state.root) external_m3=$(state.ext) total_m3=$(state.total) level=$(state.level) storage_gain_m3=$(state.storage)")

    for segment in 1:3
        Ribasim.update_allocation!(model.integrator, SEGMENT; record=false)
        apply_user_demand_shadow!(model)
        BMI.update_until(model, ENDPOINTS[segment+1])
        state = read_state(model)
        check_reference(state, segment+1, root_ref, ext_ref, "$label explicit")
        push!(states, state)
        println("RIBASIM_REAL_19L_EXPLICIT label=$label endpoint_s=$(ENDPOINTS[segment+1]) root_m3=$(state.root) external_m3=$(state.ext) total_m3=$(state.total) level=$(state.level) storage_gain_m3=$(state.storage)")
    end

    BMI.finalize(model)
    return states
end

function compare_case(root::AbstractString, label::AbstractString, native_name::AbstractString, explicit_name::AbstractString, root_ref, ext_ref)
    native_path = joinpath(root, "generated_testmodels", native_name, "ribasim.toml")
    explicit_path = joinpath(root, "generated_testmodels", explicit_name, "ribasim.toml")
    require(isfile(native_path), "$native_name was not generated")
    require(isfile(explicit_path), "$explicit_name was not generated")

    native = run_native(native_path, root_ref, ext_ref, label)
    explicit = run_explicit(explicit_path, root_ref, ext_ref, label)

    for i in eachindex(ENDPOINTS)
        check_route_equivalence(native[i], explicit[i], i, label)
    end
    println("RIBASIM_REAL_19L_CASE=PASS label=$label")
end

function main()
    length(ARGS) == 1 || error("usage: real_ribasim_explicit_apply_trajectory_bridge.jl <ribasim-root>")
    root = abspath(ARGS[1])

    compare_case(
        root,
        "root_first",
        "swap5_saveat_21600_root_first",
        "swap5_bmi_clock_root_first",
        ROOT_FIRST_ROOT,
        ROOT_FIRST_EXT,
    )
    compare_case(
        root,
        "external_first",
        "swap5_saveat_21600_external_first",
        "swap5_bmi_clock_external_first",
        EXTERNAL_FIRST_ROOT,
        EXTERNAL_FIRST_EXT,
    )

    println("RIBASIM_REAL_19L_ACCEPTED_STATE_TRAJECTORY_EQUIVALENCE=PASS")
end

main()
