# The solver type
"""
    ValueIterationSolver <: Solver

The solver type. Contains the following parameters that can be passed as keyword arguments to the constructor

    - max_iterations::Int64, the maximum number of iterations value iteration runs for (default 100)
    - belres::Float64, the Bellman residual (default 1e-3)
    - verbose::Bool, if set to true, the bellman residual and the time per iteration will be printed to STDOUT (default false)
    - include_Q::Bool, if set to true, the solver outputs the Q values in addition to the utility and the policy (default true)
    - init_util::Vector{Float64}, provides a custom initialization of the utility vector. (initializes utility to 0 by default)
"""
Base.@kwdef mutable struct ValueIterationSolver <: Solver
    max_iterations::Int         = 100 # max number of iterations
    belres::Float64             = 1e-3 # Bellman Residual
    verbose::Bool               = false
    include_Q::Bool             = true
    init_util::Vector{Float64}  = Vector{Float64}(undef, 0)
end

@POMDP_require solve(solver::ValueIterationSolver, mdp::Union{MDP,POMDP}) begin
    P = typeof(mdp)
    S = statetype(P)
    A = actiontype(P)
    @req discount(::P)
    @subreq ordered_states(mdp)
    @subreq ordered_actions(mdp)
    @req transition(::P,::S,::A)
    @req reward(::P,::S,::A,::S)
    @req stateindex(::P,::S)
    @req actionindex(::P, ::A)
    @req actions(::P, ::S)
    as = actions(mdp)
    ss = states(mdp)
    @req length(::typeof(ss))
    @req length(::typeof(as))
    a = first(as)
    s = first(ss)
    dist = transition(mdp, s, a)
    D = typeof(dist)
    @req support(::D)
    @req pdf(::D,::S)
end

#####################################################################
# Solve runs the value iteration algorithm.
# The policy input argument is either provided by the user or
# initialized during the function call.
# Verbose is a flag that triggers text output to the command line
# Example code for running the function:
# mdp = GridWorld(10, 10) # initialize a 10x10 grid world MDP (user written code)
# solver = ValueIterationSolver(max_iterations=40, belres=1e-3)
# policy = ValueIterationPolicy(mdp)
# solve(solver, mdp, policy, verbose=true)
#####################################################################
function solve(solver::ValueIterationSolver, mdp::MDP)

    @warn_requirements solve(solver, mdp)

    # solver parameters
    max_iterations = solver.max_iterations
    belres = solver.belres
    discount_factor = discount(mdp)
    ns = length(states(mdp))
    na = length(actions(mdp))

    # intialize the utility and Q-matrix
    if !isempty(solver.init_util)
        @assert length(solver.init_util) == ns "Input utility dimension mismatch"
        util = solver.init_util
    else
        util = zeros(ns)
    end
    include_Q = solver.include_Q
    if include_Q
        qmat = zeros(ns, na)
    end
    pol = zeros(Int64, ns)

    total_time = 0.0
    iter_time = 0.0

    # create an ordered list of states for fast iteration
    state_space = ordered_states(mdp)

    # main loop
    for i in 1:max_iterations
        residual = 0.0
        iter_time = @elapsed begin
        # state loop
        for (istate,s) in enumerate(state_space)
            sub_aspace = actions(mdp, s)
            if isterminal(mdp, s)
                util[istate] = 0.0
                pol[istate] = 1
            else
                old_util = util[istate] # for residual
                max_util = -Inf
                # action loop
                # util(s) = max_a( R(s,a) + discount_factor * sum(T(s'|s,a)util(s') )
                for a in sub_aspace
                    iaction = actionindex(mdp, a)
                    dist = transition(mdp, s, a) # creates distribution over neighbors
                    u = 0.0
                    for (sp, p) in weighted_iterator(dist)
                        iszero(p) && continue # skip if zero prob
                        r = reward(mdp, s, a, sp)
                        isp = stateindex(mdp, sp)
                        u += p * (r + discount_factor * util[isp])
                    end
                    new_util = u
                    if new_util > max_util
                        max_util = new_util
                        pol[istate] = iaction
                    end
                    include_Q && (qmat[istate, iaction] = new_util)
                end # action
                # update the value array
                util[istate] = max_util
                diff = abs(max_util - old_util)
                diff > residual && (residual = diff)
            end
        end # state
        end # time
        total_time += iter_time
        solver.verbose && @printf(
            "[Iteration %-4d] residual: %10.3G | iteration runtime: %10.3f ms, (%10.3G s total)\n",
            i, residual, iter_time*1000.0, total_time
        )
        residual < belres && break
    end # main
    if include_Q
        return ValueIterationPolicy(mdp, qmat, util, pol)
    else
        return ValueIterationPolicy(mdp, utility=util, policy=pol, include_Q=false)
    end
end

function solve(::ValueIterationSolver, ::POMDP)
    throw("""
           ValueIterationError: `solve(::ValueIterationSolver, ::POMDP)` is not supported,
          `ValueIterationSolver` supports MDP models only, look at QMDP.jl for a POMDP solver that assumes full observability.
           If you still wish to use the transition and reward from your POMDP model you can use the `UnderlyingMDP` wrapper from POMDPModelTools.jl as follows:
           ```
           solver = ValueIterationSolver()
           mdp = UnderlyingMDP(pomdp)
           solve(solver, mdp)
           ```
           """)
end
