# AutomotivePOMDPs: Driving Scenarios formulated as POMDPs

[![Build Status](https://travis-ci.org/sisl/AutomotivePOMDPs.jl.svg?branch=master)](https://travis-ci.org/sisl/AutomotivePOMDPs.jl)
[![Coverage Status](https://coveralls.io/repos/github/sisl/AutomotivePOMDPs.jl/badge.svg?branch=master)](https://coveralls.io/github/sisl/AutomotivePOMDPs.jl?branch=master)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://sisl.github.io/AutomotivePOMDPs.jl/latest)

Original author: Maxime Bouton, [boutonm@stanford.edu](boutonm@stanford.edu)

This repository consists of different driving scenarios formulated as POMDPs. It provides a generative model for computing policies. A few of them have explicit transition and observation models. This library is based on "POMDPs" v0.9 instead of "POMDP" v0.8 in original library.
 
## Installation

To install this package, first add the SISL registry and the JuliaPOMDP registry such that all dependencies are automatically installed. 
You can run the following in the bash:
```bash
git clone https://github.com/AutomobilePOMDP/AutomotivePOMDPs.jl
cd AutomotivePOMDPs.jl
julia
```
```julia 
pkg> add POMDPs
using POMDPs
POMDPs.add_registry()
pkg> registry add "https://github.com/sisl/Registry"
pkg> instantiate
```

## Code to run

Run `docs/Urban POMDP tutoial.ipynb` for a visualization of the simulation environment.

## Scenarios

This package exports the following POMDP Models:
- `SingleOCPOMDP`: Occluded crosswalk with one single pedestrian. Discrete states and observations with explicit transition and observation model.
- `SingleOIPOMDP`: Occluded intersection with one single car. Discrete states and observations with explicit transition and observation model.
- `OCPOMDP`: Occluded crosswalk with a flow of pedestrian. Generative model implementation with continuous state and observations
- `OIPOMDP`: Occluded T intersection with a flow of cars driving in multiple lanes. Generative model implementation with continuous state and observations
- `UrbanPOMDP` : Occluded T intersection with crosswalks, flow of cars and pedestrians. Generative model implementation with continuous state and observations

These models are defined according to the [POMDPs.jl]() interface. To see how they are parameterized, toggle the documentation using `?` or
use the function `fieldnames` if documentation is not yet written.

Currently, only the `SingleOCPOMDP` environment can be solved using online and offline methods, examples are as follows:
```julia
using POMDPs
using AutomotivePOMDPs
using POMDPPolicies
using POMDPSimulators
using BeliefUpdaters
using ParticleFilters
using AutomotiveDrivingModels
using AutomotiveSensors
using AutoViz
using Reel
using QMDP
using ARDESPOT

pomdp = SingleOCPOMDP(ΔT=0.5, max_acc=1.5, p_birth=1.0, action_cost=-0.2, γ=0.99)

qmdp_policy = solve(QMDPSolver(max_iterations=1000), pomdp)

function qmdp_upper_bound(pomdp, b)
    return value(qmdp_policy, b)
end

solver = DESPOTSolver(lambda=0., K=100, bounds=IndependentBounds(DefaultPolicyLB(RandomSolver()), qmdp_upper_bound, check_terminal=true),
default_action=SingleOCAction(-2.0), bounds_warnings=false)
planner = solve(solver, pomdp)

up = SingleOCUpdater(pomdp);

hr = RolloutSimulator(rng=rng, max_steps=50)

@show qmdp_reward = POMDPs.simulate(hr, pomdp, qmdp_policy, up);
@show despot_reward = POMDPs.simulate(hr, pomdp, planner, up);
```

## Dependencies

- AutomotiveDrivingModels.jl
- POMDPs.jl
