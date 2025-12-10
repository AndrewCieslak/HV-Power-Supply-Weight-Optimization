clc, clf, clear

global ResultX ResultL

corelossfile = 'CoreLossData.xlsx';
coresizefile = 'CoreSizeData.xlsx';
coresizeSheetname = 'Ecore';

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

% Temperature and current density are expected upper bounds 

% I want to extend the bottlenecking to Q, A, input voltage

% It seems to me actually that the B-CL curve extrapolation done in both
% magnetics scripts is actually finding the slope of the B-CL line and not
% the hysteresis line, like I had assumed before. Since the B-CL curve line
% is much more linear, the assumption actually holds pretty accurate.
% Better than I had thought.
% 12/4

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
Q_range = 0.9;
% Resonant frequency
f0_range = 3000;
% frequency of the transformer
fs_range = 3100;

% Capacitance ratio (inverse of inductance ratio) (shouldn't be lower than 0.1,
% since ZVS bandwidth becomes too small)
A_range = [0.01,0.05];
% DC input voltage range (unipolar peak) (if Vppeak is the param. to select around,
% keep GT ~1, but optimal weight is usually achieved with tank gain of ~2)
Vin_range = 100;
% Peak of the output voltage that one hope to achieve (V)
% peak to peak is 2x this value
Vo_range = 1e4;
% Output power desired (W)
Po_range = 100;
% Turns ratio secondary/primary
K_range = [90,95,100];

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
    etaInductor = 0.90;
    % Max allowable temperature (C)
    TmaxL = 100;
    % Min allowable temperature (C)
    TminL = 25;
    % Maximum allowable weight (g)
    MaxWeightL = 700;
    % Air gap (m)
    mingap = 0;
    
    % Winding and Wire Parameters
    %------------------------------------------
    
    % Minimum turns
    MinWindingL = 1;
    % Maximum turns
    MaxWindingL = 100;
    % Incremental winding
    IncreNL = 5;
    % Maximum layer of winding
    MaxMlL = 20;
    % Incremental layers. The layers of a transformer reference each wrap of
    % turns that fills the window height before moving on to the next level.
    % Once one layer fills, the next layer is wound on top, seperated by an
    % insulation layer.
    IncreMlL = 2;

    % Copper wire multiple to reduce resistive losses
    CuMultL = 1.1;
    
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
    etaXfmer = 0.90;
    % Max operating temp in Celsius
    TmaxX = 100;
    % Min operating temp in Celsius
    TminX = 25;
    % Minimum primary windings
    MinPriWindingX = 1;
    % Maximum primary windings
    MaxPriWindingX = 200;
    % Incremental primary winding
    IncreNpX = 5;
    % Maximum layer of primary winding
    MaxMlpX = 5;
    % Incremental layer of primary winding
    IncreMlpX = 1;
    % Maximum layer of secondary winding
    MaxMlsX = 30;
    % Incremental layer of secondary winding
    IncreMlsX = 2;
    % Max allowable transformer weight (g)
    MaxWeightX = 900;

    % Winding Wire Copper Multiple to Decrease Copper Loss
    CuMultX = 1.1;

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
LitzFactor = 0.75;
% Minimal wire diameter (m)
MinWireDia = 0.25/1000; % AWG28, 0.35 mm is AWG29, 0.079 is AWG40
% Max allowable current density in the wire (A/m^2)
% 500A/cm^2 is the upper bound recommended, but without active cooling, and
% since the magnetics are thermally insulated, less is assumed
Jwmax = 3e6;
% Minimum number of bundled strands per wire (paralleling magnet wires i.e.
% making custom Litz wire can be done for nonstandard strand amounts)
minLitzStrands = 1;
% Minimal litz diameter one can get (m)
MinLitzStrandDia = 0.05024 / 1000; % AWG44 % 0.0316 is AWG48, 0.03983 is AWG46
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
ResultX = zeros(1,43);
ResultL = zeros(1,38);

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
[Q,f0,A,K,Vo,fs,Po,Vin] = ndgrid(Q_range, f0_range, A_range, K_range, Vo_range, fs_range, Po_range, Vin_range);
Q = reshape(Q,[],1);
f0 = reshape(f0,[],1);
A = reshape(A,[],1);
K = reshape(K,[],1);
Vo = reshape(Vo,[],1);
fs = reshape(fs,[],1);
Po = reshape(Po,[],1);
Vin = reshape(Vin,[],1);

% All of the following calculations are computed for each element in the
% matrix individually via the A.^B, A.*B, etc. operator. The sizes of A and B
% in A.^B must be equal or compatible. This allows for a large amount of
% independent values to be computed in a compact format.

% Equivalent resistance across secondary (from output p and output v)
Req = (Vo./sqrt(2)).^2./Po;
% Resonant tank reflected load resistance
RT = Req./K.^2;
% Series inductance of the resonant tank
Ls = RT./(2*pi.*f0.*Q);
% Series capacitance of LLC network
Cs = Q.*(A+1)./(A*2*pi.*f0.*RT);
% Parallel capacitance of LLC network
Cp = Q.*(A+1)./(2*pi.*f0.*RT);
% Transfer function gain factor; small-signal tank gain
GT = (4/pi)./(sqrt((1+A).^2.*(1-(fs./f0).^2).^2+1./Q.^2.*(fs./f0-A.*f0./((A+1).*fs)).^2));
% Maximum current through resonant tank
Imax = (Vin.*GT./RT).*sqrt(1+(fs./f0).^2.*Q.^2.*(A+1).^2);


% If effective gain GT.*K is within 20% of required gain, the design is
% acceptable. If not, index ignored. If all are ignored, error is thrown.
KeepIndex = intersect(find(GT.*K>=Vo./Vin),find(GT.*K<=1.2*Vo./Vin));
KeepIndex = intersect(KeepIndex,find(GT > 1));
if isempty(KeepIndex)
    error('Driver:NoCandidates', ...
          'No design points satisfy GT*K and GT>1. Adjust Vin/Vo/K/A/Q/f0.');
end

% Operating points not ignored are kept.
Q = Q(KeepIndex);
f0 = f0(KeepIndex);
A= A(KeepIndex);
K= K(KeepIndex);
RT = RT(KeepIndex);
Ls = Ls(KeepIndex);
Cs = Cs(KeepIndex);
Cp = Cp(KeepIndex);
GT = GT(KeepIndex);
Imax = Imax(KeepIndex);
Vin = Vin(KeepIndex);
Po = Po(KeepIndex);
Vo = Vo(KeepIndex);
fs = fs(KeepIndex);

% Loops over every row of the 4-D grid, with tic-toc measuring total
% runtime.
%-------------------------------------------
pcnt = 0.1;
tic
for i = 1:length(Q)
    
    % Peak voltage applied to primary from the input and resonant tank gain.
    Vpri = Vin(i).*GT(i);
    % Peak output voltage on the transformer after turn ratio K
    Vsec = Vin(i).*GT(i).*K(i);
    % Maximum insulation stress
    Vinsulation_max = Vsec;

    % Parallel capacitive reactance
    XCp = 1/(2.*pi.*fs.*Cp);

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
        LitzFactor,MinWireDia,Jwmax,MinLitzStrandDia,CopperDensity,rou,u0,XCp, ...
        minLitzStrands,CuMultX);
    
    % Run Inductor design, return design table. All CoreLoss and CoreSize
    % data is passed, along with input voltage range (DC), output power
    % goal, switching frequency goal, winding pattern, and the resonant
    % tank sweep values.
    SuceedL = Ecore_actual_EEER_inductor_LCC(raw,raw1,raw2,raw3,raw4,raw5,raw6,...
        Vin(i),GT(i),Po(i),fs(i),Ls(i),Imax(i), Winding_Pattern,...
        Q(i), f0(i), A(i), K(i), RT(i), Ls(i), Cs(i), Cp(i), GT(i), ...
        layerTapeUse,enamelThickness,kaptonDielStrength,kaptonThickness,...
        MinTapeMargin,kaptonDensity,CoreInsulationDensity,WireInsulationDensity, ...
        dielectricstrength_insulation,etaInductor,TmaxL,TminL,MaxWeightL,mingap, ...
        MinWindingL,MaxWindingL,IncreNL,MaxMlL,IncreMlL,BSAT_discountL, ...
        CoreLossMultipleL,maxpackingfactorL,minpackingfactorL,CuMultL,...
        LitzFactor,MinWireDia,Jwmax,MinLitzStrandDia,CopperDensity,rou,u0,minLitzStrands);
    
    SuceedL = sortrows(SuceedL,23,'ascend');
    SuceedX = sortrows(SuceedX,36,'ascend');
   
    % Successful result vector of the best row for transformer and inductor are saved
    ResultX(end+1,:) = SuceedX(1,:);
    ResultL(end+1,:) = SuceedL(1,:);

    % Sliced variables in parallel loops allow this ResultX and ResultL to exist outside the
    % parfor loop.

    if i>=pcnt*length(Q)
        pcnt=pcnt+0.1;
        fprintf("%d Percent Complete \n",round(i*100/length(Q)));
    end
end
toc



% Results output
%-------------------------------------------

% Deletes rows of zeros, and then sorts by weight
XfmerDesignArray = ResultX(~all(ResultX == 0, 2), :);
XfmerDesignArray = sortrows(XfmerDesignArray,36,'ascend');

% Checks values of successful inputs to see if they are suspiciously close
% to the bounds of the input ranges. If so, that value is likely a
% bottleneck.

% Transformer Design Checker
% Checks the best 20 rows
if size(XfmerDesignArray)>1
    nTopX = min(20,size(XfmerDesignArray,1));
    bottleneckCheckX = XfmerDesignArray(1:nTopX,:);
    
    Pbase    = bottleneckCheckX(:,1);    % base power (used in efficiency)
    Pcu      = bottleneckCheckX(:,28);   % copper loss
    Pcore    = bottleneckCheckX(:,29);   % core loss
    eta_des  = (Pbase - (Pcu + Pcore)) ./ Pbase;   % final design efficiency
    T_des    = bottleneckCheckX(:,37);   % final design temperature
    Np       = bottleneckCheckX(:,7);    % primary turns
    Nlp      = bottleneckCheckX(:,19);   % primary layers
    Nls      = bottleneckCheckX(:,21);   % secondary layers
    Weight   = bottleneckCheckX(:,36);   % total transformer weight
    Packing  = bottleneckCheckX(:,27);   % packing factor
    PriAWG   = bottleneckCheckX(:,10);   % primary wire gauge (AWG)
    PriDia_m = 0.0254.*(0.005 .* 92.^((36 - PriAWG)./39));
    Jpri     = bottleneckCheckX(:,14);   % primary current density
    Jsec     = bottleneckCheckX(:,15);   % secondary current density
    NstrPri  = bottleneckCheckX(:,16);   % primary Litz strand count
    NstrSec  = bottleneckCheckX(:,17);   % secondary Litz strand count
    TurnRatio = ceil(bottleneckCheckX(:,8)./Np);
    
    checkVarBottleneck(eta_des, etaXfmer, NaN, ...
        'Efficiency (η)', nTopX/2, 0.02);
    checkVarBottleneck(T_des, TminX, TmaxX, ...
        'Temperature T', nTopX/2, 1);
    if MinPriWindingX>1
        checkVarBottleneck(Np, MinPriWindingX, MaxPriWindingX, ...
            'Primary turns Np', nTopX/2, 1);
    end
    checkVarBottleneck(Nlp, NaN, MaxMlpX, ...
        'Primary layers Nlp', nTopX/2, 1);
    checkVarBottleneck(Nls, NaN, MaxMlsX, ...
        'Secondary layers Nls', nTopX/2, 1);
    checkVarBottleneck(Weight, NaN, MaxWeightX, ...
        'Transformer weight', nTopX/2, 10);
    checkVarBottleneck(Packing, minpackingfactorX, maxpackingfactorX, ...
        'Packing factor', nTopX/2, 0.1);
    checkVarBottleneck(PriDia_m, MinWireDia, NaN, ...
        'Primary wire diameter', nTopX/2, 1e-4);
    checkVarBottleneck(Jpri, NaN, Jwmax, ...
        'Primary current density Jpri', nTopX/2, 100);
    checkVarBottleneck(Jsec, NaN, Jwmax, ...
        'Secondary current density Jsec', nTopX/2, 100);
    if minLitzStrands>1
    checkVarBottleneck(NstrPri, minLitzStrands, NaN, ...
        'Primary Litz strands', nTopX/2, 1);
    end
    if minLitzStrands>1
    checkVarBottleneck(NstrSec, minLitzStrands, NaN, ...
        'Secondary Litz strands', nTopX/2, 1);
    end
    if K_range(1)>1
    checkVarBottleneck(TurnRatio,K_range(1),K_range(end),...
        'Turn Ratio N (Transformer-Calculated)', nTopX/2, 1);
    end
end

% Turns core geometry and material into their names from the sheet
matNames = raw1(2:end,2);
geomNames = raw(2:end,2);
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

if exist(filename_xfmer,'file'); delete(filename_xfmer); end
writetable(XfmerDesignTable,filename_xfmer,'Sheet',ResultDatasheetname);

if size(XfmerDesignTable,1)>=1
    weightX = XfmerDesignTable{1,36};
    % derive magnetizing and leakage inductance estimates here, print it.
    Lmag = XfmerDesignTable{1,40};
    Lleakage = XfmerDesignTable{1,41};
    fprintf("Real magnetizing inductance is about %.3f uH",Lmag*1000000);
    fprintf("Real leakage inductance is about %.3f uH",Lleakage*1000000);
else
    weightX = 0;
end
fprintf("Transformer Weight is %.2f g",weightX);

% Deletes rows of zeros, and then sorts by weight
InductorDesignArray = ResultL(~all(ResultL == 0, 2), :);
InductorDesignArray = sortrows(InductorDesignArray,23,'ascend');

if size(InductorDesignArray)>1
    % Inductor Bottleneck Checking
    
    % Checks values of successful inputs to see if they are suspiciously close
    % to the bounds of the input ranges. If so, that value is likely a
    % bottleneck. Checks top 20 best rows.
    nTopL = min(20,size(InductorDesignArray,1));
    bottleneckCheckL = InductorDesignArray(1:nTopL,:);
    
    PbaseL   = bottleneckCheckL(:,1);
    PcuL     = bottleneckCheckL(:,17);
    PcoreL   = bottleneckCheckL(:,18);
    etaL_des = (PbaseL - (PcuL + PcoreL)) ./ PbaseL;
    TL       = bottleneckCheckL(:,24);
    NturnsL  = bottleneckCheckL(:,7);
    MlL      = bottleneckCheckL(:,14);
    WeightL  = bottleneckCheckL(:,23);
    PackingL = bottleneckCheckL(:,16);
    WireAWG_L = bottleneckCheckL(:,9);
    WireDia_L = 0.0254.*(0.005 .* 92.^((36 - WireAWG_L)./39));
    J_L      = bottleneckCheckL(:,11);
    Nstr_L   = bottleneckCheckL(:,12);
    GapL     = bottleneckCheckL(:,26);
    Out_Q = bottleneckCheckL(:,28);
    Out_A = bottleneckCheckL(:,30);
    Out_K = bottleneckCheckL(:,31);

    if K_range(1)>1
    checkVarBottleneck(Out_K,K_range(1),K_range(end), ...
        'Turn Ratio of Transformer (Inductor-Calculated)', nTopL/2, 1);
    end
    checkVarBottleneck(Out_A, A_range(1), A_range(end), ...
        'Capacitance Ratio of Tank (A)', nTopL/2, 0.01);
    checkVarBottleneck(Out_Q, Q_range(1), Q_range(end), ...
        'Quality Factor of Tank (Q)', nTopL/2, 0.05);
    checkVarBottleneck(etaL_des, etaInductor, NaN, ...
        'Inductor efficiency (η)', nTopL/2, 0.02);
    checkVarBottleneck(TL, TminL, TmaxL, ...
        'Inductor temperature T', nTopL/2, 1);
    if MinWindingL>1
        checkVarBottleneck(NturnsL, MinWindingL, MaxWindingL, ...
            'Inductor turns N', nTopL/2, 1);
    end
    checkVarBottleneck(MlL, NaN, MaxMlL, ...
        'Inductor layers', nTopL/2, 1);
    checkVarBottleneck(WeightL, NaN, MaxWeightL, ...
        'Inductor weight', nTopL/2, 10);
    checkVarBottleneck(PackingL, minpackingfactorL, maxpackingfactorL, ...
        'Inductor packing factor', nTopL/2, 0.1);
    checkVarBottleneck(WireDia_L, MinWireDia, NaN, ...
        'Inductor wire diameter', nTopL/2, 1e-4);
    checkVarBottleneck(J_L, NaN, Jwmax, ...
        'Inductor current density J', nTopL/2, 100);
    checkVarBottleneck(GapL, mingap, NaN, ...
        'Inductor gap length', nTopL/2, 1e-4);
    if minLitzStrands > 1
        checkVarBottleneck(Nstr_L, minLitzStrands, NaN, ...
            'Inductor Litz strands', nTopL/2, 1);
    end
end


% Turns core geometry and material into their names from the sheet
matNamesL = raw1(2:end,2);
geomNamesL = raw(2:end,2);
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

if exist(filename_inductor,'file'); delete(filename_inductor); end
writetable(InductorDesignTable,filename_inductor,'Sheet',ResultDatasheetname);

if size(InductorDesignTable,1)>=1
    weightL = InductorDesignTable{1,23};
else 
    weightL = 0;
end
fprintf("Inductor Weight is %.2f g",weightL);

function checkVarBottleneck(dataVec, minVal, maxVal, name, threshold, tol)
%   dataVec : the 20 best rows
%   minVal  : lower bound (NaN to ignore)
%   maxVal  : upper bound (NaN to ignore)
%   name    : descriptive name for printing
%   threshold : # of designs at the bound to trigger a warning
%   tol       : numerical tolerance

    nTop = numel(dataVec);
    if ~isnan(minVal)
        nLower = sum(dataVec <= minVal+tol);
        if nLower >= threshold
            fprintf(['Possible bottleneck (LOWER): %s at bound %.5g ' ...
                     'in %d / %d top designs. Consider relaxing the minimum.\n'], ...
                     name, minVal, nLower, nTop);
        end
    end

    if ~isnan(maxVal)
        nUpper = sum(dataVec >= maxVal-tol);
        if nUpper >= threshold
            fprintf(['Possible bottleneck (UPPER): %s at bound %.5g ' ...
                     'in %d / %d top designs. Consider relaxing the maximum.\n'], ...
                     name, maxVal, nUpper, nTop);
        end
    end
end
