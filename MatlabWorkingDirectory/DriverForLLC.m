clc, clf, clear

corelossfile = 'CoreLossDataOLD.xlsx';
coresizefile = 'CoreSizeData.xlsx';
coresizeSheetname = 'OwnedCores';

raw1 = readcell(corelossfile,'Sheet','Freq');
raw2 = readcell(corelossfile,'Sheet','Bfield');
raw3 = readcell(corelossfile,'Sheet','Ploss');
raw4 = readcell(corelossfile,'Sheet','BSAT');
raw5 = readcell(corelossfile,'Sheet','MU');
raw6 = readcell(corelossfile,'Sheet','Density');

% Ecore is the larger, perhaps inaccurate dataset, while ReviewedCores is a
% manually vetted selection of cores. OwnedCores is the 3 cores we own.
raw = readcell(coresizefile,'Sheet',coresizeSheetname);

%% Parameters to Adjust
%--------------------------------------------------------------------------

% Magnetizing inductance is assumed "large enough" as explained in the
% thesis, with A being the capacitance parallel vs. series ratio i.e.
% the inductance leakage vs. magnetizing ratio.

% Really, since leakage and magnetizing inductance aren't used in the code
% provided by the thesis and thus the output, the only things that matter
% from the output when actually building a core is the Ls, Cs, Cp, frequency,
% input voltage, output power, number of layers, and turns ratio. As long as 
% the script returns a positive result, it means I can make a set of
% magnetics with those parameters. During the design process,
% I only really care about it giving me the component values, the physical
% characteristics vary so much and are determined based on the electrical
% characteristics that are needed. The estimations of weight, winding
% number, etc. are all estimates for comparison tables so we don't have to
% make a bunch of transformers and inductors. The actual design process is
% much simpler, and different. Magnetizing inductance and leakage
% inductance is important for design but not the graphs, so I should add
% that so this script can be used for both.

% ui is assumed for ur in all equations.

% magnetizing inductance, parallel capacitance, and leakage inductance aren't limited, since they
% may help soft switching operation (source needed). Lleak, Cpara, and
% Lmag are not constrained. Fortunately, m-value matches for both
% capacitance and inductance ratio.

% NEED TO CHECK IF MAGNETIZING INDUCTANCE AND LEAKAGE INDUCTANCE EFFECTS
% ARE MODELED IN THIS SCRIPT!! 299-305 in XFMER
% Check if inductor Imax accounts for magnetizing current
% GPT told me this, it might be wrong:
    % Need to account for magnetizing rms current:
    %   Im_rms = Vp_rms / (omega * Lm);
    % And leakage energy loss
    %   Pleak = 0.5 * Lleak * Ipk^2 * fsw; 
    % And ZVS condition
    %   0.5*Lm*Im_peak^2 >= 0.5*Ceq*Vbus^2
    % And circulating current in copper loss

% For litz, the main AWG is an equivalent for the whole bundle.

Date = '11-13-25';
% Quality factor
Q_range = 0.2:0.1:1;
% Resonant frequency
f0_range = 25000;
% frequency of the transformer
fs_range = f0_range;

% Capacitance ratio (inverse of inductance ratio) (shouldn't be lower than 0.1,
% since ZVS bandwidth becomes too small)
A_range = linspace(0.1,1,20);
% DC input voltage range (unipolar peak) (if Vppeak is the param. to select around,
% keep GT ~1, but optimal weight is usually achieved with tank gain of ~2)
Vin_range = 5;
% Peak of the output voltage that one hope to achieve (V)
% peak to peak is 2x this value
Vo_range = 50;
% Output power desired (W)
Po_range = 10;
% Turns ratio secondary/primary
K_range = 1:1:10;

% Insulation
%-------------------------------------------

% Use interlayer tape instead of full wire jacket ratings?
layerTapeUse = true;
enamelThickness = 20e-6;
kaptonDielStrength = 0.5*200e5; % V/m derated 50%
kaptonThickness = 60e-6; % m
MinTapeMargin = 5e-4;
kaptonDensity = 1.42e6; % g/m^3

% Core sheath insulation
CoreInsulationDensity = 2.2e6;       % g/m^3 (Teflon)
WireInsulationDensity = 2.2e6;       % g/m^3 (Teflon)
% Dielectric strength of core insulation material (V/m) 50% derated
dielectricstrength_insulation = 0.5 * 200e5;


% Inductor parameters
%-------------------------------------------

    % Lowest allowed inductor efficiency
    etaInductor = 0.98;
    % Max allowable temperature (C)
    TmaxL = 100;
    % Min allowable temperature (C)
    TminL = 25;
    % Maximum allowable weight (g)
    MaxWeightL = 1000;
    % Air gap (m)
    mingap = 0;
    
    % Winding and Wire Parameters
    %------------------------------------------
    
    % Minimum turns
    MinWindingL = 1;
    % Maximum turns
    MaxWindingL = 200;
    % Incremental winding
    IncreNL = 1;
    % Maximum layer of winding
    MaxMlL = 10;
    % Incremental layers. The layers of a transformer reference each wrap of
    % turns that fills the window height before moving on to the next level.
    % Once one layer fills, the next layer is wound on top, seperated by an
    % insulation layer.
    IncreMlL = 1;

    % Copper wire multiple to reduce resistive losses
    CuMultL = 1;
    
    % Discount factors
    %----------------------------------------
    
    % Bmax discount factor
    BSAT_discountL = 0.75;
    % Actual core loss is always higher than the calculated
    CoreLossMultipleL = 1;
    % Maximum packing factor (copper area compared with total window area)
    maxpackingfactorL = 0.7;
    % Minimum packing factor
    minpackingfactorL = 0.01;


% Transformer parameters
%-------------------------------------------
    
    % Minimum transformer efficiency
    etaXfmer = 0.95;
    % Max operating temp in Celsius
    TmaxX = 100;
    % Min operating temp in Celsius
    TminX = 25;
    % Minimum primary windings
    MinPriWindingX = 1;
    % Maximum primary windings
    MaxPriWindingX = 200;
    % Incremental primary winding
    IncreNpX = 1;
    % Maximum layer of primary winding
    MaxMlpX = 5;
    % Incremental layer of primary winding
    IncreMlpX = 1;
    % Maximum layer of secondary winding
    MaxMlsX = 25;
    % Incremental layer of secondary winding
    IncreMlsX = 1;
    % Max allowable transformer weight (g)
    MaxWeightX = 1000;

    % Deratings
    %------------------------------------------
    
    % Saturation flux density derating
    BSAT_discountX = 0.75;
    % Core loss multiplier
    CoreLossMultipleX = 1;
    maxpackingfactorX = 0.7;
    minpackingfactorX = 0.01;



% Winding factor of litz wire, assuming only 80% of wire size is copper
% (the rest is air and enamel between parallel wires)
LitzFactor = 0.6;
% Minimal wire diameter (m)
MinWireDia = 0.25/1000; % AWG28, 0.35 mm is AWG29, 0.079 is AWG40
% Max allowable current density in the wire (A/m^2)
% 500A/cm^2 is the upper bound recommended, but without active cooling, and
% since the magnetics are thermally insulated, less is assumed
Jwmax = 3e6;
% Minimal litz diameter one can get (m)
MinLitzDia = 0.05024 / 1000; % AWG44 % 0.0316 is AWG48, 0.03983 is AWG46
% g/m^3, density of copper
CopperDensity = 8.96*1000*1000;
% Electrical constants. Normally there is no need to change
% ohm*m, resistivity of copper at 100C
rou = 2.3*1e-8;
% H/A·m^2, permeability of free space
u0 = 4*pi*10^(-7);


% Winding Pattern index: 1 indicates center leg winding, 2 indicates double
Winding_Pattern = 1;
% Hypothesis: record why you want to run the sim
Hypothesis ='';
% Notes: record any changes you made to the code
Notes ='';



%% File Output
%-------------------------------------------------------------------------------

% File output configuration
filename_xfmer = strcat(Date,'_','Xfmer.xlsx');
filename_inductor = strcat(Date,'_','Inductor.xlsx');
SheetNumber = 1;
Infosheetname = strcat('SimInfo', num2str(SheetNumber));
ResultDatasheetname = strcat('ResultsData', num2str(SheetNumber));

field1 = 'name';
value1_req = {'Date','Hypothesis','Notes',...
    'Q_range','fO_range','A_range','K_range',...
    'Vin_range','Vo_range','Po_range','fs_range','Winding_Pattern'};
field2 = 'data';
value2_req = {Date,Hypothesis, Notes,...
    Q_range, f0_range , A_range, K_range,...
    Vin_range, Vo_range, Po_range,fs_range , Winding_Pattern};
Requirement = struct(field1,value1_req,field2,value2_req);
fn   = fieldnames(Requirement);
vals = struct2cell(Requirement);

% Places input variable ranges and values in sheet named "SimInfo"
for i = 1:numel(vals)
    v = vals{i};
    if isnumeric(v) || islogical(v)
        if isscalar(v), vals{i} = v; else, vals{i} = mat2str(v); end
    elseif isstring(v) || ischar(v)
        vals{i} = char(v);
    else
        vals{i} = jsonencode(v);
    end
end
T = table(fn, vals, 'VariableNames', {'Field','Value'});
writetable(T, filename_xfmer, 'Sheet', Infosheetname, 'WriteVariableNames', true);

%% Calculations
%------------------------------------------------------------------------------

% First, resonant tank parameters are calculated

% Creates 4-D array of these 4 ranges. Each output is the size of all 4
% multiplied together. The reshape() just flattens each 4-D array into a
% column vector (turns ?x?x?x? into 4?x1)
[Q,f0,A,K] = ndgrid(Q_range, f0_range, A_range, K_range);
Q = reshape(Q,[],1);
f0 = reshape(f0,[],1);
A = reshape(A,[],1);
K = reshape(K,[],1);

% All of the following calculations are computed for each element in the
% matrix individually via the A.^B, A.*B, etc. operator. The sizes of A and B
% in A.^B must be equal or compatible. This allows for a large amount of
% independent values to be computed in a compact format.

% Equivalent resistance across secondary (from output p and output v)
Req = (Vo_range./sqrt(2)).^2./Po_range;
% Resonant tank reflected load resistance
RT = Req./K.^2;
% Series inductance of the resonant tank
Ls = RT./(2*pi.*f0.*Q);
% Series capacitance of LLC network
Cs = Q.*(A+1)./(A*2*pi.*f0.*RT);
% Parallel capacitance of LLC network
Cp = Q.*(A+1)./(2*pi.*f0.*RT);
% Transfer function gain factor; small-signal tank gain
GT = (4/pi)./(sqrt((1+A).^2.*(1-(fs_range./f0).^2).^2+1./Q.^2.*(fs_range./f0-A.*f0./((A+1).*fs_range)).^2));
% Maximum current through resonant tank
Imax = (Vin_range.*GT./RT).*sqrt(1+(fs_range./f0).^2.*Q.^2.*(A+1).^2);


% If effective gain GT.*K is within 20% of required gain, the design is
% acceptable. If not, index ignored. If all are ignored, error is thrown.
KeepIndex = intersect(find(GT.*K>=Vo_range./Vin_range),find(GT.*K<=1.2*Vo_range./Vin_range));
KeepIndex = intersect(KeepIndex,find(GT > 1));
if isempty(KeepIndex)
    error('Driver:NoCandidates', ...
          'No design points satisfy GT*K and GT>1. Adjust Vin/Vo/K/A/Q/f0.');
end

% Operating points not ignored are kept.
Q=Q(KeepIndex);
f0 = f0(KeepIndex);
A= A(KeepIndex);
K= K(KeepIndex);
RT = RT(KeepIndex);
Ls = Ls(KeepIndex);
Cs = Cs(KeepIndex);
Cp = Cp(KeepIndex);
GT = GT(KeepIndex);
Imax = Imax(KeepIndex);

% Loops over every row of the 4-D grid, with tic-toc measuring total
% runtime.
%-------------------------------------------
tic
NumPoints = length(Q);

% --- Pre-Allocation
% Initialization of zero matrix
ResultX = zeros(NumPoints, 43); 
ResultL = zeros(NumPoints, 38);
toc


tic
parfor i = 1:NumPoints
    
    % Peak voltage applied to primary from the input and resonant tank gain.
    Vpri = Vin_range.*GT(i);
    % Peak output voltage on the transformer after turn ratio K
    Vsec = Vin_range.*GT(i).*K(i);
    % Maximum insulation stress
    Vinsulation_max = Vsec;

    % Parallel capacitive reactance
    XCp = 1/(2.*pi.*fs_range.*Cp);

    % Run Xfmer design, return design vector. All CoreLoss and CoreSize
    % data is passed, along with primary voltage, secondary voltage, output
    % power goal, switching frequency goal, max insulation stress, and^
    % winding pattern. None of the resonant tank sweep values are passed
    % here. Only the GT and K are relevant for the transformer design and
    % are what are being sweeped within this for loop through Vpri, Vinsulation_max,
    % and Vsec.
    SuceedX = Ecore_actual_EEER_xfmer_LCC(raw,raw1,raw2,raw3,raw4,raw5,raw6,...
        Vpri, Vsec, Po_range, fs_range, Vinsulation_max, Winding_Pattern,...
        layerTapeUse,enamelThickness,kaptonDielStrength,kaptonThickness,...
        MinTapeMargin,kaptonDensity,CoreInsulationDensity,WireInsulationDensity, ...
        dielectricstrength_insulation,etaXfmer,TmaxX,TminX,MinPriWindingX, ...
        MaxPriWindingX,IncreNpX,MaxMlpX,IncreMlpX,MaxMlsX,IncreMlsX,MaxWeightX, ...
        BSAT_discountX,CoreLossMultipleX,maxpackingfactorX,minpackingfactorX, ...
        LitzFactor,MinWireDia,Jwmax,MinLitzDia,CopperDensity,rou,u0,XCp);
    
    % Run Inductor design, return design table. All CoreLoss and CoreSize
    % data is passed, along with input voltage range (DC), output power
    % goal, switching frequency goal, winding pattern, and the resonant
    % tank sweep values.
    SuceedL = Ecore_actual_EEER_inductor_LCC(raw,raw1,raw2,raw3,raw4,raw5,raw6,...
        Vin_range,GT(i),Po_range,fs_range,Ls(i),Imax(i), Winding_Pattern,...
        Q(i), f0(i), A(i), K(i), RT(i), Ls(i), Cs(i), Cp(i), GT(i), ...
        layerTapeUse,enamelThickness,kaptonDielStrength,kaptonThickness,...
        MinTapeMargin,kaptonDensity,CoreInsulationDensity,WireInsulationDensity, ...
        dielectricstrength_insulation,etaInductor,TmaxL,TminL,MaxWeightL,mingap, ...
        MinWindingL,MaxWindingL,IncreNL,MaxMlL,IncreMlL,BSAT_discountL, ...
        CoreLossMultipleL,maxpackingfactorL,minpackingfactorL,CuMultL,...
        LitzFactor,MinWireDia,Jwmax,MinLitzDia,CopperDensity,rou,u0);
    
    % Successful result vector of many columns and 1 row for transformer and inductor are saved
    ResultX(i,:) = SuceedX;
    ResultL(i,:) = SuceedL;
    % Sliced variables in parallel loops allow this ResultX and ResultL to exist outside the
    % parfor loop.
end
toc

% -------------------------------------------------------------------------
% Optimization/benchmarking integration (uses helpers in optimization/)
% -------------------------------------------------------------------------

% Ensure optimization helpers are on the path
thisFolder = fileparts(mfilename('fullpath'));        % folder containing DriverForLLC.m
opt_dir    = fullfile(thisFolder, 'optimization');    % sibling optimization folder

if ~isfolder(opt_dir)
    error('Expected optimization folder not found: %s', opt_dir);
end

% add to path if not already present
if isempty(strfind(path, opt_dir))                     % simple contains check
    addpath(opt_dir);
end

% verify the file exists and then load defaults
if exist(fullfile(opt_dir,'optimization_defaults.m'),'file') == 2
    opt = optimization_defaults();
else
    error('optimization_defaults.m not found in: %s', opt_dir);
end

% (optimization folder already added above; opt already loaded)

% Build data struct for costfun_LLC and wrappers
data.raw = raw; data.raw1 = raw1; data.raw2 = raw2; data.raw3 = raw3;
data.raw4 = raw4; data.raw5 = raw5; data.raw6 = raw6;
data.Vin = Vin_range; data.Vo = Vo_range; data.Po = Po_range;

% common params passed to evaluators (copy from this script)
data.Winding_Pattern = Winding_Pattern;
data.layerTapeUse = layerTapeUse; data.enamelThickness = enamelThickness;
data.kaptonDielStrength = kaptonDielStrength; data.kaptonThickness = kaptonThickness;
data.MinTapeMargin = MinTapeMargin; data.kaptonDensity = kaptonDensity;
data.CoreInsulationDensity = CoreInsulationDensity; data.WireInsulationDensity = WireInsulationDensity;
data.dielectricstrength_insulation = dielectricstrength_insulation;

% Transformer params
data.etaXfmer = etaXfmer; data.TmaxX = TmaxX; data.TminX = TminX;
data.MinPriWindingX = MinPriWindingX; data.MaxPriWindingX = MaxPriWindingX;
data.IncreNpX = IncreNpX; data.MaxMlpX = MaxMlpX; data.IncreMlpX = IncreMlpX;
data.MaxMlsX = MaxMlsX; data.IncreMlsX = IncreMlsX; data.MaxWeightX = MaxWeightX;
data.BSAT_discountX = BSAT_discountX; data.CoreLossMultipleX = CoreLossMultipleX;
data.maxpackingfactorX = maxpackingfactorX; data.minpackingfactorX = minpackingfactorX;

% Inductor params
data.etaInductor = etaInductor; data.TmaxL = TmaxL; data.TminL = TminL;
data.MaxWeightL = MaxWeightL; data.mingap = mingap;
data.MinWindingL = MinWindingL; data.MaxWindingL = MaxWindingL; data.IncreNL = IncreNL;
data.MaxMlL = MaxMlL; data.IncreMlL = IncreMlL;
data.BSAT_discountL = BSAT_discountL; data.CoreLossMultipleL = CoreLossMultipleL;
data.maxpackingfactorL = maxpackingfactorL; data.minpackingfactorL = minpackingfactorL;
data.CuMultL = CuMultL;

% Wire & physics
data.LitzFactor = LitzFactor; data.MinWireDia = MinWireDia; data.Jwmax = Jwmax;
data.MinLitzDia = MinLitzDia; data.CopperDensity = CopperDensity;
data.rou = rou; data.u0 = u0;

% Create results folder
if ~exist(opt.results_folder,'dir'), mkdir(opt.results_folder); end

% --- 1) Full brute-force optimum derived from computed ResultX/ResultL ---
% Combine weights where both transformer and inductor produced non-zero rows
totalWeights = Inf(size(ResultX,1),1);
for ii = 1:size(ResultX,1)
    rx = ResultX(ii,:);
    rl = ResultL(ii,:);
    if ~all(rx==0) && ~all(rl==0)
        wX = rx(36);
        wL = rl(23);
        totalWeights(ii) = wX + wL;
    end
end
[minW, minIdx] = min(totalWeights);
if isfinite(minW)
    bf_full.best.J = minW;
    bf_full.best.x = [Q(minIdx), f0(minIdx), A(minIdx), K(minIdx)];
    bf_full.best.idx = minIdx;
    save(fullfile(opt.results_folder,'bruteforce_full_best.mat'),'bf_full');
    fprintf('\nFull brute-force best total weight = %.3f g at Q=%.3g f0=%.3g A=%.3g K=%.3g\n', ...
        bf_full.best.J, bf_full.best.x(1), bf_full.best.x(2), bf_full.best.x(3), bf_full.best.x(4));
else
    fprintf('\nFull brute-force found no feasible designs.\n');
end

% --- 2) Timed brute-force (2 seconds) using costfun_wrapper to log ---
ctx.alg = 'bruteforce_timed'; ctx.run_id = round(posixtime(datetime('now')));
best_timed.J = Inf; best_timed.x = [];
deadline_secs = 2; % seconds
startTime = tic;
i = 1;
% Use parfeval + wait(timeout) when a parallel pool is available so we can
% cancel long-running evaluations and respect the overall deadline. If no
% pool is present, fall back to sequential calls (best-effort timing).
poolobj = gcp('nocreate');
while i <= length(Q)
    remaining = deadline_secs - toc(startTime);
    if remaining <= 0
        break;
    end
    x = [Q(i), f0(i), A(i), K(i)];
    if ~isempty(poolobj)
        % run evaluation on the pool and wait with timeout = remaining
        f = parfeval(poolobj, @costfun_wrapper, 2, x, data, opt, ctx);
        % Some MATLAB versions/platforms can throw when calling wait(f,timeout).
        % Use a safe polling loop that checks IsFinished and enforces timeout.
        t0 = tic;
        finished = false;
        while toc(t0) < remaining
            % Some MATLAB versions expose 'State' rather than IsFinished.
            % Check for a 'State' property first, otherwise try IsDone.
            if isprop(f, 'State')
                if strcmp(f.State, 'finished')
                    finished = true;
                    break;
                end
            elseif isprop(f, 'IsDone')
                if f.IsDone
                    finished = true;
                    break;
                end
            else
                % Last resort: attempt to fetchOutputs with zero timeout
                % in a try block; if it succeeds the future finished.
                try
                    if ~isempty(f.Tasks) && strcmp(f.Tasks(1).State,'finished')
                        finished = true; break;
                    end
                catch
                    % cannot determine; continue polling
                end
            end
            pause(0.05);
        end
        if ~finished
            % timed out; cancel the future and stop
            try cancel(f); catch; end
            break;
        end
        try
            [Jval, out] = fetchOutputs(f);
        catch ME
            warning('DriverForLLC:TimedBruteEval','Failed to fetch outputs: %s', ME.message);
            break;
        end
    else
        % No parallel pool: run inline (cannot preempt mid-eval). This may
        % overrun the deadline by at most one evaluation.
        [Jval, out] = costfun_wrapper(x, data, opt, ctx);
    end

    if out.eval.feasible && out.eval.J < best_timed.J
        best_timed.J = out.eval.J; best_timed.x = x; best_timed.entry = out.eval;
    end
    i = i + 1;
end
fprintf('\nTimed brute-force evaluated %d designs in %.2f seconds.\n', i-1, toc(startTime));
save(fullfile(opt.results_folder,'bruteforce_timed_best.mat'),'best_timed');
if isfinite(best_timed.J)
    fprintf('Timed brute-force (%.1fs) best J = %.3f at Q=%.3g f0=%.3g A=%.3g K=%.3g\n', ...
        deadline_secs, best_timed.J, best_timed.x(1), best_timed.x(2), best_timed.x(3), best_timed.x(4));
else
    fprintf('Timed brute-force (%.1fs) found no feasible designs.\n', deadline_secs);
end

% --- 3) Run optimizers (GA and Particle Swarm) with unified logging ---
bounds.Q = opt.bounds.Q; bounds.f0 = opt.bounds.f0; bounds.A = opt.bounds.A; bounds.K = opt.bounds.K;
fprintf('\nRunning GA (seed=1) ...\n');
t_ga = tic;
res_ga = run_optimizer('ga', data, opt, bounds, 1);
time_ga = toc(t_ga);
fprintf('GA completed in %.2f seconds.\n', time_ga);
save(fullfile(opt.results_folder,'res_ga.mat'),'res_ga');

if isfield(res_ga,'fbest') && isfinite(res_ga.fbest)
    if isfield(res_ga,'xbest') && ~isempty(res_ga.xbest)
        fprintf('GA best total weight = %.3f g at [Q f0 A K] = [%.3g %.3g %.3g %.3g]\n', res_ga.fbest, res_ga.xbest);
    else
        fprintf('GA best total weight = %.3f g (no parameter vector returned)\n', res_ga.fbest);
    end
else
    % attempt to print preliminary info if available
    if isfield(res_ga,'output') && isstruct(res_ga.output) && isfield(res_ga.output,'prelim_best') && isfinite(res_ga.output.prelim_best)
        pb = res_ga.output.prelim_best; px = res_ga.output.prelim_x;
        if ~isempty(px)
            fprintf('GA aborted: preliminary best = %.3f g at [Q f0 A K] = [%.3g %.3g %.3g %.3g]\n', pb, px);
        else
            fprintf('GA aborted: no feasible samples found in preliminary sampling.\n');
        end
    else
        fprintf('GA aborted or failed without a result.\n');
    end
end

fprintf('\nRunning Particle Swarm (seed=2) ...\n');
t_pso = tic;
res_pso = run_optimizer('particleswarm', data, opt, bounds, 2);
time_pso = toc(t_pso);
fprintf('Particle Swarm completed in %.2f seconds.\n', time_pso);

save(fullfile(opt.results_folder,'res_pso.mat'),'res_pso');
if isfield(res_pso,'fbest') && isfinite(res_pso.fbest)
    if isfield(res_pso,'xbest') && ~isempty(res_pso.xbest)
        fprintf('PSO best total weight = %.3f g at [Q f0 A K] = [%.3g %.3g %.3g %.3g]\n', res_pso.fbest, res_pso.xbest);
    else
        fprintf('PSO best total weight = %.3f g (no parameter vector returned)\n', res_pso.fbest);
    end
else
    if isfield(res_pso,'output') && isstruct(res_pso.output) && isfield(res_pso.output,'prelim_best') && isfinite(res_pso.output.prelim_best)
        pb = res_pso.output.prelim_best; px = res_pso.output.prelim_x;
        if ~isempty(px)
            fprintf('PSO aborted: preliminary best = %.3f g at [Q f0 A K] = [%.3g %.3g %.3g %.3g]\n', pb, px);
        else
            fprintf('PSO aborted: no feasible samples found in preliminary sampling.\n');
        end
    else
        fprintf('PSO aborted or failed without a result.\n');
    end
end

% Print a short summary
fprintf('\nSummary:\n');
if exist('bf_full','var') && isfield(bf_full,'best')
    fprintf('  Full brute best: J=%.3f at [Q f0 A K]=[%.3g %.3g %.3g %.3g]\n', bf_full.best.J, bf_full.best.x);
end
if ~isempty(best_timed.x)
    fprintf('  Timed brute (2s): J=%.3f at [Q f0 A K]=[%.3g %.3g %.3g %.3g]\n', best_timed.J, best_timed.x);
end
fprintf('  GA: J=%.3f at x=[%.3g %.3g %.3g %.3g]\n', res_ga.fbest, res_ga.xbest);
fprintf('  PSO: J=%.3f at x=[%.3g %.3g %.3g %.3g]\n', res_pso.fbest, res_pso.xbest);


% Results output
%-------------------------------------------

% Deletes rows of zeros, and then sorts by weight
XfmerDesignArray = ResultX(~all(ResultX == 0, 2), :);
XfmerDesignArray = sortrows(XfmerDesignArray,36,'ascend');

% Turns core geometry and material into their names from the sheet
freqTable = readcell(corelossfile,'Sheet','Freq');
sizeTable = readcell(coresizefile,'Sheet',coresizeSheetname);
matNames = freqTable(2:end,2);
geomNames = sizeTable(2:end,2);
geomIndexes = XfmerDesignArray(1:end,38);
matIndexes = XfmerDesignArray(1:end,5);
fullmatNames = matNames(matIndexes);
fullgeomNames = geomNames(geomIndexes);
XfmerDesignCellArr = num2cell(XfmerDesignArray);
XfmerDesignCellArr(:,5) = fullmatNames;
XfmerDesignCellArr(:,38) = fullgeomNames;

% Results for transformer and the column names are passed here.
XfmerDesignTable = cell2table(XfmerDesignCellArr,'VariableNames',{'Po_W','Vppeak_V',...
    'Vspeak_V','fs_Hz','Core Material','CoreMatFreq_Hz',...
    'NumOfPri','NumOfSec',...
    'BcoreDensity_T','WirePriDia_AWG','WirePriFullDia_m','WireSecDia_AWG',...
    'WireSecFullDia_m','WirePri_Idensity_A/m2','WireSecIdensity_A/m2',...
    'WirePriNstrands','WireSecNstrands','WirePri_per_layer','WirePri_Nlayer',...
    'WireSec_per_layer', 'WireSec_Nlayer','Ns1','Ns2','Ns3','Ns4','CopperPackingFactor',...
    'PackingFactor', 'LossCore_W','LossCopper_W' , 'WeightCore_g','WeightPri_copper_g',...
    'WeightPri_Insu_g', 'WeightSec_copper_g', 'WeightSec_Insu_g', 'WeightCore_Insu_g',...
    'TotalWeight_g', 'TempAbsolute_C','Core Geometry','Volume_m^3','Magnetizing Inductance_H', ...
    'Leakage Inductance_H','Primary strand diameter_AWG','Secondary strand diameter_AWG'});

writetable(XfmerDesignTable,filename_xfmer,'Sheet',ResultDatasheetname);
% Results are written to excel file and sheet
xcelX = readcell(filename_xfmer,'Sheet',ResultDatasheetname);
[row,col] = size(xcelX);
writecell(repmat({''},row,col),filename_xfmer,'Sheet',ResultDatasheetname);
writetable(XfmerDesignTable,filename_xfmer,'Sheet',ResultDatasheetname);

if size(XfmerDesignTable,1)>=2
    weightX = XfmerDesignTable{2,36};
    % derive magnetizing and leakage inductance estimates here, print it.
    Lmag = XfmerDesignTable{2,40};
    Lleakage = XfmerDesignTable{2,41};
    fprintf("Real magnetizing inductance is about %.3f uH",Lmag*1000000);
    fprintf("Real leakage inductance is about %.3f uH",Lleakage*1000000);
else
    weightX = 0;
end
fprintf("Transformer Weight is %.2f g",weightX);

% Deletes rows of zeros, and then sorts by weight
InductorDesignArray = ResultL(~all(ResultL == 0, 2), :);
InductorDesignArray = sortrows(InductorDesignArray,23,'ascend');

% Turns core geometry and material into their names from the sheet
freqTableL = readcell(corelossfile,'Sheet','Freq');
sizeTableL = readcell(coresizefile,'Sheet',coresizeSheetname);
matNamesL = freqTableL(2:end,2);
geomNamesL = sizeTableL(2:end,2);
geomIndexesL = InductorDesignArray(1:end,27);
matIndexesL = InductorDesignArray(1:end,5);
fullmatNamesL = matNamesL(matIndexesL);
fullgeomNamesL = geomNamesL(geomIndexesL);
InductorDesignCellArr = num2cell(InductorDesignArray);
InductorDesignCellArr(:,5) = fullmatNamesL;
InductorDesignCellArr(:,27) = fullgeomNamesL;

% Results for inductor and the column names are passed here.
InductorDesignTable = cell2table(InductorDesignCellArr,'VariableNames',{'PoW','Vin_V',...
    'Vpri_V','fs_Hz','Core Material','CoreMatFreq_Hz','NumOfPri','BcoreDensity_T', ...
    'WirePriDia_AWG','WirePriFullDia_m','WirePri_Idensity_Aperm2', ...
    'WirePriNstrands','WirePri_per_layer','WirePri_Nlayer',...
    'CopperPackingFactor', 'PackingFactor','LossCore_W',...
    'LossCopper_W','WeightCore_g', 'WeightPri_copper_g','WeightPri_Insu_g',...
    'WeightCore_Insu_g','TotalWeight_g','TempAbsolute_C','L', 'airgap_m', 'Core Geometry',...
    'Q','f0', 'A', 'K', 'RT', 'Ls', 'Cs', 'Cp', 'GT','Volume_m^3','Strand diameter_AWG'});

writetable(InductorDesignTable,filename_inductor,'Sheet',ResultDatasheetname);
xcelL = readcell(filename_inductor,'Sheet',ResultDatasheetname);
[row,col] = size(xcelL);
writecell(repmat({''},row,col),filename_inductor,'Sheet',ResultDatasheetname);
writetable(InductorDesignTable,filename_inductor,'Sheet',ResultDatasheetname);

if size(InductorDesignTable,1)>=2
    weightL = InductorDesignTable{2,23};
else 
    weightL = 0;
end
fprintf("Inductor Weight is %.2f g",weightL);
