function y = Ecore_RTC_Boost( ...
    Vin_range, G_range, Po_range, Winding_Pattern, ...
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
    CopperDensity, rou, u0)
% ECORE_RTC_BOOST  Design an E/ER/U/UR-core inductor for a single-stage
%                  resonant transition boost converter.
%
%   All tunable parameters are passed from the driver script.
%   Returns a design matrix (Nx36) sorted by weight, or zeros(1,36) if
%   no feasible design is found.

% Parse Core Loss Data
%% -------------------------------------------------------------------------------------

[m1,n1] = size(raw1);
LCoreFreq   = cell2mat(raw1(2:m1, 3:n1));
[m1,n1] = size(raw2);
LCoreBfield = cell2mat(raw2(2:m1, 3:n1));
[m1,n1] = size(raw3);
LCorePloss  = cell2mat(raw3(2:m1, 3:n1));
[m1,~]  = size(raw4);
LCoreBSAT   = cell2mat(raw4(2:m1, 3));
[m1,~]  = size(raw5);
LCoreMU     = cell2mat(raw5(2:m1, 3));
[m1,~]  = size(raw6);
CoreDensity = cell2mat(raw6(2:m1, 3)) * 1e6;

Pbar = 500; % mW/cm^3 reference

% Build Steinmetz Parameters
%% -------------------------------------------------------------------------------------

NoMat = m1 - 1;
FreqFlag = zeros(1, NoMat);

maxFreqPairs   = floor(size(LCoreFreq,2)/2);
ConstantA      = zeros(NoMat, maxFreqPairs);
ConstantB      = zeros(NoMat, maxFreqPairs);
B_atPv_500     = zeros(NoMat, maxFreqPairs);
F_atPv_500     = zeros(NoMat, maxFreqPairs);
beta_range     = zeros(NoMat, maxFreqPairs);
XCorePloss_3rd = zeros(NoMat, maxFreqPairs);
alpha_range    = zeros(NoMat, maxFreqPairs);
K1_range       = zeros(NoMat, maxFreqPairs);

for i = 1:NoMat
    DataSheetFreq = LCoreFreq(i, ~isnan(LCoreFreq(i,:)));
    NoFreq = length(DataSheetFreq)/2;

    for j = 1:NoFreq
        ConstantA(i,j) = (log10(LCorePloss(i,2*j)) - log10(LCorePloss(i,2*j-1))) / ...
            (log10(LCoreBfield(i,2*j)) - log10(LCoreBfield(i,2*j-1)));
        ConstantB(i,j) = log10(LCorePloss(i,2*j)) - ConstantA(i,j)*log10(LCoreBfield(i,2*j));

        B_atPv_500(i,j) = 10^((log10(Pbar) - ConstantB(i,j)) / ConstantA(i,j));
        F_atPv_500(i,j) = DataSheetFreq(2*j-1);
        FreqFlag(i) = 1;

        if j > 1
            beta_range(i,j) = log10(LCorePloss(i,2*j)/LCorePloss(i,2*j-1)) / ...
                log10(LCoreBfield(i,2*j)/LCoreBfield(i,2*j-1));
            XCorePloss_3rd(i,j) = 10^(ConstantA(i,j-1)*log10(LCoreBfield(i,2*j)) + ConstantB(i,j-1));
            alpha_range(i,j) = log10(XCorePloss_3rd(i,j)/LCorePloss(i,2*j)) / ...
                log10(DataSheetFreq(2*j-3)/DataSheetFreq(2*j-1));
            K1_range(i,j) = LCorePloss(i,2*j) / ...
                (LCoreBfield(i,2*j)^beta_range(i,j)) / ...
                (DataSheetFreq(2*j-1)^alpha_range(i,j));
            if j == 2
                beta_range(i,1)  = beta_range(i,2);
                alpha_range(i,1) = alpha_range(i,2);
                K1_range(i,1) = LCorePloss(i,2*j-2) / ...
                    (LCoreBfield(i,2*j-2)^beta_range(i,1)) / ...
                    (DataSheetFreq(2*j-3)^alpha_range(i,1));
            end
        end
    end
end

% Parse Core Geometry
%% -------------------------------------------------------------------------------------

[m1,~] = size(raw);
LCoreIndex          = cell2mat(raw(2:m1, 1));
LcoreVe             = cell2mat(raw(2:m1, 3)) / 1e9;
LcoreAe             = cell2mat(raw(2:m1, 4)) / 1e6;
LcoreLe             = cell2mat(raw(2:m1, 5)) / 1e3;
LcoreCoreShapeIndex = cell2mat(raw(2:m1, 6));
LcorePriW           = cell2mat(raw(2:m1, 8)) / 1e3;
LcorePriH           = cell2mat(raw(2:m1, 9)) / 1e3;
LcoreWindowW        = cell2mat(raw(2:m1,12)) / 1e3;
LcoreWindowH        = cell2mat(raw(2:m1,13)) / 1e3;

% Design Space Sweep
%% -------------------------------------------------------------------------------------

CoreMatIndexSweep = find(FreqFlag);

[Po, Vin, G, CoreIndex, matno_record, Np, Mlp, airgap] = ndgrid( ...
    Po_range, Vin_range, G_range, LCoreIndex, CoreMatIndexSweep, ...
    MinWinding:IncreN:MaxWinding, 1:IncreMl:MaxMl, ...
    linspace(mingap, maxgap, numGapsTested));

Po           = reshape(Po, [], 1);
Vin          = reshape(Vin, [], 1);
G            = reshape(G, [], 1);
matno_record = reshape(matno_record, [], 1);
Np           = reshape(Np, [], 1);
Mlp          = reshape(Mlp, [], 1);
airgap       = reshape(airgap, [], 1);
CoreIndex    = reshape(CoreIndex, [], 1);

% Map geometry
Vcore     = LcoreVe(CoreIndex);
Ac        = LcoreAe(CoreIndex);
W         = LcoreWindowW(CoreIndex);
H         = LcoreWindowH(CoreIndex);
Le        = LcoreLe(CoreIndex);
PriW      = LcorePriW(CoreIndex);
PriH      = LcorePriH(CoreIndex);
CoreShape = LcoreCoreShapeIndex(CoreIndex);

% Map material
ui   = LCoreMU(matno_record);
BSAT = LCoreBSAT(matno_record);

% Inductance and output voltage
Vo = Vin .* G;
L  = u0 * Ac .* Np.^2 ./ (airgap + Le./ui);

% RTC Boost Timing
%% -------------------------------------------------------------------------------------

tring  = zeros(length(L), 1);
Ilpeak = zeros(length(L), 1);
tlrise = zeros(length(L), 1);
Ipeak  = zeros(length(L), 1);

for xx = 1:length(L)
    sigma_xx = (Vo(xx) - 2*Vin(xx)) / (Vo(xx) - Vin(xx));
    theta_xx = acos(1 - sigma_xx);

    tring(xx)  = (pi - theta_xx) * sqrt(L(xx) * Ctot);
    Ilpeak(xx) = -(Vo(xx) - Vin(xx)) * sqrt(Ctot/L(xx)) * sin(theta_xx);
    tlrise(xx) = L(xx) * abs(Ilpeak(xx)) / Vin(xx);

    a_c = L(xx)*Vo(xx) / (Vo(xx)-Vin(xx));
    b_c = -2*Po(xx)*Vo(xx)*L(xx) / (Vin(xx)*(Vo(xx)-Vin(xx)));
    c_c = -2*Po(xx)*tring(xx) - 2*Po(xx)*tlrise(xx) - L(xx)*Ilpeak(xx)^2;
    d_c = -2*Ctot*Vo(xx)*Po(xx);

    I = roots([a_c b_c c_c d_c]);
    Ipeak(xx) = I(1);
end

tfall = L .* Ipeak ./ (Vo - Vin);
trise = L .* Ipeak ./ Vin;
thold = Ctot .* Vo ./ Ipeak;
T     = trise + thold + tfall + tring + tlrise;
fs    = 1 ./ T;

% Initial Filters (airgap, Bmax, frequency)
%% -------------------------------------------------------------------------------------

KeepAirGap = intersect(find(airgap >= mingap), find(airgap <= 0.2*Le));
if isempty(KeepAirGap)
    warning('No feasible airgap for any core/turns combination.');
end

ue       = ui ./ (1 + ui .* airgap ./ Le);
Bm_dummy = u0 .* Np .* Ipeak ./ Le .* ue;

Keep_Bmindex = find(Bm_dummy < BSAT * BSAT_discount);
Keep_fsindex = intersect(find(fs >= fs_min), find(fs <= fs_max));
KeepIndex    = intersect(intersect(KeepAirGap, Keep_Bmindex), Keep_fsindex);

if isempty(KeepIndex)
    warning('No designs pass initial filters (airgap + Bsat + fs).');
    y = zeros(1, 44);
    return;
end

% Apply filters
Po     = Po(KeepIndex);    Vin   = Vin(KeepIndex);   Vo    = Vo(KeepIndex);
matno_record = matno_record(KeepIndex);
BSAT   = BSAT(KeepIndex);  CoreIndex = CoreIndex(KeepIndex);
PriW   = PriW(KeepIndex);  PriH  = PriH(KeepIndex);
CoreShape = CoreShape(KeepIndex);
H      = H(KeepIndex);     W     = W(KeepIndex);
Ac     = Ac(KeepIndex);    Vcore = Vcore(KeepIndex);
airgap = airgap(KeepIndex); Le   = Le(KeepIndex);
Np     = Np(KeepIndex);    Mlp   = Mlp(KeepIndex);
L      = L(KeepIndex);     fs    = fs(KeepIndex);
Ipeak  = Ipeak(KeepIndex); Ilpeak = Ilpeak(KeepIndex);
tring  = tring(KeepIndex); tlrise = tlrise(KeepIndex);
trise  = trise(KeepIndex); thold  = thold(KeepIndex);
tfall  = tfall(KeepIndex); T      = T(KeepIndex);
Bm     = Bm_dummy(KeepIndex);
Vinsulation_max = Vo;
Vpri = Vo; % inductor sees output voltage

% Expand for Steinmetz data points
%% -------------------------------------------------------------------------------------

FsnoNonzero = F_atPv_500(matno_record,:) > 0;
FsnoIndex   = abs(fs - F_atPv_500(matno_record,:)) ./ fs <= 0.4;
matfsIndex  = FsnoNonzero .* FsnoIndex;
matfs       = F_atPv_500(matno_record,:) .* matfsIndex;
K1          = K1_range(matno_record,:) .* matfsIndex * 1000;
alpha       = alpha_range(matno_record,:) .* matfsIndex;
beta        = beta_range(matno_record,:) .* matfsIndex;
[rowIdcs, ~] = find(matfs > 0);

if isempty(rowIdcs)
    warning('No Steinmetz data near operating frequency.');
    y = zeros(1, 44);
    return;
end

[UniqueRowIdcs, ~] = unique(rowIdcs, 'rows');
ColDuplicate = sum(matfs(UniqueRowIdcs,:) ~= 0, 2);

% Replicate all design vectors
Po     = repelem(Po(UniqueRowIdcs), ColDuplicate);
fs     = repelem(fs(UniqueRowIdcs), ColDuplicate);
Vin    = repelem(Vin(UniqueRowIdcs), ColDuplicate);
Vo     = repelem(Vo(UniqueRowIdcs), ColDuplicate);
Vpri   = repelem(Vpri(UniqueRowIdcs), ColDuplicate);
Vinsulation_max = repelem(Vinsulation_max(UniqueRowIdcs), ColDuplicate);
matno_record = repelem(matno_record(UniqueRowIdcs), ColDuplicate);
BSAT   = repelem(BSAT(UniqueRowIdcs), ColDuplicate);
CoreIndex = repelem(CoreIndex(UniqueRowIdcs), ColDuplicate);
PriW   = repelem(PriW(UniqueRowIdcs), ColDuplicate);
PriH   = repelem(PriH(UniqueRowIdcs), ColDuplicate);
CoreShape = repelem(CoreShape(UniqueRowIdcs), ColDuplicate);
H      = repelem(H(UniqueRowIdcs), ColDuplicate);
W      = repelem(W(UniqueRowIdcs), ColDuplicate);
Ac     = repelem(Ac(UniqueRowIdcs), ColDuplicate);
Vcore  = repelem(Vcore(UniqueRowIdcs), ColDuplicate);
airgap = repelem(airgap(UniqueRowIdcs), ColDuplicate);
Le     = repelem(Le(UniqueRowIdcs), ColDuplicate);
Np     = repelem(Np(UniqueRowIdcs), ColDuplicate);
Mlp    = repelem(Mlp(UniqueRowIdcs), ColDuplicate);
L      = repelem(L(UniqueRowIdcs), ColDuplicate);
Ipeak  = repelem(Ipeak(UniqueRowIdcs), ColDuplicate);
Ilpeak = repelem(Ilpeak(UniqueRowIdcs), ColDuplicate);
tring  = repelem(tring(UniqueRowIdcs), ColDuplicate);
tlrise = repelem(tlrise(UniqueRowIdcs), ColDuplicate);
trise  = repelem(trise(UniqueRowIdcs), ColDuplicate);
thold  = repelem(thold(UniqueRowIdcs), ColDuplicate);
tfall  = repelem(tfall(UniqueRowIdcs), ColDuplicate);
T      = repelem(T(UniqueRowIdcs), ColDuplicate);
Bm     = repelem(Bm(UniqueRowIdcs), ColDuplicate);

steinmetz_mask = reshape(matfsIndex(UniqueRowIdcs,:)', [], 1) > 0;
matfs = reshape(matfs(UniqueRowIdcs,:)', [], 1); matfs = matfs(steinmetz_mask);
K1    = reshape(K1(UniqueRowIdcs,:)',    [], 1); K1    = K1(steinmetz_mask);
beta  = reshape(beta(UniqueRowIdcs,:)',  [], 1); beta  = beta(steinmetz_mask);
alpha = reshape(alpha(UniqueRowIdcs,:)', [], 1); alpha = alpha(steinmetz_mask);

% Detailed Design: Losses, Wire, Weight
%% -------------------------------------------------------------------------------------

if isempty(Po)
    y = zeros(1, 44);
    return;
end

% Recompute effective permeability and flux (post-expansion)
ue = ui(1)*ones(size(Po)); % placeholder — recompute properly
ui_exp = LCoreMU(matno_record);
ue = ui_exp ./ (1 + ui_exp .* airgap ./ Le);
Bm = u0 .* Np .* Ipeak ./ Le .* ue;

% Core weight
Wcore = Vcore .* CoreDensity(matno_record);

% Core loss
Pcore = CoreLossMultiple .* Vcore .* K1 .* fs.^alpha .* Bm.^beta;

% Core shape masks
isEE = (CoreShape == 1);
isER = (CoreShape == 2);
isU  = (CoreShape == 3);
isUR = (CoreShape == 4);

% Wire Sizing (fixed litz logic from LCC)
%-------------------------------------------

Iprms     = Ipeak ./ sqrt(2);
skindepth = 1 ./ sqrt(pi .* fs .* u0 ./ rou);

% Required copper cross-section (with CuMult margin)
Areq_p = CuMult .* Iprms ./ Jwmax;
dsolid = 2 .* sqrt(Areq_p ./ pi);

% Solid vs litz: use 2*skindepth threshold (not 1x)
useSolid = dsolid <= 2.*skindepth;

% Litz strand diameter: use 2*skindepth (not 1x)
dstrand_litz = max(MinLitzStrandDia, 2.*skindepth);
Astrand      = pi .* (dstrand_litz./2).^2;

% Number of strands with minimum floor
Pri_Nstrands = ones(size(Iprms));
idLitz = ~useSolid;
Pri_Nstrands(idLitz) = min(maxLitzStrands, max(minLitzStrands, ceil(Areq_p(idLitz) ./ Astrand(idLitz))));

% Uninsulated wire diameter
Pri_WireDia = max(MinWireDia, dsolid);
if any(idLitz)
    % Physical bundle diameter: total copper / fill fraction
    Pri_WireDia(idLitz) = 2.*sqrt(Pri_Nstrands(idLitz).*Astrand(idLitz) ./ (pi.*LitzFactor));
end

% Strand diameter
Pri_ds = max(MinWireDia, dsolid);
Pri_ds(idLitz) = dstrand_litz(idLitz);

% Insulated wire diameter
CoreInsulationThickness = Vinsulation_max ./ dielectricstrength_insulation;
if layerTapeUse
    Pri_FullWireDia = Pri_WireDia + 2.*enamelThickness;
else
    Pri_FullWireDia = Pri_WireDia + 2.*(Vpri ./ dielectricstrength_insulation);
end

% Packing factors
CopperPacking  = (pi.*Pri_WireDia.^2./4 .* Np) ./ (H.*W);
OverallPacking = (pi.*Pri_FullWireDia.^2./4 .* Np) ./ (H.*W);

% Winding Geometry (per core shape and winding pattern)
%-------------------------------------------

Pri_PerLayer = floor(Np ./ Mlp);
TLp = zeros(size(Np));

if layerTapeUse
    numTapePerLayerPri = ceil((Vpri./Mlp) ./ (kaptonDielStrength * kaptonThickness));
    tTapePri = max(Mlp-1, 0) .* numTapePerLayerPri .* kaptonThickness;
else
    numTapePerLayerPri = zeros(size(Mlp));
    tTapePri = zeros(size(Mlp));
end

if Winding_Pattern == 1  % Center leg winding
    % EE and U: rectangular perimeter
    TLp(isEE|isU) = 2.*Np(isEE|isU) .* ( ...
        PriW(isEE|isU) + PriH(isEE|isU) + ...
        4.*CoreInsulationThickness(isEE|isU) + ...
        2.*tTapePri(isEE|isU) + ...
        2.*Mlp(isEE|isU).*Pri_FullWireDia(isEE|isU));

    % ER and UR: cylindrical
    TLp(isER|isUR) = 2.*pi.*Np(isER|isUR) .* ( ...
        PriW(isER|isUR)./2 + ...
        CoreInsulationThickness(isER|isUR) + ...
        0.5.*tTapePri(isER|isUR) + ...
        0.5.*Mlp(isER|isUR).*Pri_FullWireDia(isER|isUR));

elseif Winding_Pattern == 2  % Double leg winding
    % EE and U: wound on outer legs (wider perimeter)
    TLp(isEE|isU) = 2.*Np(isEE|isU) .* ( ...
        PriW(isEE|isU) + PriH(isEE|isU) + ...
        4.*CoreInsulationThickness(isEE|isU) + ...
        2.*tTapePri(isEE|isU) + ...
        2.*Mlp(isEE|isU).*Pri_FullWireDia(isEE|isU));

    % ER and UR: cylindrical around outer
    TLp(isER|isUR) = 2.*pi.*Np(isER|isUR) .* ( ...
        PriW(isER|isUR)./2 + ...
        CoreInsulationThickness(isER|isUR) + ...
        0.5.*tTapePri(isER|isUR) + ...
        0.5.*Mlp(isER|isUR).*Pri_FullWireDia(isER|isUR));
end

% Window fit checks
Mlp_index          = find(Mlp.*Pri_FullWireDia + tTapePri <= W - 2.*CoreInsulationThickness);
Pri_PerLayer_index = find(Pri_PerLayer.*Pri_FullWireDia <= H - 2.*CoreInsulationThickness);

% Copper Loss (Dowell — RTC form, which is the standard form)
%-------------------------------------------

PriKlayer = sqrt(pi .* Pri_Nstrands) .* Pri_ds ./ (2 .* Pri_WireDia);
% Standard Dowell: xp = (ds/(2*delta)) * sqrt(pi*K)
Pri_xp    = (Pri_ds ./ (2.*skindepth)) .* sqrt(pi .* PriKlayer);
Pri_Rdc   = rou .* TLp ./ (Pri_Nstrands .* (pi .* Pri_ds.^2 ./ 4));
Pri_Fr    = Pri_xp .* ( ...
    (sinh(2.*Pri_xp) + sin(2.*Pri_xp)) ./ (cosh(2.*Pri_xp) - cos(2.*Pri_xp)) + ...
    2.*(Mlp.^2.*Pri_Nstrands - 1)./3 .* ...
    (sinh(Pri_xp) - sin(Pri_xp)) ./ (cosh(Pri_xp) + cos(Pri_xp)));
Pri_Rac = Pri_Rdc .* Pri_Fr;

% RTC copper loss: DC from average current + AC from ripple
Pcopper = (Po./Vin).^2 .* Pri_Rdc + (Ipeak - Ilpeak).^2./8 .* Pri_Rac;

% Thermal
%-------------------------------------------

Wa = 2.*H.*W .* (isEE|isER) + H.*W .* (isU|isUR);
Rth = 16.31e-3 .* (Ac .* Wa).^(-0.405);
Tafterloss = Rth .* (Pcopper + Pcore) + 25;

% Core Insulation Weight (per shape)
%-------------------------------------------

WeightCore_Insu = zeros(size(Np));

WeightCore_Insu(isEE) = ( ...
    2.*H(isEE).*(PriW(isEE)+2.*PriH(isEE)) + ...
    4.*W(isEE).*(PriW(isEE)+2.*PriH(isEE)) + ...
    H(isEE).*(2.*PriW(isEE)+2.*PriH(isEE))) ...
    .* CoreInsulationThickness(isEE) .* CoreInsulationDensity;

WeightCore_Insu(isER) = ( ...
    sqrt(2).*pi.*H(isER).*PriW(isER) + ...
    sqrt(2).*pi.*2.*W(isER).*PriW(isER) + ...
    H(isER).*pi.*PriW(isER)) ...
    .* CoreInsulationThickness(isER) .* CoreInsulationDensity;

WeightCore_Insu(isU) = ( ...
    2.*H(isU).*(PriW(isU)+2.*PriH(isU)) + ...
    2.*W(isU).*(PriW(isU)+2.*PriH(isU)) + ...
    H(isU).*(2.*PriW(isU)+2.*PriH(isU))) ...
    .* CoreInsulationThickness(isU) .* CoreInsulationDensity;

WeightCore_Insu(isUR) = ( ...
    2.*H(isUR).*(PriW(isUR)+2.*PriH(isUR)) + ...
    pi.*W(isUR).*PriW(isUR) + ...
    H(isUR).*pi.*PriW(isUR)) ...
    .* CoreInsulationThickness(isUR) .* CoreInsulationDensity;

% Wire Weights
%-------------------------------------------

WeightPri_copper = pi.*Pri_WireDia.^2./4 .* TLp .* CopperDensity;
WeightPri_Insu   = pi.*(Pri_FullWireDia.^2 - Pri_WireDia.^2)./4 .* TLp .* WireInsulationDensity;

% Interlayer Tape Weight
%-------------------------------------------

if ~layerTapeUse
    Weight_InterlayerTape = zeros(size(Mlp));
    tapeMargin = 0;
else
    tapeMargin = max(0.02.*H, MinTapeMargin);
    a1 = Mlp.*Pri_FullWireDia + max(Mlp-1,0).*numTapePerLayerPri.*kaptonThickness;

    Lbase_p = zeros(size(Mlp));
    Lbase_p(isEE|isU)  = 2.*(PriW(isEE|isU) + PriH(isEE|isU) + 4.*CoreInsulationThickness(isEE|isU));
    Lbase_p(isER|isUR) = 2.*pi.*(PriW(isER|isUR)./2 + CoreInsulationThickness(isER|isUR));

    Lavg_il_p = Lbase_p + pi.*(a1./2);
    nBndPri   = max(Mlp-1, 0);
    L_tape_total = 1.05 .* (nBndPri .* numTapePerLayerPri .* Lavg_il_p);
    w_tape = H + 2.*tapeMargin;
    V_tape = kaptonThickness .* w_tape .* L_tape_total;
    Weight_InterlayerTape = kaptonDensity .* V_tape;
end

% Total Weight
%-------------------------------------------

TotalWeight = Wcore + WeightPri_copper + WeightPri_Insu + WeightCore_Insu + Weight_InterlayerTape;

% Packing factor update when using tape
if layerTapeUse
    CopperPacking  = (pi.*Pri_WireDia.^2./4 .* Np) ./ ((H - 2.*tapeMargin) .* W);
    OverallPacking = (pi.*Pri_FullWireDia.^2./4 .* Np) ./ ((H - 2.*tapeMargin) .* W);
end

% Final Filters
%% -------------------------------------------------------------------------------------

B_index                 = find(Bm < BSAT .* BSAT_discount);
P_loss_index            = find(Pcopper + Pcore <= Po .* (1 - etaInductor));
Tafterloss_index        = find(Tafterloss <= Tmax);
Tmin_index              = find(Tafterloss >= Tmin);
TotalWeight_index       = find(TotalWeight <= MaxWeight);
OverallPackingmin_index = find(OverallPacking >= minpackingfactor);
OverallPackingmax_index = find(OverallPacking <= maxpackingfactor);

Index_Meet_All = B_index;
Index_Meet_All = intersect(Index_Meet_All, P_loss_index);
Index_Meet_All = intersect(Index_Meet_All, Tafterloss_index);
Index_Meet_All = intersect(Index_Meet_All, Tmin_index);
Index_Meet_All = intersect(Index_Meet_All, TotalWeight_index);
Index_Meet_All = intersect(Index_Meet_All, OverallPackingmin_index);
Index_Meet_All = intersect(Index_Meet_All, OverallPackingmax_index);
Index_Meet_All = intersect(Index_Meet_All, Mlp_index);
Index_Meet_All = intersect(Index_Meet_All, Pri_PerLayer_index);

% Build Output
%% -------------------------------------------------------------------------------------

if ~isempty(Index_Meet_All)
    idx = Index_Meet_All;

    Volume = Vcore(idx) ...
        + WeightPri_copper(idx) ./ CopperDensity ...
        + WeightPri_Insu(idx) ./ WireInsulationDensity ...
        + WeightCore_Insu(idx) ./ CoreInsulationDensity;

    % AWG conversions
    Pri_WireDiaMM  = Pri_WireDia(idx) .* 1000;
    Pri_WireAWG    = -39*log(Pri_WireDiaMM ./ 0.127) ./ log(92) + 36;
    Pri_StrandDiaMM = Pri_ds(idx) .* 1000;
    Pri_StrandAWG   = -39*log(Pri_StrandDiaMM ./ 0.127) ./ log(92) + 36;

    Design = zeros(numel(idx), 44);
    Design(:, 1)  = Po(idx);
    Design(:, 2)  = Vin(idx);
    Design(:, 3)  = Vo(idx);
    Design(:, 4)  = Vinsulation_max(idx);
    Design(:, 5)  = fs(idx);
    Design(:, 6)  = matno_record(idx);
    Design(:, 7)  = matfs(idx);
    Design(:, 8)  = PriW(idx);
    Design(:, 9)  = PriH(idx);
    Design(:,10)  = Ac(idx);
    Design(:,11)  = H(idx);
    Design(:,12)  = W(idx);
    Design(:,13)  = Np(idx);
    Design(:,14)  = Bm(idx);
    Design(:,15)  = Pri_WireAWG;
    Design(:,16)  = Pri_FullWireDia(idx);
    Design(:,17)  = Ipeak(idx) ./ (pi .* Pri_Nstrands(idx) .* Pri_ds(idx).^2 ./ 4);
    Design(:,18)  = Pri_Nstrands(idx);
    Design(:,19)  = Pri_PerLayer(idx);
    Design(:,20)  = Mlp(idx);
    Design(:,21)  = CopperPacking(idx);
    Design(:,22)  = OverallPacking(idx);
    Design(:,23)  = Pcore(idx);
    Design(:,24)  = Pcopper(idx);
    Design(:,25)  = Wcore(idx);
    Design(:,26)  = WeightPri_copper(idx);
    Design(:,27)  = WeightPri_Insu(idx);
    Design(:,28)  = WeightCore_Insu(idx);
    Design(:,29)  = TotalWeight(idx);
    Design(:,30)  = Tafterloss(idx);
    Design(:,31)  = L(idx);
    Design(:,32)  = airgap(idx);
    Design(:,33)  = CoreIndex(idx);
    Design(:,34)  = Volume;
    Design(:,35)  = CoreShape(idx);
    Design(:,36)  = Pri_StrandAWG;
    % RTC timing outputs
    Design(:,37)  = Ipeak(idx);
    Design(:,38)  = Ilpeak(idx);
    Design(:,39)  = trise(idx);
    Design(:,40)  = thold(idx);
    Design(:,41)  = tfall(idx);
    Design(:,42)  = tring(idx);
    Design(:,43)  = tlrise(idx);
    Design(:,44)  = T(idx);

    y = Design;
else
    y = zeros(1, 44);
    disp('No feasible RTC boost inductor design found.');
end

end
