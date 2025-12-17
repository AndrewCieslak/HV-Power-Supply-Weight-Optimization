function [J, feasible, details] = costfun_LLC(x, data, opt)
% COSTFUN_LLC Evaluate total weight for LLC decision vector x = [Q, f0, A, K]
%   This function is a deterministic cost function that wraps the existing
%   transformer and inductor evaluators (`Ecore_actual_EEER_xfmer_LCC` and
%   `Ecore_actual_EEER_inductor_LCC`) and returns a scalar objective `J`.
%
%   Outputs:
%     J        - scalar objective to minimize (total weight in grams, with
%                penalties added for infeasible designs)
%     feasible - logical flag indicating whether design met constraints
%     details  - struct containing weights, losses, GT, Imax and full
%                evaluator outputs for logging and later analysis
%
%   Intended usage: called by `costfun_wrapper` and optimization drivers
%   (e.g., `run_bruteforce` and `run_optimizer`). Do not perform file I/O
%   inside this function; pass preloaded `data` to avoid repeated Excel reads.
%
% Inputs:
%   x     - 1x4 vector [Q, f0, A, K]
%   data  - struct containing the preloaded inputs and constants used by
%           the existing DriverForLLC (raw, raw1..raw6, Vin, Vo, Po, etc.)
%   opt   - options struct from optimization_defaults (for penalties)
%
% Outputs:
%   J      - scalar objective (minimize). Total weight in grams (plus any penalty)
%   feasible - logical true/false whether both transformer & inductor succeeded
%   details  - struct with metrics for logging (weightX, weightL, losses, GT, Imax,...)

% Unpack x
Q = x(1);
f0 = x(2);
A = x(3);
K = x(4);

% Validate required fields in data
requiredFields = {'raw','raw1','raw2','raw3','raw4','raw5','raw6','Vin','Vo','Po'};
for k = 1:numel(requiredFields)
    if ~isfield(data, requiredFields{k})
        error('costfun_LLC:MissingData','data.%s is required', requiredFields{k});
    end
end

% Use the same shorthand names used in DriverForLLC
Vin_range = data.Vin;
Vo_range = data.Vo;
Po_range = data.Po;
fs_range = f0; % follow Driver's convention: set switching frequency equal to f0

% Compute tank parameters (scalars)
Req = (Vo_range./sqrt(2)).^2./Po_range;    % equivalent load across secondary
RT = Req./(K.^2);
Ls = RT./(2*pi.*f0.*Q);
Cs = Q.*(A+1)./(A*2*pi.*f0.*RT);
Cp = Q.*(A+1)./(2*pi.*f0.*RT);

% Transfer function gain GT (small-signal) -- copy the expression
GT = (4/pi) ./ ( sqrt((1+A).^2 .* (1 - (fs_range./f0).^2).^2 + 1./Q.^2 .* (fs_range./f0 - A.*f0./((A+1).*fs_range)).^2) );

% Maximum current through resonant tank
Imax = (Vin_range .* GT ./ RT) .* sqrt(1 + (fs_range./f0).^2 .* Q.^2 .* (A+1).^2);

% Default details
details = struct();
details.Q = Q; details.f0 = f0; details.A = A; details.K = K;
details.GT = GT; details.Imax = Imax; details.Ls = Ls; details.Cs = Cs; details.Cp = Cp;

% Check GT*K bounds based on DriverForLLC logic
lower_gain = Vo_range ./ Vin_range;
upper_gain = 1.2 * Vo_range ./ Vin_range;
feasible = true;
penalty = 0;
if ~(GT * K >= lower_gain && GT * K <= upper_gain && GT > 1)
    feasible = false;
    % compute violation magnitude and add a scaled penalty
    viol_low = max(0, lower_gain - GT*K);
    viol_high = max(0, GT*K - upper_gain);
    penalty = penalty + opt.penalty.GTK_scale * (viol_low + viol_high);
end

% Compute Vpri and Vsec for transformer
Vpri = Vin_range .* GT;
Vsec = Vin_range .* GT .* K;
Vinsulation_max = Vsec;

% Parallel capacitive reactance
XCp = 1/(2*pi*fs_range*Cp);

% Call transformer evaluator
try
    SuceedX = Ecore_actual_EEER_xfmer_LCC(data.raw,data.raw1,data.raw2,data.raw3,data.raw4,data.raw5,data.raw6, ...
        Vpri, Vsec, Po_range, fs_range, Vinsulation_max, data.Winding_Pattern, ...
        data.layerTapeUse, data.enamelThickness, data.kaptonDielStrength, data.kaptonThickness, ...
        data.MinTapeMargin, data.kaptonDensity, data.CoreInsulationDensity, data.WireInsulationDensity, ...
        data.dielectricstrength_insulation, data.etaXfmer, data.TmaxX, data.TminX, data.MinPriWindingX, ...
        data.MaxPriWindingX, data.IncreNpX, data.MaxMlpX, data.IncreMlpX, data.MaxMlsX, data.IncreMlsX, data.MaxWeightX, ...
        data.BSAT_discountX, data.CoreLossMultipleX, data.maxpackingfactorX, data.minpackingfactorX, ...
        data.LitzFactor, data.MinWireDia, data.Jwmax, data.MinLitzDia, data.CopperDensity, data.rou, data.u0, XCp);
catch ME
    % If the evaluator throws, mark infeasible and large penalty
    warning('costfun_LLC:TransformerError','Transformer evaluator error: %s', ME.message);
    SuceedX = zeros(1,43);
end

% Call inductor evaluator
try
    SuceedL = Ecore_actual_EEER_inductor_LCC(data.raw,data.raw1,data.raw2,data.raw3,data.raw4,data.raw5,data.raw6, ...
        Vin_range, GT, Po_range, fs_range, Ls, Imax, data.Winding_Pattern, ...
        Q, f0, A, K, RT, Ls, Cs, Cp, GT, data.layerTapeUse, data.enamelThickness, data.kaptonDielStrength, data.kaptonThickness, ...
        data.MinTapeMargin, data.kaptonDensity, data.CoreInsulationDensity, data.WireInsulationDensity, data.dielectricstrength_insulation, ...
        data.etaInductor, data.TmaxL, data.TminL, data.MaxWeightL, data.mingap, data.MinWindingL, data.MaxWindingL, data.IncreNL, ...
        data.MaxMlL, data.IncreMlL, data.BSAT_discountL, data.CoreLossMultipleL, data.maxpackingfactorL, data.minpackingfactorL, data.CuMultL, ...
        data.LitzFactor, data.MinWireDia, data.Jwmax, data.MinLitzDia, data.CopperDensity, data.rou, data.u0);
catch ME
    warning('costfun_LLC:InductorError','Inductor evaluator error: %s', ME.message);
    SuceedL = zeros(1,38);
end

% Extract weights and loss metrics (guarded)
weightX = 0; weightL = 0;
if isnumeric(SuceedX) && numel(SuceedX) >= 36 && ~all(SuceedX==0)
    weightX = SuceedX(36);
else
    feasible = false;
end
if isnumeric(SuceedL) && numel(SuceedL) >= 23 && ~all(SuceedL==0)
    weightL = SuceedL(23);
else
    feasible = false;
end

% Raw objective (sum of weights)
Jraw = weightX + weightL;

% Final objective with penalties
if ~feasible
    J = Jraw + opt.penalty.infeasible + penalty;
else
    J = Jraw + penalty; % typically penalty==0 here
end

% Populate details for logging
details.weightX = weightX;
details.weightL = weightL;
details.Jraw = Jraw;
details.SuceedX = SuceedX;
details.SuceedL = SuceedL;

details.feasible = feasible;

details.penalty = penalty;

end
