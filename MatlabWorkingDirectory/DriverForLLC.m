clc, clf, clear all 
close all

% Inductor and Transformer Test Table is given in TestTableIndXfmer.xlsx

%{
Notes:
What is done here:

- Sweeping core size, core material, wire build, and winding pattern.
Electrical, thermal, and mechanical parameters of each design are
calculated. 
    - Electrical:Max flux density, inductance of the inductor, magnetizing
        impedance of the transformer.
    - Thermal: Core loss (Steinmetz), copper loss (Dowell), absolute
    temperature
    - Physical: Packing factor (insulation), winding width and height

Rule out designs with constraints: (Examples below)
    - Max flux density >= 0.75*BSAT
    - Max temp >= 90 degC
    - Total loss 2% for inductors, 5% for transformers
    - Overall Packing factor >= 0.7,
    - Windings must fit in window height and width

Once satisfied, weight must be calculated:
    - Core
    - Wire Copper
    - Wire insulation
    - Core insulation

Lightest design is selected


Transformer:
    - The core should account for 50% of the weight,
    with the other 50% taken up by the copper.
    - Current density of the secondary is usually smaller
    than the rule-of-thumb 500A/cm^3.
    - Core loss %: core loss % corresponds to less current
    density in the wire
    - 

%}


% Ensure the excel files are not open elsewhere, or else
% you will get an error:

% "Unable to open file 'path' as
% a workbook. Check that the file exists,..."

% If your variables are too restrictive for your data, you will get
% a table with no values, as no set of variables match your requirements

%% Data Format for Size and Loss:

% Need to obtain data for the cores desired to analyze.
% You need to collect geometry and size data, as well as
% material-specific data.

% LossData:

% For material: You need flux density and power loss
% at discrete known frequencies,
% saturation flux density, and permittivity.
% Freq is in Hz, Bfield is in T, Ploss is in mW/cm^3,
% BSAT is in T, MU is in H/m

% Freq: at least one frequency must be within 40% of operating freq.
% frequency is in pairs of values. cols in Pairs of freq. per material
% Bfield: exactly 2 B points per freq. This is by design, so choose 2
% points close to your intended operating point or just in the middle of
% the CL loss data to avoid the low and high ranges, and it should be more
% accurate than any regression fit with more points (in theory)
% Ploss: 2 loss values corresponding to B values, in mW/cm3
% BSAT: design derates to 0.75 of value. Put one value in C per material
% MU: material mu_r in column C
% core loss data provided in the manufacturer's datasheet 

% Large Dataset (Memory Issues with PC)
% corelossfile = 'CoreLossData.xlsx';
% raw1 = readcell('CoreLossData.xlsx','Sheet','Freq');
% raw2 = readcell('CoreLossData.xlsx','Sheet','Bfield');
% raw3 = readcell('CoreLossData.xlsx','Sheet','Ploss');
% raw4 = readcell('CoreLossData.xlsx','Sheet','BSAT');
% raw5 = readcell('CoreLossData.xlsx','Sheet','MU');

corelossfile = 'CoreLossDataOLD.xlsx';
raw1 = readcell('CoreLossDataOLD.xlsx','Sheet','Freq');
raw2 = readcell('CoreLossDataOLD.xlsx','Sheet','Bfield');
raw3 = readcell('CoreLossDataOLD.xlsx','Sheet','Ploss');
raw4 = readcell('CoreLossDataOLD.xlsx','Sheet','BSAT');
raw5 = readcell('CoreLossDataOLD.xlsx','Sheet','MU');
raw6 = readcell('CoreLossDataOLD.xlsx','Sheet','Density');

% SizeData:

% For geometry: You need geometries with known dimensions
% You need core effective length Le (mm), 
% core window area height and width (mm^2),
% core volume (mm^3) as Le*Ac,
% need to differentiate between core geometries in the xlsx file,
% center leg and side leg area (still need to make standardized format
% for the excel file to be named accordingly to ER,EE,U,UR, etc.

% Ecore sheet from data in thesis, plus a column for core shape choice,
% with 1 = EE, 2 = ER, 3 = U, 4 = UR, but U and UR aren't included yet.
% Columns go as follows:
% [rowNumber,coreName,Ve,Ae,Le,coreShapeIndex,empty,priWindingWidth,
% priWindingHeight,secWindingWidth,secWindingHeight,coreWindowWidth,
% coreWindowHeight]
% all units are mm, or mm^2, or mm^3

% Large Dataset (Memory Issues with PC)
% coresizefile = 'CoreSizeData.xlsx';
% raw = readcell('CoreSizeData.xlsx','Sheet','Ecore');

coresizefile = 'CoreSizeDataOLD.xlsx';
raw = readcell('CoreSizeDataOLD.xlsx','Sheet','Ecore');

%% Parameters to Adjust

Date = 'xxx';
% Quality factor
Q_range = 0.1:0.1:5;
% Resonant frequency
f0_range = 4000;
% Capacitance ratio
A_range = 0.1:0.1:5;
% Turns ratio
K_range = 1:1:100;
% DC input voltage range
% Doesn't work with arrays for some reason.
Vin_range = 100;
% Peak amplitude of the output voltage that one hope to achieve (V)
% Doesn't work with arrays for some reason.
Vo_range = 4000;
% Output power desired (W)
Po_range = 200;
% frequency of the transformer
fs_range = 4000;


%[3981,6310,10000,15849,25119,...
%   39811,63096,100000,158489,251189,398107,630957,1000000];

% Winding Pattern index: 1 indicates center leg winding, 2 indicates double
Winding_Pattern = 1;
% Hypothesis: record why you want to run the sim
Hypothesis ='';
% Notes: record any changes you made to the code
Notes ='';

%% File Output


% File output configuration
filename_xfmer = strcat(Date,'_','TestXfmer.xlsx');
filename_inductor = strcat(Date,'_','TestInductor.xlsx');
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

% Resonant tank equivalent resistance, simply a constant divided by K^2.
RT = 8/pi^2*40000^2/700/6/6./K.^2;
% Series inductance of the resonant tank
Ls = RT./(2*pi.*f0.*Q);
% Series capacitance of LLC network
Cs = Q.*(A+1)./(A*2*pi.*f0.*RT);
% Parallel capacitance of LLC network
Cp = Q.*(A+1)./(2*pi.*f0.*RT);
% Transfer function gain factor; small-signal tank gain
GT = 4/pi./(sqrt((1+A).^2.*(1-(fs_range./f0).^2).^2+1./Q.^2.*(fs_range./f0-A.*f0./((A+1).*fs_range)).^2));
% Maximum current through resonant tank
Imax = Vin_range.*GT./RT.*sqrt(1+(fs_range./f0).^2.*Q.^2.*(A+1).^2);

% If effective gain GT.*K is within 20% of required gain, the design is
% acceptable. If not, index ignored. If all are ignored, error is thrown.
KeepIndex = intersect(find(GT.*K>=Vo_range/Vin_range),find(GT.*K<=1.2*Vo_range/Vin_range));
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
tic
for i = 1:length(Q)
    
    % Voltage applied to primary from the input and resonant tank gain.
    Vpri = Vin_range.*GT(i);
    % Output voltage on the transformer after turn ratio K
    Vsec = Vin_range.*GT(i).*K(i);
    % Maximum insulation stress
    Vinsulation_max = Vsec;

    % Run Xfmer design, return design vector. All CoreLoss and CoreSize
    % data is passed, along with primary voltage, secondary voltage, output
    % power goal, switching frequency goal, max insulation stress, and
    % winding pattern. None of the resonant tank sweep values are passed
    % here. Only the GT and K are relevant for the transformer design and
    % are what are being sweeped within this for loop through Vpri, Vinsulation_max,
    % and Vsec.
    SuceedX = Ecore_actual_EEER_xfmer_LCC(raw,raw1,raw2,raw3,raw4,raw5,raw6,...
        Vpri, Vsec, Po_range, fs_range, Vinsulation_max, Winding_Pattern);
    
    % Run Inductor design, return design table. All CoreLoss and CoreSize
    % data is passed, along with input voltage range (DC), output power
    % goal, switching frequency goal, winding pattern, and the resonant
    % tank sweep values.
    SuceedL = Ecore_actual_EEER_inductor_LCC(raw,raw1,raw2,raw3,raw4,raw5,raw6,...
        Vin_range,GT(i),Po_range,fs_range,Ls(i),Imax(i), Winding_Pattern,...
        Q(i), f0(i), A(i), K(i), RT(i), Ls(i), Cs(i), Cp(i), GT(i));
    
    % Successful result vector of many columns and 1 row for transformer and inductor are saved
    ResultX(i,:) = SuceedX;
    ResultL(i,:) = SuceedL;
    % Sliced variables in parallel loops allow this ResultX and ResultL to exist outside the
    % parfor loop.
end
toc


% Results for transformer and the column names are passed here.
XfmerDesignTable = array2table(ResultX,'VariableNames',{'Po_W','Vppeak_V',...
    'Vspeak_V','Vinsulation_max_V', 'fs_Hz','matno','CoreMatFreq_Hz','CoreAc_m2',...
    'CoreWindowH_m','CoreWindowW_m', 'NumOfPri','NumOfSec', 'RealConversion',...
    'BcoreDensity_T','WirePriDia_m','WirePriFullDia_m','WireSecDia_m',...
    'WireSecFullDia_m','WirePri_Idensity_Aperm2','WireSecIdensity_Aperm2',...
    'WirePriNstrands','WireSecNstrands','WirePri_per_layer','WirePri_Nlayer',...
    'WireSec_per_layer', 'WireSec_Nlayer','Ns1','Ns2','Ns3','Ns4','CopperPackingFactor',...
    'PackingFactor', 'LossCore_W','LossCopper_W' , 'WeightCore_g','WeightPri_copper_g',...
    'WeightPri_Insu_g', 'WeightSec_copper_g', 'WeightSec_Insu_g', 'WeightCore_Insu_g',...
    'TotalWeight_g', 'TempAbsolute_C','CoreIndex','Volume_m^3'});
% Deletes rows of zeros, and then sorts by weight
A = table2array(XfmerDesignTable);
XfmerDesignTable = XfmerDesignTable(~all(A == 0, 2), :);
XfmerDesignTable = sortrows(XfmerDesignTable,"TotalWeight_g","ascend");
% Results are written to excel file and sheet
writetable(XfmerDesignTable,filename_xfmer,'Sheet',ResultDatasheetname);

% Results for inductor and the column names are passed here.
InductorDesignTable = array2table(ResultL,'VariableNames',{'PoW','Vin_V',...
    'Vpri_V', 'Vinsulation_max_V', 'fs_Hz','matno','CoreMatFreq_Hz',...
    'CoreCenterLegL_m', 'CoreCenterLegT_m','CoreAc_m2','CoreWindowH_m',...
    'CoreWindowW_m','NumOfPri','BcoreDensity_T','WirePriDia_m','WirePriFullDia_m',...
    'WirePri_Idensity_Aperm2','WirePriNstrands','WirePri_per_layer','WirePri_Nlayer',...
    'CopperPackingFactor', 'PackingFactor','LossCore_W',...
    'LossCopper_W','WeightCore_g', 'WeightPri_copper_g','WeightPri_Insu_g',...
    'WeightCore_Insu_g','TotalWeight_g','TempAbsolute_C','L', 'airgap_m', 'CoreIndex',...
    'f0','Q', 'A', 'K', 'RT', 'Ls', 'Cs', 'Cp', 'GT','Volume_m^3'});
% Deletes rows of zeros, and then sorts by weight
A = table2array(InductorDesignTable);
InductorDesignTable = InductorDesignTable(~all(A == 0, 2), :);
InductorDesignTable = sortrows(InductorDesignTable,"TotalWeight_g","ascend");
% Results are written to excel file and sheet
writetable(InductorDesignTable,filename_inductor,'Sheet',ResultDatasheetname);

% Minimum weights for each design is printed in the chat.
weightX = ResultX(1,41);
fprintf("Transformer Weight is %.2f g",weightX);
weightL = ResultL(1,29);
fprintf("Inductor Weight is %.2f g",weightL);
