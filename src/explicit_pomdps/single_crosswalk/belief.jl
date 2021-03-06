# function POMDPs.initialize_belief(pomdp::SingleOCPOMDP)
#     b0 = DiscreteBelief(n_states(pomdp))
#     d0 = initialstate(pomdp::SingleOCPOMDP)
#     for (i, s) in enumerate(iterator(states(pomdp)))
#         b0.b[i] = pdf(d0, s)
#     end
#     @assert sum(b0.b) ≈ 1.0
#     return b0
# end

#for sarsop for exploration
# function POMDPs.initialstate(pomdp::SingleOCPOMDP)
#      state_space = states(pomdp)
#      states_to_add = SingleOCState[]
#      for s in state_space
#          if !s.crash
#              push!(states_to_add, s)
#          end
#      end
#      probs = ones(length(states_to_add))
#      normalize!(probs, 1)
#      return SparseCat(states_to_add, probs)
#  end

# """
# Returns the initial state of the pomdp problem
# """
# function POMDPs.initialstate(pomdp::SingleOCPOMDP)
#     ImplicitDistribution() do rng
#         ped = rand(rng) > pomdp.no_ped_prob
#         if ped
#             pomdp.no_ped = false
#             d = initialstate(pomdp)
#             s = rand(rng, d)
#         else
#             # println("No pedestrians")
#             pomdp.no_ped = true
#             d = initial_distribution_no_ped(pomdp::SingleOCPOMDP)
#             s = rand(rng, d)
#         end
#         return s
#     end
# end

"""
Returns the initial state distribution over the ego car state when there is no pedestrians
"""
function initial_distribution_no_ped(pomdp::SingleOCPOMDP)
    env = pomdp.env
    V_ego = LinRange(0., env.params.speed_limit, Int(floor(env.params.speed_limit/pomdp.vel_res)) + 1)
    rl = env.params.roadway_length
    cw = env.params.crosswalk_width
    lw = env.params.lane_width
    cl = env.params.crosswalk_length
    p_birth = pomdp.p_birth
    x_ped = 0.5*(env.params.roadway_length - env.params.crosswalk_width + 1)
    y_ego = 0. #XXX might need to be a parameter
    x_start = pomdp.x_start #XXX parameterized
    states = SingleOCState[]
    for v in V_ego
        ego = VehicleState(VecSE2(x_start, y_ego, 0.), env.roadway, v)
        push!(states, SingleOCState(false, ego, get_off_the_grid(pomdp)))
    end
    probs = ones(length(states))
    probs = normalize!(probs, 1)
    return SparseCat(states, probs)
end


function POMDPs.initialstate(pomdp::SingleOCPOMDP)
    env = pomdp.env
    V_ego = LinRange(0., env.params.speed_limit, Int(floor(env.params.speed_limit/pomdp.vel_res)) + 1)
    rl = env.params.roadway_length
    cw = env.params.crosswalk_width
    lw = env.params.lane_width
    cl = env.params.crosswalk_length
    p_birth = pomdp.p_birth
    x_ped = 0.5*(env.params.roadway_length - env.params.crosswalk_width + 1)
    y_ego = 0. #XXX might need to be a parameter
    x_start = pomdp.x_start #XXX parameterized
    Y = get_Y_grid(pomdp)
    V_ped = LinRange(0, env.params.ped_max_speed, Int(floor(env.params.ped_max_speed/pomdp.vel_res)) + 1)
    states = SingleOCState[]
    for v in V_ego
        ego = VehicleState(VecSE2(x_start, y_ego, 0.), env.roadway, v)
        for y in Y[1:div(length(Y),2)]
            for v_ped in V_ped
                ped = VehicleState(VecSE2(x_ped, y, pi/2), env.roadway, v_ped)
                crash = is_colliding(Vehicle(ego, pomdp.ego_type, 0),
                                     Vehicle(ped, pomdp.ped_type, 1))
                push!(states, SingleOCState(crash, ego, ped))
            end
        end
    end
    # Add also the off the grid state, weight using the probability p_birth
    # of a pedestrian actually being here
    n_in_grid = length(states)
    for v in V_ego
        ego = VehicleState(VecSE2(x_start, y_ego, 0.), env.roadway, v)
        push!(states, SingleOCState(false, ego, get_off_the_grid(pomdp)))
    end
    n_off_grid = length(states) - n_in_grid
    probs = ones(length(states))
    probs[1:n_in_grid] .= p_birth/n_in_grid
    probs[n_in_grid + 1:end] .= (1.0 - p_birth)/n_off_grid
    normalize!(probs, 1)
    @assert sum(probs) ≈ 1.
    return SparseCat(states, probs)
end

function POMDPs.initialstate(pomdp::SingleOCPOMDP, ego::VehicleState)
    env = pomdp.env
    rl = env.params.roadway_length
    cw = env.params.crosswalk_width
    lw = env.params.lane_width
    cl = env.params.crosswalk_length
    p_birth = pomdp.p_birth
    x_ped = 0.5*(env.params.roadway_length - env.params.crosswalk_width + 1)
    y_ego = 0. #XXX might need to be a parameter
    x_start = pomdp.x_start #XXX parameterized
    Y = get_Y_grid(pomdp)
    V_ped = LinRange(0, env.params.ped_max_speed, Int(floor(env.params.ped_max_speed/pomdp.vel_res)) + 1)
    states = SingleOCState[]
    for y in Y[1:div(length(Y),2)]
        for v_ped in V_ped
            ped = VehicleState(VecSE2(x_ped, y, pi/2), env.roadway, v_ped)
            crash = is_colliding(Vehicle(ego, pomdp.ego_type, 0),
                                 Vehicle(ped, pomdp.ped_type, 1))
            push!(states, SingleOCState(crash, ego, ped))
        end
    end
    # Add also the off the grid state, weight using the probability p_birth
    # of a pedestrian actually being here
    n_in_grid = length(states)
    push!(states, SingleOCState(false, ego, get_off_the_grid(pomdp)))

    n_off_grid = length(states) - n_in_grid
    probs = ones(length(states))
    probs[1:n_in_grid] = p_birth/n_in_grid
    probs[n_in_grid + 1:end] = (1.0 - p_birth)/n_off_grid
    # normalize!(probs, 1)
    @assert sum(probs) ≈ 1.
    return SparseCat(states, probs)
end

mutable struct SingleOCUpdater <: Updater
    pomdp::SingleOCPOMDP
end


# Updates the belief given the current action and observation
function POMDPs.update(bu::SingleOCUpdater, bold::SparseCat, a::SingleOCAction, o::SingleOCObs)
    bnew = SparseCat(SingleOCState[], Float64[])
    pomdp = bu.pomdp
    # initialize spaces
    pomdp_states = ordered_states(pomdp)

    # iterate through each state in belief vector
    for (i, sp) in enumerate(pomdp_states)
        # get the distributions
        od = observation(pomdp, a, sp)
        # get prob of observation o from current distribution
        probo = pdf(od, o)
        # if observation prob is 0.0, then skip rest of update b/c bnew[i] is zero
        if probo == 0.0
            continue
        end
        b_sum = 0.0 # belief for state sp
        for (j, s) in enumerate(bold.vals)
            td = transition(pomdp, s, a)
            pp = pdf(td, sp)
            b_sum += pp * bold.probs[j]
        end
        if b_sum != 0.
            push!(bnew.vals, sp)
            push!(bnew.probs, probo*b_sum)
        end
    end

    # if norm is zero, the update was invalid - reset to uniform
    if sum(bnew.probs) == 0.0
        println("Invalid update for: ", bold, " ", a, " ", o)
        throw("UpdateError")
    else
        normalize!(bnew.probs, 1)
    end
    bnew
end

########################### HELPERS ###############################################################

# These functions are helpful to reshape the belief as input of a deep RL algorithm

"""
    vec2dis(bvec::Vector{Float64}, state_space::Vector{SingleOCState} = state_space)
Convert a discrete belief representation to a more compact one using the SparseCat type
"""
function vec2dis(bvec::Vector{Float64}, state_space::Vector{SingleOCState} = state_space)
    bsparse = sparsevec(bvec)
    n = nnz(bsparse)
    bdis = SparseCat(Vector{SingleOCState}(n), zeros(n))
    for i = 1:n
        ind = bsparse.nzind[i]
        bdis.p[i] = bsparse.nzval[i]
        bdis.it[i] = state_space[ind]
    end
    return bdis
end

"""
    dis2vec!(pomdp::SingleOCPOMDP, bdis::SparseCat, bvec::Vector{Float64})
convert an SparseCat to a full vector representation
"""
function dis2vec!(pomdp::SingleOCPOMDP, bdis::SparseCat, bvec::Vector{Float64})
    for i =1:length(bdis.probs)
        ind = stateindex(pomdp, bdis.vals[i])
        bvec[ind] = bdis.p[i]
    end
end

"""
    get_belief_image(pomdp::SingleOCPOMDP, d0::SparseCat, Y::LinRange{Float64} = get_Y_grid(pomdp), V_ped::LinRange{Float64} = get_V_ped_grid(pomdp))
returns a probability matrix where the index are the pedestrian position and velSingleOCity, the values are the probability of such y,v pair
"""
function get_belief_image(pomdp::SingleOCPOMDP, d0::SparseCat, Y::LinRange{Float64} = get_Y_grid(pomdp), V_ped::LinRange{Float64} = get_V_ped_grid(pomdp))
    Y = get_Y_grid(pomdp)
    V_ped = get_V_ped_grid(pomdp)
    P = zeros(length(Y), length(V_ped))
    p_off_grid = 0.
    for (i,s) in enumerate(d0.vals)
        if off_the_grid(pomdp, s.ped)
            p_off_grid += d0.probs[i]
        else
            y_ind = get_y_index(pomdp, s.ped.posG.y)
            v_ped_ind = get_v_ped_index(pomdp, s.ped.v)
            P[y_ind, v_ped_ind] += d0.probs[i]
        end
    end
    @assert sum(P) + p_off_grid ≈ 1.0
    return P, p_off_grid
end

"""
    tuple_to_belief(pomdp::SingleOCPOMDP, t::Tuple{Array{Float64,1},Array{Float64,2}})
convert tuple representation to SparseCat object
"""
function tuple_to_belief(pomdp::SingleOCPOMDP, t::Tuple{Array{Float64,1},Array{Float64,2}})
    Y_grid = get_Y_grid(pomdp)
    V_ped = get_V_ped_grid(pomdp)
    b = SparseCat(SingleOCState[], Float64[])
    P = t[2]
    ego_x, ego_v, p_off = t[1][1], t[1][2], t[1][3]
    ego = xv_to_state(pomdp, ego_x, ego_v)
    m, n = size(P)
    for i=1:n
        for j=1:m
            if P[j, i] != 0
            ped = yv_to_state(pomdp, Y_grid[j], V_ped[i])
            s = SingleOCState(collision_checker(ego, ped, pomdp.ego_type, pomdp.ped_type), ego, ped)
            push!(b.vals, s)
            push!(b.probs, P[j, i])
            end
        end
    end
    s_off = SingleOCState(false, ego, get_off_the_grid(pomdp))
    push!(b.vals, s_off)
    push!(b.probs, p_off)
    # sanity check
    @assert sum(b.p) ≈ 1.0
    @assert length(b.p) == length(b.it)
    return b
end

"""
    belief_to_tuple(pomdp::SingleOCPOMDP, b::SparseCat)
only valid after first step when ego car is known
convert a belief representation into a tuple [ego.x, ego.v, p_off], belief image
"""
function belief_to_tuple(pomdp::SingleOCPOMDP, b::SparseCat)
    vec = zeros(3)
    ego_x, ego_v = b.it[1].ego.posG.x, b.it[1].ego.v
    img, p_off = get_belief_image(pomdp, b, get_Y_grid(pomdp), get_V_ped_grid(pomdp))
    vec[1], vec[2], vec[3] = ego_x, ego_v, p_off
    s = (vec, img)
end
