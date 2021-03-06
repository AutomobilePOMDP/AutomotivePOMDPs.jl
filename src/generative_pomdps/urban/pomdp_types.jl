
const UrbanState = Records.Frame{Records.Entity{AutomotiveDrivingModels.VehicleState,AutomotiveDrivingModels.VehicleDef,Int64}}

const UrbanObs = Vector{Float64}

#### Action type

struct UrbanAction
    acc::Float64
end

function Base.copyto!(a::UrbanAction, b::UrbanAction)
    a.acc = b.acc
end

function Base.hash(a::UrbanAction, h::UInt64 = zero(UInt64))
    return hash(a.acc, h)
end

function Base.:(==)(a::UrbanAction, b::UrbanAction)
    return a.acc == b.acc
end

#### POMDP type

@with_kw mutable struct UrbanPOMDP <: POMDP{UrbanState, UrbanAction, UrbanObs}
    env::UrbanEnv = UrbanEnv()
    obs_dist::ObstacleDistribution = ObstacleDistribution(UrbanEnv())
    lidar::Bool = false
    sensor::AbstractSensor = GaussianSensor()
    models::Dict{Int64, DriverModel} = Dict{Int64, DriverModel}(1=>EgoDriver(UrbanAction(0.)))
    ego_type::VehicleDef = VehicleDef()
    car_type::VehicleDef = VehicleDef()
    ped_type::VehicleDef = VehicleDef(AgentClass.PEDESTRIAN, 1.0, 1.0)
    max_cars::Int64 = 10
    max_peds::Int64 = 10
    max_obstacles::Int64 = 3
    max_acc::Float64 = 2.0
    ego_start::Float64 = env.params.stop_line - ego_type.length/2
    ego_goal::LaneTag = LaneTag(2,2)
    off_grid::VecSE2 = VecSE2(UrbanEnv().params.x_min+VehicleDef().length/2, UrbanEnv().params.y_min+VehicleDef().width/2, 0)
    car_models::Dict{SVector{2, LaneTag}, DriverModel} = get_car_models(env, get_ttc_model)
    n_features::Int64 = 4
    ΔT::Float64 = 0.5 # decision frequency
    car_birth::Float64 = 0.3
    ped_birth::Float64 = 0.3
    a_noise::Float64 = 1.0
    v_noise::Float64 = 1.
    pos_obs_noise::Float64 = 0.5
    vel_obs_noise::Float64 = 0.5
    collision_cost::Float64 = -1.
    action_cost::Float64 = 0.
    goal_reward::Float64 = 1.
    γ::Float64 = 0.95 # discount factor
end

## HELPERS

function POMDPs.discount(pomdp::UrbanPOMDP)
    return pomdp.γ
end

POMDPs.actions(pomdp::UrbanPOMDP) = [UrbanAction(-2.0), UrbanAction(0.0), UrbanAction(2.0), UrbanAction(4.0)]

function POMDPs.actionindex(pomdp::UrbanPOMDP, action::UrbanAction)
    if action.acc == -4.0
        return 1
    elseif action.acc == -2.0
        return 2
    elseif action.acc == 0.
        return 3
    else
        return 4
    end
end

# only works for single lane intersection!
function get_car_models(env::UrbanEnv, get_model::Function)
    d = Dict{SVector{2, LaneTag}, DriverModel}()

    r1 = SVector(LaneTag(1,1), LaneTag(2,1))
    d[r1] = get_model(env, r1)

    r2 = SVector(LaneTag(1,1), LaneTag(5,1))
    d[r2] = get_model(env, r2)

    r3 = SVector(LaneTag(3,1), LaneTag(4,1))
    d[r3] = get_model(env, r3)

    r4 = SVector(LaneTag(3,1), LaneTag(5,1))
    d[r4] = get_model(env, r4)
    return d
end
