function res = run_optimizer(algorithm, data, opt, bounds, seed)
% RUN_OPTIMIZER Simple manager for running optimizers with unified logging
%   Thin manager that runs different MATLAB optimizers (`ga`,
%   `particleswarm`) with a shared `costfun_wrapper` logger so results are
%   comparable across algorithms. It maps `opt.max_evals` to optimizer
%   population/iteration settings and enforces a runtime cap using
%   `optimoptions('MaxTime',...)` where supported.
%
%   Inputs:
%     algorithm - string: 'ga' or 'particleswarm' (extendable)
%     data      - preloaded data struct for costfun_LLC
%     opt       - options (from optimization_defaults)
%     bounds    - struct with fields .Q .f0 .A .K containing [lb ub]
%     seed      - random seed (integer)
%
%   Output:
%     res - struct containing best solution, final objective, timing, and optimizer output

if nargin < 5, seed = 0; end
rng(seed);

nvars = 4;
lb = [bounds.Q(1), bounds.f0(1), bounds.A(1), bounds.K(1)];
ub = [bounds.Q(2), bounds.f0(2), bounds.A(2), bounds.K(2)];

ctx.alg = algorithm; ctx.run_id = seed;

% Build anonymous wrapped objective to match optimizer API
fun = @(x) costfun_wrapper(x, data, opt, ctx);

% The wrapper returns [J, out]. For optimizers we need to return scalar J.
obj = @(x) fun(x); % when called, costfun_wrapper will save logs

% Set a termination time (seconds)
maxTime = opt.max_time_seconds;

% --- Preliminary feasibility sampling ---
% Do a small random sample to detect completely-infeasible parameter spaces
init_N = min( max(10, round(opt.max_evals * 0.05)), 40 );
fprintf('  Preliminary sampling (%d points) to check feasibility...\n', init_N);
prelim_best = Inf; prelim_x = [];
feasible_count = 0;
for ii = 1:init_N
    xr = lb + rand(1,4) .* (ub - lb);
    % call numeric wrapper and extract scalar objective
    try
        Jtmp = obj_scalar(xr);
    catch ME
        warning('run_optimizer:PrelimEvalError','Prelim eval error: %s', ME.message);
        Jtmp = Inf;
    end
    if isfinite(Jtmp) && (Jtmp < opt.penalty.infeasible)
        feasible_count = feasible_count + 1;
        if Jtmp < prelim_best
            prelim_best = Jtmp; prelim_x = xr;
        end
    end
end

if feasible_count == 0
    warning('run_optimizer:NoFeasible','No feasible candidate in prelim sampling. Starting %s with random population.', algorithm);
else
    fprintf('  Found %d feasible candidates in preliminary sampling; best J = %.4f\n', feasible_count, prelim_best);
end


res = struct();
res.algorithm = algorithm;
res.seed = seed;
res.start_time = datetime('now');

switch lower(algorithm)
    case 'ga'
        % population sizing heuristic
        popsize = 40;
        maxgens = max(1, floor(opt.max_evals / popsize) - 1);
        options = optimoptions('ga', 'PopulationSize', popsize, 'MaxGenerations', maxgens, ...
            'UseParallel', true, 'Display', 'off', 'MaxTime', maxTime);
        % ga expects a function that returns scalar; our obj uses the wrapper which returns [J,out]
        % so we supply a small wrapper
        ga_fun = @(x) obj_scalar(x);
        IntCon = [];
        try
            [xbest,fbest,exitflag,output] = ga(ga_fun, nvars, [],[],[],[], lb, ub, [], IntCon, options);
        catch ME
            warning('run_optimizer:GAError','GA failed: %s', ME.message);
            xbest = []; fbest = Inf; output = []; exitflag = -1;
        end
        res.xbest = xbest; res.fbest = fbest; res.exitflag = exitflag; res.output = output;
    case 'particleswarm'
        swarm = 40;
        maxit = max(1, floor(opt.max_evals / swarm) - 1);
        options = optimoptions('particleswarm','SwarmSize',swarm,'MaxIterations',maxit,'UseParallel',true,'Display','off','MaxTime',maxTime);
        try
            [xbest,fbest,exitflag,output] = particleswarm(@(x) obj_scalar(x), nvars, lb, ub, options);
        catch ME
            warning('run_optimizer:PSOError','Particle swarm failed: %s', ME.message);
            xbest = []; fbest = Inf; output = []; exitflag = -1;
        end
        res.xbest = xbest; res.fbest = fbest; res.exitflag = exitflag; res.output = output;
    otherwise
        error('run_optimizer:UnknownAlg','Unknown algorithm %s', algorithm);
end

res.end_time = datetime('now');

    function f = obj_scalar(x)
        % helper to call costfun_wrapper and return scalar objective
        [J, out] = costfun_wrapper(x, data, opt, ctx);
        % costfun_wrapper saves logs; return scalar J
        f = J;
    end

end
