clc, clear

% RTC Boost Inductor Design Driver
% Designs a single-stage resonant transition boost inductor on an
% E/ER/U/UR core. No voltage multiplier staging, no H-bridge, no cap bank.

%% User Inputs — Electrical
%--------------------------------------------------------------------------

Date = '4-12-26';

Vin = 18;          % Input DC voltage (V)
Vo  = 100;          % Output voltage of RTC boost stage (V), must be > 2*Vin
Po  = 100;         % Output power (W)

% Winding Pattern: 1 = center leg, 2 = double leg
Winding_Pattern = 1;

Hypothesis = '';
Notes = '';

%% User Inputs — RTC Parameters
%--------------------------------------------------------------------------

% Total parasitic capacitance at switch node (F)
% (two GS66502T @ 40 pF + two C3D1P7060 @ 20 pF, with margin)
Ctot = 160e-12;

% Switching frequency bounds (Hz)
fs_min = 1e6;
fs_max = 5e6;

%% User Inputs — Inductor Constraints
%--------------------------------------------------------------------------

etaInductor = 0.80;     % Minimum inductor efficiency
Tmax        = 100;      % Max temperature (C)
Tmin        = 25;       % Min temperature (C)
MaxWeight   = 500;      % Max inductor weight (g)

%% User Inputs — Air Gap Sweep
%--------------------------------------------------------------------------

mingap        = 1e-3;   % Minimum air gap (m)
maxgap        = 3e-3;   % Maximum air gap (m)
numGapsTested = 10;

%% User Inputs — Turns and Layers
%--------------------------------------------------------------------------

MinWinding = 1;
MaxWinding = 20;
IncreN     = 1;
MaxMl      = 4;
IncreMl    = 1;

%% User Inputs — Wire
%--------------------------------------------------------------------------

MinWireDia       = 0.25/1000;    % Minimum wire diameter (m), ~AWG30
Jwmax            = 3e6;          % Max current density (A/m^2)
CuMult           = 1.1;          % Copper area oversizing factor
MinLitzStrandDia = 0.05024/1000; % Min litz strand diameter (m), AWG44
minLitzStrands   = 1;            % Min number of parallel strands
maxLitzStrands   = 19;
LitzFactor       = 0.8;          % Litz bundle copper fill fraction

%% User Inputs — Insulation
%--------------------------------------------------------------------------

layerTapeUse   = true;
enamelThickness = 20e-6;        % Per-side enamel thickness (m)
kaptonDielStrength = 0.5*200e5; % Derated Kapton dielectric strength (V/m)
kaptonThickness = 60e-6;        % Kapton tape thickness (m)
MinTapeMargin  = 5e-4;          % Min tape overhang (m)
kaptonDensity  = 1.42e6;        % Kapton density (g/m^3)

CoreInsulationDensity = 2.2e6;  % Core sheath density, Teflon (g/m^3)
WireInsulationDensity = 2.2e6;  % Wire jacket density, Teflon (g/m^3)
dielectricstrength_insulation = 0.5*200e5; % Core insulation strength (V/m)

%% User Inputs — Deratings
%--------------------------------------------------------------------------

BSAT_discount    = 0.85;
CoreLossMultiple = 1.5;
maxpackingfactor = 0.7;
minpackingfactor = 0.01;

%% Constants
%--------------------------------------------------------------------------

CopperDensity = 8.96e6;    % g/m^3
rou           = 2.3e-8;    % Resistivity of copper at 100 C (ohm*m)
u0            = 4*pi*1e-7; % Permeability of free space (H/m)

%% Read Core Data
%--------------------------------------------------------------------------

raw1 = readcell('CoreLossData.xlsx','Sheet','Freq');
raw2 = readcell('CoreLossData.xlsx','Sheet','Bfield');
raw3 = readcell('CoreLossData.xlsx','Sheet','Ploss');
raw4 = readcell('CoreLossData.xlsx','Sheet','BSAT');
raw5 = readcell('CoreLossData.xlsx','Sheet','MU');
raw6 = readcell('CoreLossData.xlsx','Sheet','Density');

raw = readcell('CoreSizeData.xlsx','Sheet','ReviewedCores');

%% Run Design
%--------------------------------------------------------------------------

G = Vo / Vin;
if Vo <= 2*Vin
    error('ZVS requires Vo > 2*Vin. Got Vo=%.1f, 2*Vin=%.1f.', Vo, 2*Vin);
end

tic
Result = Ecore_RTC_Boost( ...
    Vin, G, Po, Winding_Pattern, ...
    raw, raw1, raw2, raw3, raw4, raw5, raw6, ...
    Ctot, fs_min, fs_max, ...
    etaInductor, Tmax, Tmin, MaxWeight, ...
    mingap, maxgap, numGapsTested, ...
    MinWinding, MaxWinding, IncreN, MaxMl, IncreMl, ...
    MinWireDia, Jwmax, CuMult, MinLitzStrandDia, minLitzStrands, maxLitzStrands, LitzFactor, ...
    layerTapeUse, enamelThickness, kaptonDielStrength, kaptonThickness, ...
    MinTapeMargin, kaptonDensity, ...
    CoreInsulationDensity, WireInsulationDensity, dielectricstrength_insulation, ...
    BSAT_discount, CoreLossMultiple, maxpackingfactor, minpackingfactor, ...
    CopperDensity, rou, u0);
toc

if all(Result == 0)
    error('No feasible inductor design found. Relax constraints or check inputs.');
end

%% File Output
%--------------------------------------------------------------------------

filename = strcat(Date, '_', 'RTC_boost_inductor.xlsx');

% Save input parameters
field1 = 'name';
value1_req = {'Date','Hypothesis','Notes',...
    'Vin (V)','Vo (V)','Po (W)','G','Winding_Pattern', ...
    'Ctot (F)','fs_min (Hz)','fs_max (Hz)'};
field2 = 'data';
value2_req = {Date, Hypothesis, Notes, ...
    Vin, Vo, Po, G, Winding_Pattern, ...
    Ctot, fs_min, fs_max};
Requirement = struct(field1, value1_req, field2, value2_req);
fn   = fieldnames(Requirement);
vals = struct2cell(Requirement);
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
writetable(T, filename, 'Sheet', 'SimInfo', 'WriteVariableNames', true);

% Save inductor results
OutputTableL = array2table(Result, 'VariableNames', { ...
    'Po (W)', 'Vin (V)', 'Vo (V)', 'Vinsulation_max (V)', ...
    'fs (Hz)', 'matno', 'CoreMatFreq (Hz)', ...
    'CenterL (m)', 'CenterT (m)', 'CoreAc (m2)', ...
    'CoreWindowH (m)', 'CoreWindowW (m)', 'NumOfPri', ...
    'BcoreDensity (T)', 'WirePriDia_AWG', 'WirePriFullDia (m)', ...
    'WirePri_Idensity (A/m2)', 'WirePriNstrands', ...
    'WirePri_per_layer', 'WirePri_Nlayer', ...
    'CopperPackingFactor', 'PackingFactor', ...
    'LossCore (W)', 'LossCopper (W)', ...
    'WeightCore (g)', 'WeightPri_copper (g)', ...
    'WeightPri_Insu (g)', 'WeightCore_Insu (g)', ...
    'TotalWeight (g)', 'TempAbsolute (C)', ...
    'L (H)', 'airgap (m)', 'CoreIndex', 'Volume (m3)', ...
    'Core Shape Index', 'Strand dia (AWG)'});

arrL = table2array(OutputTableL);
OutputTableL = OutputTableL(~all(arrL == 0, 2), :);
OutputTableL = sortrows(OutputTableL, 'TotalWeight (g)', 'ascend');
writetable(OutputTableL, filename, 'Sheet', 'ResultsData');

fprintf('Best inductor weight: %.2f g\n', OutputTableL{1,'TotalWeight (g)'});
fprintf('Switching frequency:  %.2f MHz\n', OutputTableL{1,'fs (Hz)'}/1e6);
fprintf('Inductance:           %.2f uH\n', OutputTableL{1,'L (H)'}*1e6);
fprintf('Litz strands:         %d\n', OutputTableL{1,'WirePriNstrands'});
fprintf('Results saved to %s\n', filename);
