function result = run_bruteforce(grid_def, data, opt, max_evals)
% RUN_BRUTEFORCE Exhaustive grid evaluation using costfun_wrapper
%   Execute a grid-based brute-force baseline using the same logging wrapper
%   used by optimizers so results are directly comparable.
%
%   Inputs:
%     grid_def - struct with vectors `Q`, `f0`, `A`, `K` describing grid
%     data     - preloaded data struct for costfun_LLC
%     opt      - options from optimization_defaults
%     max_evals - optional cap on number of evaluations (Inf for full grid)
%
%   Outputs:
%     result - struct with fields `best`, `tests`, and `grid_size`.

if nargin < 4 || isempty(max_evals)
    max_evals = Inf;
end

Qv = grid_def.Q;
f0v = grid_def.f0;
Av = grid_def.A;
Kv = grid_def.K;

% Build list of combinations
[Qg,f0g,Ag,Kg] = ndgrid(Qv,f0v,Av,Kv);
Xlist = [Qg(:), f0g(:), Ag(:), Kg(:)];
N = size(Xlist,1);

nrun = min(N, max_evals);

best.J = Inf;
best.x = [];

% Context for logging
ctx.alg = 'bruteforce'; ctx.run_id = 1;

for i = 1:nrun
    x = Xlist(i,:);
    [J, out] = costfun_wrapper(x, data, opt, ctx);
    if out.eval.J < best.J && out.eval.feasible
        best.J = out.eval.J;
        best.x = x;
        best.entry = out.eval;
    end
end

result.best = best;
result.tests = nrun;
result.grid_size = N;

end
