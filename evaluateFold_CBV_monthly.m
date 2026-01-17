function monthResults = evaluateFold_CBV_monthly(obs, go, cov, BMEparam, ...
    trainMask, valMask, valYear, valMonth)
% evaluateFold_CBV_monthly - Evaluate checker-board validation for single month
%
% Performs CBV for one month using ±1 year temporal window. Follows LOOCV
% monthly pattern and uses krigingME_stug_multi for multi-soft datasets.
%
% SYNTAX:
%   monthResults = evaluateFold_CBV_monthly(obs, go, cov, BMEparam, ...
%                                           trainMask, valMask, valYear, valMonth)
%
% INPUTS:
%   obs       - Observational data structure from getTOARobservationalData
%   go        - Global offset structure from getTOARglobalOffset
%   cov       - Covariance structure from getTOARautoCov
%   BMEparam  - BME parameters from getBMEparam
%   trainMask - nStations × 1 logical array (true = use for training)
%   valMask   - nStations × 1 logical array (true = use for validation)
%   valYear   - Year to validate (e.g., 2017)
%   valMonth  - Month to validate (1-12)
%
% OUTPUTS:
%   monthResults - Structure with monthly validation results:
%                  .Y_obs      - Observed values at validation points
%                  .Y_est      - Estimated values at validation points
%                  .Y_estNoGo  - Estimates in residual space (without GO)
%                  .sk         - Spatial coordinates of validation points
%                  .tk         - Temporal coordinates of validation points
%                  .XkBMEv     - Estimation variances
%                  .gok        - Global offset at validation points
%                  .nTrain     - Number of training points
%                  .nValid     - Number of valid pairs
%
% DESCRIPTION:
%   This function implements monthly checker-board validation:
%   1. Defines ±1 year temporal window around target month
%   2. Creates training dataset from obs using trainMask + temporal window
%   3. Prepares BME knowledge base using training data only
%   4. Estimates at validation station-time combinations that have observations
%   5. Filters to only s/t locations where observational data exists
%   6. Uses krigingME_stug_multi for multi-soft dataset support (like estTOARsBME)
%
% EXAMPLE:
%   [trainMask, valMask] = getCheckerBoard(obs.sMS, 3.0, 1);
%   results = evaluateFold_CBV_monthly(obs, go, cov, BMEparam, ...
%                                      trainMask, valMask, 2017, 6);

%% Input Validation
if nargin < 8
    error('All 8 inputs required');
end

% Ensure masks are logical column vectors
if ~islogical(trainMask), trainMask = logical(trainMask); end
if ~islogical(valMask), valMask = logical(valMask); end
trainMask = trainMask(:);
valMask = valMask(:);

%% Define Target Month Time Window
% Month boundaries in decimal years
monthStart = valYear + (valMonth - 1) / 12;
monthEnd = valYear + valMonth / 12;

fprintf('    Target month: %.4f - %.4f (Year %d, Month %d)\n', ...
    monthStart, monthEnd, valYear, valMonth);

%% Define Training Window (±1 year around target month)
% User requirement: use ±1 year temporal window
temporalWindow = 1.0;  % ±1 year in decimal years
windowStart = valYear - temporalWindow;
windowEnd = valYear + temporalWindow + 1/12;  % Add one month to include end

fprintf('    Training window: %.4f - %.4f (±%.1f years)\n', ...
    windowStart, windowEnd, temporalWindow);

%% Filter Observations to Training Window AND Training Stations
% Time indices within training window
inWindow = (obs.tME >= windowStart) & (obs.tME < windowEnd);

if sum(inWindow) == 0
    warning('No time periods in training window');
    monthResults = struct('nValid', 0);
    return;
end

% Create training dataset: training stations + training time window
trainObs = obs;
trainObs.sMS = obs.sMS(trainMask, :);
trainObs.Z = obs.Z(trainMask, inWindow);
trainObs.Y = obs.Y(trainMask, inWindow);
trainObs.tME = obs.tME(inWindow);

% Count valid training data
nTrainTotal = numel(trainObs.Z);
nTrainValid = sum(~isnan(trainObs.Z(:)));

fprintf('    Training data:\n');
fprintf('      Stations: %d\n', size(trainObs.sMS, 1));
fprintf('      Time periods: %d\n', length(trainObs.tME));
fprintf('      Valid observations: %d / %d (%.1f%%)\n', ...
    nTrainValid, nTrainTotal, 100*nTrainValid/nTrainTotal);

%% Prepare BME Knowledge Base from Training Data
fprintf('    Preparing BME knowledge base from training data...\n');
[KG, KS, ~] = getTOARknowledgeBase(trainObs, go, cov, [], BMEparam.BMEmethod8digits);

% Check sufficient training data
if isempty(KS.harddata.z) || length(KS.harddata.z) < 10
    warning('Insufficient training data points (%d)', length(KS.harddata.z));
    monthResults = struct('nValid', 0);
    return;
end

fprintf('      Training points in knowledge base: %d\n', length(KS.harddata.z));

%% Create Validation Locations (Only Target Month)
% Get validation stations
valStations = obs.sMS(valMask, :);

% For validation, only use the exact target month
targetMonthIdx = (obs.tME >= monthStart) & (obs.tME < monthEnd);
valTimes = obs.tME(targetMonthIdx);

if isempty(valTimes)
    warning('No time periods in target month');
    monthResults = struct('nValid', 0);
    return;
end

% Get observations at validation stations for target month
Y_obs_matrix = obs.Y(valMask, targetMonthIdx);  % [nValStations × nMonthTimes]
Z_obs_matrix = obs.Z(valMask, targetMonthIdx);

% Create all space-time combinations
nValStations = size(valStations, 1);
nMonthTimes = length(valTimes);

% Expand to all combinations
sk_all = repmat(valStations, nMonthTimes, 1);
tk_all = repelem(valTimes, nValStations);
Y_obs_all = reshape(Y_obs_matrix', [], 1);  % Vectorize observations
Z_obs_all = reshape(Z_obs_matrix', [], 1);

% IMPORTANT: Filter to only s/t locations WITH observational data
hasObs = ~isnan(Y_obs_all);
sk = sk_all(hasObs, :);
tk = tk_all(hasObs);
Y_obs = Y_obs_all(hasObs);
Z_obs = Z_obs_all(hasObs);

if isempty(sk)
    warning('No observations available at validation locations for target month');
    monthResults = struct('nValid', 0);
    return;
end

% Create estimation points
pk = [sk, tk];

fprintf('    Validation locations:\n');
fprintf('      Stations: %d\n', nValStations);
fprintf('      Time periods: %d\n', nMonthTimes);
fprintf('      Total s/t points with observations: %d\n', size(pk, 1));

%% Perform BME Estimation at Validation Locations
fprintf('    Performing BME estimation at validation locations...\n');
tic;

% Get BME method type
BMEmethod8digits = BMEparam.BMEmethod8digits;
BMEprobaType = str2double(BMEmethod8digits(8));

% Use krigingME_stug_multi for multi-soft datasets (following estTOARsBME.m pattern)
switch BMEprobaType
    case 3  % KrigingME with multi-soft data support (STUG format)
        % STUG format: fastest for large uniform grids
        % Reformat soft data for all datasets if it's a cell array
        if iscell(KS.softdata)
            soft_data = cell(size(KS.softdata));
            p_soft = cell(size(KS.softdata));
            z_soft = cell(size(KS.softdata));
            vs_soft = cell(size(KS.softdata));

            fprintf('      Multi-soft datasets detected: %d models\n', length(KS.softdata));
            for ii = 1:length(KS.softdata)
                soft_data{ii} = reformat_stg_to_stug(KS.softdata{ii});
                p_soft{ii} = KS.softdata{ii}.p;
                z_soft{ii} = KS.softdata{ii}.z;
                vs_soft{ii} = KS.softdata{ii}.vs;
            end
        else
            % Single soft dataset
            fprintf('      Single soft dataset\n');
            soft_data = reformat_stg_to_stug(KS.softdata);
            p_soft = KS.softdata.p;
            z_soft = KS.softdata.z;
            vs_soft = KS.softdata.vs;
        end

        fprintf('      Using krigingME_stug_multi (STUG format)...\n');
        [XkBMEm, XkBMEv] = krigingME_stug_multi(pk, KS.harddata.p, p_soft, ...
            KS.harddata.z, z_soft, vs_soft, ...
            KG.covmodel, KG.covparam, BMEparam.nhmax, BMEparam.nsmax, ...
            BMEparam.dmax, KG.order, BMEparam.options, KS.harddata, soft_data);

    case 2  % KrigingME (standard format based on dataFormat)
        switch BMEparam.dataFormat
            case 'stug'
                fprintf('      Using krigingME_stug (STUG format - single soft dataset)...\n');
                soft_data = reformat_stg_to_stug(KS.softdata);

                [XkBMEm, XkBMEv] = krigingME_stug(pk, KS.harddata.p, KS.softdata.p, ...
                    KS.harddata.z, KS.softdata.z, KS.softdata.vs, ...
                    KG.covmodel, KG.covparam, BMEparam.nhmax, BMEparam.nsmax, ...
                    BMEparam.dmax, KG.order, 0, KS.harddata, soft_data);

            otherwise
                % Use standard krigingME for other formats
                fprintf('      Using krigingME (standard format)...\n');
                [XkBMEm, XkBMEv] = krigingME(pk, KS.harddata.p, KS.softdata.p, ...
                    KS.harddata.z, KS.softdata.z, KS.softdata.vs, ...
                    KG.covmodel, KG.covparam, BMEparam.nhmax, BMEparam.nsmax, ...
                    BMEparam.dmax, KG.order, BMEparam.options);
        end

    otherwise
        error('Unsupported BME method type: %d', BMEprobaType);
end

elapsedTime = toc;
fprintf('      Estimation completed in %.1f seconds\n', elapsedTime);

% Ensure column vectors
if size(XkBMEm, 2) > 1, XkBMEm = XkBMEm'; end
if size(XkBMEv, 2) > 1, XkBMEv = XkBMEv'; end

% Replace NaNs in XkBMEm with 0s (in residual space)
XkBMEm(isnan(XkBMEm)) = 0;

%% Add Global Offset Back to Get Final Estimates
% XkBMEm is in residual space (GO removed)
% Need to add GO back to get estimates in original concentration space

% Interpolate global offset at validation points
gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, sk, unique(tk));

% Add global offset to residual estimates
YkBMEm = XkBMEm + gok;

%% Clean Up Variance Estimates
% Replace NaN variances with maximum valid variance
if any(isnan(XkBMEv))
    maxVar = max(XkBMEv(~isnan(XkBMEv)));
    if isempty(maxVar) || maxVar == 0
        maxVar = 100;  % Default if all NaN
    end
    XkBMEv(isnan(XkBMEv)) = maxVar;
end

% Ensure variance is real (remove tiny imaginary components)
if ~isreal(XkBMEv)
    XkBMEv = real(XkBMEv);
end

%% Final Validity Check
% Remove any remaining NaN pairs
validPairs = ~isnan(Y_obs) & ~isnan(YkBMEm);

nValid = sum(validPairs);
fprintf('      Valid prediction pairs: %d / %d (%.1f%%)\n', ...
    nValid, length(validPairs), 100*nValid/length(validPairs));

%% Package Monthly Results
monthResults.Y_obs = Y_obs(validPairs);           % Observed values (original space)
monthResults.Y_est = YkBMEm(validPairs);         % Estimated values (original space)
monthResults.Y_estNoGo = XkBMEm(validPairs);     % Estimates (residual space)
monthResults.sk = sk(validPairs, :);             % Spatial coordinates
monthResults.tk = tk(validPairs);                % Time coordinates
monthResults.XkBMEv = XkBMEv(validPairs);        % Estimation variances
monthResults.gok = gok(validPairs);              % Global offset values
monthResults.nTrain = length(KS.harddata.z);     % Number of training points
monthResults.nValid = nValid;                    % Number of valid pairs

if nValid > 0
    fprintf('      Monthly summary:\n');
    fprintf('        Obs range: [%.1f, %.1f] %s\n', ...
        min(monthResults.Y_obs), max(monthResults.Y_obs), obs.Zunit);
    fprintf('        Est range: [%.1f, %.1f] %s\n', ...
        min(monthResults.Y_est), max(monthResults.Y_est), obs.Zunit);
else
    warning('No valid validation pairs found for this month');
end

end
