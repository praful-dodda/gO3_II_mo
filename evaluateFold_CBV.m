function foldResults = evaluateFold_CBV(obs, go, cov, BMEparam, trainMask, valMask, valParam)
% evaluateFold_CBV - Evaluate a single checkerboard validation fold
%
% Trains BME model on training set (defined by trainMask) and validates
% on validation set (defined by valMask). This is the core function for
% checker-board validation.
%
% SYNTAX:
%   foldResults = evaluateFold_CBV(obs, go, cov, BMEparam, trainMask, valMask, valParam)
%
% INPUTS:
%   obs       - Observational data structure from getTOARobservationalData
%   go        - Global offset structure from getTOARglobalOffset
%   cov       - Covariance structure from getTOARautoCov
%   BMEparam  - BME parameters from getBMEparam
%   trainMask - nStations × 1 logical array (true = use for training)
%   valMask   - nStations × 1 logical array (true = use for validation)
%   valParam  - Validation parameters structure with fields:
%               .valYears  - Years to validate
%               .valMonths - Months to validate
%
% OUTPUTS:
%   foldResults - Structure with validation results:
%                 .Y_obs      - Observed values at validation points
%                 .Y_est      - Estimated values at validation points
%                 .Y_estNoGo  - Estimates in residual space (without GO)
%                 .sk         - Spatial coordinates of validation points
%                 .tk         - Temporal coordinates of validation points
%                 .XkBMEv     - Estimation variances
%                 .gok        - Global offset at validation points
%                 .nTrain     - Number of training points
%                 .nVal       - Number of validation points
%
% DESCRIPTION:
%   This function implements one fold of checker-board validation:
%   1. Creates training dataset from obs using trainMask
%   2. Creates validation dataset from obs using valMask
%   3. Prepares BME knowledge base using training data only
%   4. Estimates at validation locations using trained model
%   5. Computes metrics comparing predictions to validation observations
%
% EXAMPLE:
%   [trainMask, valMask] = getCheckerBoard(obs.sMS, 5, 1);
%   results = evaluateFold_CBV(obs, go, cov, BMEparam, trainMask, valMask, valParam);
%   stats = calculateValidationStats(results.Y_obs, results.Y_est);

%% Input Validation
if nargin < 7
    error('All 7 inputs required');
end

% Ensure masks are logical column vectors
if ~islogical(trainMask)
    trainMask = logical(trainMask);
end
if ~islogical(valMask)
    valMask = logical(valMask);
end

trainMask = trainMask(:);
valMask = valMask(:);

%% Filter Data to Requested Time Period
% Create time mask for requested years and months
timeMask = false(size(obs.tME));
for iYear = valParam.valYears
    for iMonth = valParam.valMonths
        monthStart = iYear + (iMonth - 1) / 12;
        monthEnd = iYear + iMonth / 12;
        timeMask = timeMask | ((obs.tME >= monthStart) & (obs.tME < monthEnd));
    end
end

if sum(timeMask) == 0
    error('No time periods match requested years/months');
end

fprintf('  Time periods selected: %d\n', sum(timeMask));

%% Create Training Dataset
% Training set: subset of obs using only training stations
trainObs = obs;
trainObs.sMS = obs.sMS(trainMask, :);
trainObs.Z = obs.Z(trainMask, timeMask);
trainObs.Y = obs.Y(trainMask, timeMask);
trainObs.tME = obs.tME(timeMask);

% Count valid training data
nTrainTotal = numel(trainObs.Z);
nTrainValid = sum(~isnan(trainObs.Z(:)));

fprintf('  Training data:\n');
fprintf('    Stations: %d\n', size(trainObs.sMS, 1));
fprintf('    Time periods: %d\n', length(trainObs.tME));
fprintf('    Valid observations: %d / %d (%.1f%%)\n', ...
    nTrainValid, nTrainTotal, 100*nTrainValid/nTrainTotal);

%% Prepare BME Knowledge Base from Training Data
% Convert training data to knowledge base format
% This removes global offset and prepares data for BME
fprintf('  Preparing BME knowledge base from training data...\n');
[KG, KS, ~] = getTOARknowledgeBase(trainObs, go, cov, [], BMEparam.BMEmethod8digits);

% Check sufficient training data
if isempty(KS.harddata.z) || length(KS.harddata.z) < 10
    error('Insufficient training data points (%d)', length(KS.harddata.z));
end

fprintf('    Training points in knowledge base: %d\n', length(KS.harddata.z));

%% Create Validation Locations
% Validation set: all space-time points at validation stations
valStations = obs.sMS(valMask, :);
valTimes = obs.tME(timeMask);

% Create all combinations of validation stations × times
nValStations = size(valStations, 1);
nTimes = length(valTimes);

% Estimation grid: all validation station × time combinations
sk = repmat(valStations, nTimes, 1);  % Repeat stations for each time
tk = reshape(repmat(valTimes, nValStations, 1), [], 1);  % Repeat times for each station
ck = [sk, tk];  % Combine to [lon, lat, time]

fprintf('  Validation locations:\n');
fprintf('    Stations: %d\n', nValStations);
fprintf('    Time periods: %d\n', nTimes);
fprintf('    Total estimation points: %d\n', size(ck, 1));

%% Perform BME Estimation at Validation Locations
fprintf('  Performing BME estimation at validation locations...\n');
tic;

% Use krigingME for estimation (matches LOOCV approach)
[XkBMEm, XkBMEv] = krigingME(ck, ...
    KS.harddata.p, KS.softdata.p, KS.harddata.z, KS.softdata.z, KS.softdata.vs, ...
    KG.covmodel, KG.covparam, BMEparam.nhmax, BMEparam.nsmax, ...
    BMEparam.dmax, KG.order, BMEparam.options);

elapsedTime = toc;
fprintf('    Estimation completed in %.1f seconds\n', elapsedTime);

% Ensure column vectors
if size(XkBMEm, 2) > 1, XkBMEm = XkBMEm'; end
if size(XkBMEv, 2) > 1, XkBMEv = XkBMEv'; end

%% Add Global Offset Back
% XkBMEm is in residual space (GO removed)
% Need to add GO back to get estimates in original concentration space

% Interpolate global offset at validation points
gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, sk, unique(tk));

% Add global offset to residual estimates
YkBMEm = XkBMEm + gok;

%% Extract Observed Values at Validation Locations
% Need to extract observations at validation stations/times
Y_obs_full = obs.Y(valMask, timeMask);  % [nValStations × nTimes]

% Reshape to match estimation grid order (stations repeated for each time)
Y_obs = reshape(Y_obs_full', [], 1);  % Transpose then vectorize

% Also get observed residuals
Z_obs_full = obs.Z(valMask, timeMask);
Z_obs = reshape(Z_obs_full', [], 1);

%% Clean Up Results
% Replace NaN variances with maximum valid variance
if any(isnan(XkBMEv))
    maxVar = max(XkBMEv(~isnan(XkBMEv)));
    if isempty(maxVar)
        maxVar = 100;  % Default if all NaN
    end
    XkBMEv(isnan(XkBMEv)) = maxVar;
end

% Ensure variance is real
if ~isreal(XkBMEv)
    XkBMEv = real(XkBMEv);
end

%% Remove NaN Pairs (where observations don't exist)
validPairs = ~isnan(Y_obs) & ~isnan(YkBMEm);

fprintf('  Valid prediction pairs: %d / %d (%.1f%%)\n', ...
    sum(validPairs), length(validPairs), 100*sum(validPairs)/length(validPairs));

%% Package Results
foldResults.Y_obs = Y_obs(validPairs);           % Observed values (original space)
foldResults.Y_est = YkBMEm(validPairs);         % Estimated values (original space)
foldResults.Y_estNoGo = XkBMEm(validPairs);     % Estimates (residual space)
foldResults.sk = sk(validPairs, :);             % Spatial coordinates
foldResults.tk = tk(validPairs);                % Time coordinates
foldResults.XkBMEv = XkBMEv(validPairs);        % Estimation variances
foldResults.gok = gok(validPairs);              % Global offset values
foldResults.nTrain = length(KS.harddata.z);     % Number of training points
foldResults.nVal = sum(validPairs);             % Number of validation points

if foldResults.nVal > 0
    fprintf('  Validation summary:\n');
    fprintf('    Obs range: [%.1f, %.1f] %s\n', ...
        min(foldResults.Y_obs), max(foldResults.Y_obs), obs.Zunit);
    fprintf('    Est range: [%.1f, %.1f] %s\n', ...
        min(foldResults.Y_est), max(foldResults.Y_est), obs.Zunit);
else
    warning('No valid validation pairs found');
end

end
