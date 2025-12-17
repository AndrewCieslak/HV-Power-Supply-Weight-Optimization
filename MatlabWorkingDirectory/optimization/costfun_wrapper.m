function [J, out] = costfun_wrapper(x, data, opt, ctx)
% COSTFUN_WRAPPER Logging wrapper around costfun_LLC
%   Wrapper that calls `costfun_LLC`, records timing, and appends a log
%   entry to an in-memory persistent log. Periodically writes a partial
%   `.mat` file to `opt.results_folder` so runs can be resumed or inspected.
%
%   Inputs:
%     x   - decision vector
%     data - preloaded data struct required by costfun_LLC
%     opt  - options (from optimization_defaults)
%     ctx  - context struct with fields `alg` and `run_id` used for filenames
%
%   Outputs:
%     J   - scalar objective (returned from costfun_LLC)
%     out - struct containing the most recent eval entry and accumulated log
%
%   Note: keep this wrapper lightweight and avoid heavy I/O inside the
%   objective evaluation; saving is periodic and minimal to prevent slowdown.

persistent eval_count log_entries start_time
if isempty(eval_count)
    eval_count = 0;
    log_entries = [];
    start_time = tic;
end

eval_count = eval_count + 1;
this_eval = eval_count;

tstart = tic;
[lastWarnBeforeMsg, lastWarnBeforeId] = lastwarn();
% Temporarily suppress warnings to avoid flooding the console during optimizer runs.
% We capture the last warning text after the eval so it can be logged for debugging.
warning('off','all');
lastwarn('');
[J, feasible, details] = costfun_LLC(x, data, opt);
% capture any warning message emitted during the evaluation
[lastWarnAfterMsg, lastWarnAfterId] = lastwarn();
% restore warnings
warning('on','all');
if ~isempty(lastWarnAfterMsg)
    details.suppressedWarning = lastWarnAfterMsg;
else
    details.suppressedWarning = '';
end
% restore previous lastwarn (best-effort)
if ~isempty(lastWarnBeforeMsg)
    lastwarn(lastWarnBeforeMsg, lastWarnBeforeId);
else
    lastwarn('');
end
telapsed = toc(tstart);

entry.eval = this_eval;
entry.timestamp = datetime('now');
entry.x = x;
entry.J = J;
entry.Jraw = details.Jraw;
entry.feasible = feasible;
entry.weightX = details.weightX;
entry.weightL = details.weightL;
entry.GT = details.GT;
entry.Imax = details.Imax;
entry.time_s = telapsed;
entry.details = details; %#ok<STRNU>
if isfield(details,'suppressedWarning') && ~isempty(details.suppressedWarning)
    entry.suppressedWarning = details.suppressedWarning;
else
    entry.suppressedWarning = '';
end

if isempty(log_entries)
    log_entries = entry;
else
    log_entries(end+1) = entry; %#ok<AGROW>
end

%{
% Save periodically
if ~exist(opt.results_folder,'dir')
    mkdir(opt.results_folder);
end

% Build filename
if nargin < 4 || ~isfield(ctx,'alg') || ~isfield(ctx,'run_id')
    fname = fullfile(opt.results_folder, sprintf('eval_log_run.mat'));
else
    fname = fullfile(opt.results_folder, sprintf('%s_eval_log.mat', ctx.alg));
end

% Save only the log_entries and a summary to file to avoid huge files
summary.best_so_far = min([log_entries.J]);
summary.evals = numel(log_entries);
summary.last_time = toc(start_time);
save(fname, 'log_entries', 'summary');
%}

% Return optional info
out.eval = entry;
out.log = log_entries;

end
