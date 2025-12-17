function opt = optimization_defaults()
% OPTIMIZATION_DEFAULTS Default bounds and benchmarking settings for LLC optimization
%   This file returns a struct `opt` containing tunable bounds, brute-force
%   grid defaults, penalty parameters, and benchmarking budgets used by the
%   optimization helpers in `MatlabWorkingDirectory/optimization/`.
%
%   Usage:
%     opt = optimization_defaults();
%
%   Edit the returned fields (bounds, max_time_seconds, bruteforce.grid, etc.)
%   to change optimization behavior.

% Variable bounds (tunable)
opt.bounds.Q = [0.2, 1.0];            % Quality factor
opt.bounds.f0 = [20e3, 30e3];        % Resonant frequency (Hz)
opt.bounds.A = [0.1, 1.0];            % Capacitance ratio
opt.bounds.K = [1.0, 10.0];           % Turns ratio (secondary/primary)

% Budget and timing
opt.max_time_seconds = 120;           % 2 minutes per optimization run
opt.max_evals = 1500;                % fallback maximum function evaluations
opt.repeats = 5;                     % repeats for stochastic algorithms

% Brute-force grid defaults (coarse baseline)
opt.bruteforce.grid.Q = linspace(opt.bounds.Q(1), opt.bounds.Q(2), 6);
opt.bruteforce.grid.f0 = linspace(opt.bounds.f0(1), opt.bounds.f0(2), 6);
opt.bruteforce.grid.A = linspace(opt.bounds.A(1), opt.bounds.A(2), 6);
opt.bruteforce.grid.K = linspace(opt.bounds.K(1), opt.bounds.K(2), 6);

% Penalty settings
opt.penalty.infeasible = 1e6;        % large gram penalty for infeasible designs
opt.penalty.GTK_scale = 1e5;         % scale for GT*K bound violations

% Logging / results folder
opt.results_folder = fullfile(pwd, 'MatlabWorkingDirectory', 'optimization', 'results');

end
