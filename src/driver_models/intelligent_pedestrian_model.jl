### Intelligent pedestrian model that stops if a crosswalk is busy

@with_kw mutable struct IntelligentPedestrian <: DriverModel{ConstantSpeedDawdling}
    a::ConstantSpeedDawdling = ConstantSpeedDawdling(0., 0.)
    v_noise::Float64 = 0.
    dt::Float64 = 0.1
    motion::DriverModel = ConstantPedestrian(v_noise = v_noise, dt = dt)
    ttc_threshold::Float64 = 4.5
    crosswalk::Lane = Lane()
    conflict_lanes::Vector{Lane{Float64}} = Lane{Float64}[]
    dtol::Float64 = 0.1
    # states
    wait::Bool = true
    crossing::Bool = false
    done::Bool = false
end

AutomotiveDrivingModels.get_name(model::IntelligentPedestrian) = "IntelligentPedestrian"
Base.rand(model::IntelligentPedestrian) = model.a

AutomotiveDrivingModels.reset_hidden_state!(model::IntelligentPedestrian) = model

function AutomotiveDrivingModels.observe!(model::IntelligentPedestrian,
                                        scene::EntityFrame{VehicleState, VehicleDef, Int64},
                                        roadway::Roadway,
                                        egoid::Int)
    ped = scene[findfirst(egoid, scene)]
    observe!(model.motion, scene, roadway, egoid)
    model.crossing = update_crossing(ped, model.crosswalk, model.conflict_lanes, roadway)
    model.done = update_done(ped, model.crossing, model.crosswalk)
    if !model.crossing
        model.wait = update_wait(ped, scene, model, roadway)
    else
        model.wait = false
    end
    if !model.wait || model.done# if engaged, keep going
        model.a = model.motion.a 
    else 
        if model.wait
            model.a = ConstantSpeedDawdling(0., 0.)
        else
            model.a = model.motion.a 
        end 
    end     
end

function update_crossing(ped::Vehicle, crosswalk::Lane{T}, conflict_lanes::Vector{Lane{T}}, roadway::Roadway) where T
    # check if the pedestrian is in the conflict zone
    for lane in conflict_lanes
        ped_f = Frenet(proj(ped.state.posG, lane, roadway, move_along_curves=false), roadway)
        if abs(ped_f.t) < lane.width/2 && get_lane(roadway, ped).tag == crosswalk.tag
            # println(" position on lane : ", ped_f)
            return true
        end
    end
    return false 
end

function update_done(ped::Vehicle, crossing::Bool, crosswalk::Lane)
    # check if the pedestrian is done crossing 
    return !crossing && direction_from_center(ped, crosswalk) .< 0.
end    

function get_distance_to_crosswalk(veh::Vehicle, crosswalk::Lane, roadway::Roadway)
    lane = get_lane(roadway, veh)
    cw_length = get_end(crosswalk)
    cw_center = posg(Frenet(crosswalk, cw_length/2), roadway)
    collision_point = VecSE2(cw_center.x, veh.state.posG.y)
    cw_proj = Frenet(collision_point, lane, roadway)
    Δs = cw_proj.s - veh.state.posF.s
    return Δs
end

function update_wait(ped::Vehicle, 
                    scene::Scene, 
                    model::IntelligentPedestrian, 
                    roadway::Roadway)
    # check if the pedestrian should wait or not 
    for veh in scene 
        if veh.def.class == AgentClass.PEDESTRIAN
            continue 
        end 
        # check if vehicle is on the crosswalk 
        posG = veh.state.posG 
        cw_posF = Frenet(proj(posG, model.crosswalk, roadway, move_along_curves=false), roadway)
        lane = get_lane(roadway, veh)
        # if lane ∈ model.conflict_lanes
        # println("vehicle position on cw $(cw_posF)") 
        # println("pedestrian position $(ped.state.posF)")
        # println(" difference: $(cw_posF.s - ped.state.posF.s)")
        # t_car = cw_posF.t 
        # println( abs(cw_posF.t) < model.crosswalk.width/2 + veh.def.length/2 - model.dtol)
        # println( (cw_posF.s - ped.state.posF.s)*cos(ped.state.posF.ϕ) > 0.)
        if abs(cw_posF.t) < model.crosswalk.width/2 + veh.def.length/2 - model.dtol &&
                                (cw_posF.s - ped.state.posF.s)*cos(ped.state.posF.ϕ) > 0.
            # println("vehicle $(veh.id) is on the crosswalk")
            # vehicle is on the crosswalk 
            # check if pedestrian is passed it or not 
            return true 
        end
        if lane ∈ model.conflict_lanes
            # check the ttc 
            Δs = get_distance_to_crosswalk(veh, model.crosswalk, roadway)
            ttc = Δs/veh.state.v
            if 0. < ttc < model.ttc_threshold 
                # println("vehicle $(veh.id) ttc: $ttc, Δs: $Δs")
                return true
            end
        end
    end
    return false 
end
