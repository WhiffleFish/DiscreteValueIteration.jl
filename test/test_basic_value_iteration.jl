using DelimitedFiles

function support_serial_qtest(mdp::Union{MDP,POMDP}, file::AbstractString; niter::Int64=100, res::Float64=1e-3)
    qt = readdlm(file)
    solver = ValueIterationSolver(max_iterations=niter, belres=res, verbose=true)
    policy = solve(solver, mdp)
    (q, u, p, am) = locals(policy)
    npolicy = ValueIterationPolicy(mdp, deepcopy(q))
    nnpolicy = ValueIterationPolicy(mdp, deepcopy(q), deepcopy(u), deepcopy(p))
    s = GridWorldState(1,1)
    a1 = action(policy, s)
    @inferred action(policy, s)
    v1 = value(policy, s)
    a2 = action(npolicy, s)
    v2 = value(npolicy, s)
    return (isapprox(qt, q, rtol=1e-5)) && (policy.policy == nnpolicy.policy)
end


function test_complex_gridworld()
    # Load correct policy from file and verify we can reconstruct it
    rstates = [GridWorldState(4,3), GridWorldState(4,6), GridWorldState(9,3), GridWorldState(8,8)]
    rvals = [-10.0, -5.0, 10.0, 3.0]
    xs = 10
    ys = 10
    mdp = LegacyGridWorld(sx=xs, sy=ys, rs = rstates, rv = rvals)
    file = "grid-world-10x10-Q-matrix.txt"
    niter = 100
    res = 1e-3

    return support_serial_qtest(mdp, file, niter=niter, res=res)
end

function test_simple_grid()
    # Simple test....
    # GridWorld(sx=2,sy=3) w reward at (2,3):
    # Here's our grid:
    # |state (x,y)____available actions__|
    # ----------------------------------------------
    # |5 (1,3)__u,d,l,r__|6 (2,3)__u,d,l,r+REWARD__|
    # |3 (1,2)__u,d,l,r__|4 (2,2)______u,d,l,r_____|
    # |1 (1,1)__u,d,l,r__|2 (2,1)______u,d,l,r_____|
    # ----------------------------------------------
    # 7 (0,0) is absorbing state
    mdp = LegacyGridWorld(sx=2, sy=3, rs = [GridWorldState(2,3)], rv = [10.0])

    solver = ValueIterationSolver(verbose=true)
    policy = solve(solver, mdp)

    # up: 1, down: 2, left: 3, right: 4
    correct_policy = [1,1,1,1,4,1,1] # alternative policies
    # are possible, but since they are tied & the first
    # action is always 1, we will always return 1 for tied
    # actions
    return policy.policy == correct_policy
end

function test_init_solution()
    # Initialize the value to the solution
    rstates = [GridWorldState(4,3), GridWorldState(4,6), GridWorldState(9,3), GridWorldState(8,8)]
    rvals = [-10.0, -5.0, 10.0, 3.0]
    xs = 10
    ys = 10
    mdp = LegacyGridWorld(sx=xs, sy=ys, rs = rstates, rv = rvals)
    qt = readdlm("grid-world-10x10-Q-matrix.txt")
    ut = maximum(qt, dims=2)[:]
    solver = ValueIterationSolver(verbose=true, init_util=ut, belres=1e-3)
    policy = solve(solver, mdp)
    return isapprox(ut, policy.util, rtol=1e-5)
end

function test_not_include_Q()
    # Load correct policy from file and verify we can reconstruct it
    rstates = [GridWorldState(4,3), GridWorldState(4,6), GridWorldState(9,3), GridWorldState(8,8)]
    rvals = [-10.0, -5.0, 10.0, 3.0]
    xs = 10
    ys = 10
    mdp = LegacyGridWorld(sx=xs, sy=ys, rs = rstates, rv = rvals)
    qt = readdlm("grid-world-10x10-Q-matrix.txt")
    ut = maximum(qt, dims=2)[:]
    niter = 100
    res = 1e-3
    solver = ValueIterationSolver(verbose=true, init_util=ut, belres=1e-3, include_Q=false)
    policy = solve(solver, mdp)
    return isapprox(ut, policy.util, rtol=1e-3)
end

function test_type_stability()
    mdp = LegacyGridWorld()
    solver = ValueIterationSolver()
    @inferred solve(solver, mdp)
    return true
end

@test test_complex_gridworld() == true
@test test_simple_grid() == true
@test test_init_solution() == true
@test test_not_include_Q() == true
@test_throws String solve(ValueIterationSolver(), TigerPOMDP())
@test test_type_stability() == true
