function monthResults = evaluateFold_CBV_monthly(obs, go, cov, KG, KS, BMEparam, trainMask, valMask, valYear, valMonth)
% evaluateFold_CBV_monthly - Evaluate CBV for a single month
%
% Performs checker-board validation for one month: trains on training stations
% within temporal window, validates at validation stations for the target month.
%
% SYNTAX:
%   monthResults = evaluateFold_CBV_monthly(obs, go, cov, KG, KS, BMEparam, ...
%                                           trainMask, valMask, valYear, valMonth)
%
% INPUTS:
%   obs       - Full observational data structure
%   go        - Global offset structure
%   cov       - Covariance structure
%   KG        - General Knowledge
%   KS        - Site-specific Knowledge (from full data)
%   BMEparam  - BME parameters
%   trainMask - nStations × 1 logical (true = training stations)
%   valMask   - nStations × 1 logical (true = validation stations)
%   valYear   - Validation year (e.g., 2017)
%   valMonth  - Validation month (1-12)
%
% OUTPUTS:
%   monthResults - Structure with:
%                  .Y_obs      - Observed values at validation points
%                  .Y_est      - Estimated values
%                  .Y_estNoGo  - Estimates without global offset
%                  .sk         - Spatial coordinates
%                  .tk         - Time coordinates
%                  .XkBMEv     - Estimation variances
%                  .gok        - Global offset values
%                  .nValid     - Number of valid pairs

%% Define Time Windows
% Target month boundaries
monthStart = valYear + (valMonth - 1) / 12;
monthEnd = valYear + valMonth / 12;

fprintf('  Target month: %.4f - %.4f (Year %d, Month %d)\n', ...
    monthStart, monthEnd, valYear, valMonth);

%% Define Temporal Window (±1 year for 2017)
% Use ±1 year of data around validation year
temporalWindow = 1.0;  % years
windowStart = valYear - temporalWindow;
windowEnd = valYear + temporalWindow + 1/12;  % Include validation year end

fprintf('  Temporal window: %.4f - %.4f (±%.1f years)\n', ...
    windowStart, windowEnd, temporalWindow);

%% Filter Observations to Temporal Window
inWindow = (obs.tME >= windowStart) & (obs.tME < windowEnd);

if sum(inWindow) == 0
    warning('No time periods in temporal window');
    monthResults = [];
    return;
end

%% Create Training Dataset (Spatial + Temporal Filter)
% Training: only training stations, within temporal window
trainObs = obs;
trainObs.sMS = obs.sMS(trainMask, :);
trainObs.Z = obs.Z(trainMask, inWindow);
trainObs.Y = obs.Y(trainMask, inWindow);
trainObs.tME = obs.tME(inWindow);

nTrainValid = sum(~isnan(trainObs.Z(:)));
fprintf('  Training data: %d stations, %d times, %d valid points\n', ...
    size(trainObs.sMS, 1), length(trainObs.tME), nTrainValid);

%% Prepare BME Knowledge Base from Training Data
% Convert training data to knowledge base (STG → STV format)
fprintf('  Building knowledge base from training data...\n');
[KG_train, KS_train, ~] = getTOARknowledgeBase(trainObs, go, cov, ...
    KS.softdata, BMEparam.BMEmethod8digits, 'stug');

if isempty(KS_train.harddata.z) || length(KS_train.harddata.z) < 10
    warning('Insufficient training data (%d points)', length(KS_train.harddata.z));
    monthResults = [];
    return;
end

fprintf('  Training knowledge base: %d hard data points\n', length(KS_train.harddata.z));

%% Create Validation Space-Time Points
% Get validation stations and target month time
valStations = obs.sMS(valMask, :);

% Find exact target month time index
inTargetMonth = (obs.tME >= monthStart) & (obs.tME < monthEnd);
targetTimes = obs.tME(inTargetMonth);

if isempty(targetTimes)
    warning('No target month in data');
    monthResults = [];
    return;
end

% Create estimation points: validation stations × target month time(s)
nValStations = size(valStations, 1);
nTargetTimes = length(targetTimes);

% Repeat stations for each time
sk_all = repmat(valStations, nTargetTimes, 1);
tk_all = reshape(repmat(targetTimes, nValStations, 1), [], 1);
pk_all = [sk_all, tk_all];  % [lon, lat, time]

% Get observed values at these points
Y_obs_full = obs.Y(valMask, inTargetMonth);  % [nValStations × nTargetTimes]
Y_obs_all = reshape(Y_obs_full', [], 1);  % Vectorize (transpose first!)

% Filter to only locations where observations exist
hasObs = ~isnan(Y_obs_all);
pk = pk_all(hasObs, :);
Y_obs = Y_obs_all(hasObs);
sk = sk_all(hasObs, :);
tk = tk_all(hasObs);

if isempty(pk)
    warning('No valid observations at validation locations for this month');
    monthResults = [];
    return;
end

fprintf('  Validation points: %d (filtered from %d to locations with obs)\n', ...
    size(pk, 1), size(pk_all, 1));

%% Perform BME Estimation at Validation Points
fprintf('  Performing BME estimation at validation locations...\n');
tic;

% Use STUG format for fastest estimation
BMEprobaType = str2double(BMEparam.BMEmethod8digits(8));

switch BMEprobaType
    case 2  % KrigingME
        % Reformat soft data to STUG if needed
        if ~isempty(KS_train.softdata) && ~isempty(KS_train.softdata.p)
            soft_data_stug = reformat_stg_to_stug(KS_train.softdata);
        else
            soft_data_stug = struct();
        end

        % Call krigingME_stug
        [XkBMEm, XkBMEv] = krigingME_stug(pk, ...
            KS_train.harddata.p, KS_train.softdata.p, ...
            KS_train.harddata.z, KS_train.softdata.z, KS_train.softdata.vs, ...
            KG_train.covmodel, KG_train.covparam, ...
            BMEparam.nhmax, BMEparam.nsmax, BMEparam.dmax, ...
            KG_train.order, 0, KS_train.harddata, soft_data_stug);

    otherwise
        error('Only BMEprobaType=2 (KrigingME) supported for CBV');
end

elapsedTime = toc;
fprintf('  Estimation completed in %.1f seconds\n', elapsedTime);

% Ensure column vectors
if size(XkBMEm, 2) > 1, XkBMEm = XkBMEm'; end
if size(XkBMEv, 2) > 1, XkBMEv = XkBMEv'; end

%% Add Global Offset
% Interpolate global offset at validation points
gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, sk, unique(tk));

% Add global offset to residuals
YkBMEm = XkBMEm + gok;

%% Clean Up Results
% Replace NaN estimates with 0 (following estTOARsBME pattern)
XkBMEm(isnan(XkBMEm)) = 0;
YkBMEm = XkBMEm + gok;  % Recalculate after replacing NaNs

% Clean variance
XkBMEv(isnan(XkBMEv)) = max(XkBMEv(~isnan(XkBMEv)));
XkBMEv = real(XkBMEv);

%% Remove Any Remaining NaN Pairs
validPairs = ~isnan(Y_obs) & ~isnan(YkBMEm) & isfinite(Y_obs) & isfinite(YkBMEm);

%% Package Results
monthResults.Y_obs = Y_obs(validPairs);
monthResults.Y_est = YkBMEm(validPairs);
monthResults.Y_estNoGo = XkBMEm(validPairs);
monthResults.sk = sk(validPairs, :);
monthResults.tk = tk(validPairs);
monthResults.XkBMEv = XkBMEv(validPairs);
monthResults.gok = gok(validPairs);
monthResults.nValid = sum(validPairs);

fprintf('  Valid pairs: %d\n', monthResults.nValid);

if monthResults.nValid > 0
    fprintf('  Obs range: [%.1f, %.1f], Est range: [%.1f, %.1f]\n', ...
        min(monthResults.Y_obs), max(monthResults.Y_obs), ...
        min(monthResults.Y_est), max(monthResults.Y_est));
end

end
