function valResults = validateTOAR_monthly(obs, go, cov, BMEparam, valYear, valMonth)
% validateTOAR_monthly - Perform LOOCV for a single month
%
% SYNTAX:
%   valResults = validateTOAR_monthly(obs, go, cov, BMEparam, valYear, valMonth)
%
% INPUTS:
%   obs       - Observational data structure from getTOARobservationalData
%   go        - Global offset structure from getTOARglobalOffset
%   cov       - Covariance structure from getTOARautoCov
%   BMEparam  - BME parameters from getTOARknowledgeBase
%   valYear   - Year to validate (e.g., 2016)
%   valMonth  - Month to validate (1-12)
%
% OUTPUTS:
%   valResults - Structure with validation results for this month

%% Define Time Window for Target Month
% Month boundaries in decimal years
monthStart = valYear + (valMonth - 1) / 12;
monthEnd = valYear + valMonth / 12;

fprintf('    Target month: %.4f - %.4f (Year %d, Month %d)\n', ...
    monthStart, monthEnd, valYear, valMonth);

%% Define Training Window (month ± temporal search radius)
% dmax(2) is in months, need to convert to years (same units as obs.tME)
temporalWindow = BMEparam.dmax(2) / 12;  % convert months to years
windowStart = monthStart - temporalWindow;
windowEnd = monthEnd + temporalWindow;

fprintf('    Training window: %.4f - %.4f (±%.2f months = ±%.2f years)\n', ...
    windowStart, windowEnd, BMEparam.dmax(2), temporalWindow);

%% Filter Observations to Training Window
% Find time indices within training window
inWindow = (obs.tME >= windowStart) & (obs.tME < windowEnd);

if sum(inWindow) == 0
    warning('No time periods in training window');
    valResults = [];
    return;
end

% Create subset of obs structure with only training window data
dataStruct = obs;
dataStruct.Y = obs.Y(:, inWindow);
dataStruct.Z = obs.Z(:, inWindow);
dataStruct.tME = obs.tME(inWindow);

fprintf('    Time periods in window: %d\n', sum(inWindow));

%% Get Knowledge Base for Training Data
% This converts from STG to STV format and prepares hard/soft data
[KG, KS, ~] = getTOARknowledgeBase(dataStruct, go, cov, [], BMEparam.BMEmethod8digits);

% Check if we have sufficient data
if isempty(KS.harddata.p) || length(KS.harddata.z) < 10
    warning('Too few hard data points (%d) for validation', length(KS.harddata.z));
    valResults = [];
    return;
end

fprintf('    Hard data points in window: %d\n', length(KS.harddata.z));

%% Perform Leave-One-Out Cross Validation
% krigingME_Xvalidation performs LOOCV internally
% Option 1 means validate at hard data locations only
fprintf('    Performing LOOCV using krigingME_Xvalidation...\n');
tic;

[XkBMEm, XkBMEv, ~, ~, ~] = krigingME_Xvalidation(1, ...
    KS.harddata.p, KS.softdata.p, KS.harddata.z, KS.softdata.z, KS.softdata.vs, ...
    KG.covmodel, KG.covparam, BMEparam.nhmax, BMEparam.nsmax, ...
    BMEparam.dmax, BMEparam.order, BMEparam.options);

elapsedTime = toc;
fprintf('    LOOCV completed in %.1f seconds\n', elapsedTime);

%% Filter Results to Target Month Only
% krigingME_Xvalidation returns estimates for ALL points in training window
% We only want results for points in the exact target month

% Transpose if needed (make column vectors)
if size(XkBMEm, 2) > 1, XkBMEm = XkBMEm'; end
if size(XkBMEv, 2) > 1, XkBMEv = XkBMEv'; end

% Extract coordinates and times from KS.harddata.p
pk_all = KS.harddata.p;  % [nPoints x 3] where columns are [lon, lat, time]
z_all = KS.harddata.z;   % Observed residuals

% Filter to exact target month
inTargetMonth = (pk_all(:,3) >= monthStart) & (pk_all(:,3) < monthEnd);

if sum(inTargetMonth) == 0
    warning('No observations in exact target month after filtering');
    valResults = [];
    return;
end

% Extract target month data
pk_month = pk_all(inTargetMonth, :);
XkBMEm_month = XkBMEm(inTargetMonth);
XkBMEv_month = XkBMEv(inTargetMonth);
z_month = z_all(inTargetMonth);

fprintf('    Points in target month: %d\n', sum(inTargetMonth));

%% Add Global Offset Back to Get Final Estimates
% XkBMEm is in residual space (with GO removed)
% Need to add GO back to get estimates in original space

% Interpolate global offset at validation points
gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, pk_month(:,1:2), unique(pk_month(:,3)));

% Add global offset to residual estimates
YkBMEm = XkBMEm_month + gok;

% Also get observed values in original space
% z_month is observed residuals, add GO back to get observed concentrations
Y_obs = z_month + gok;

%% Clean Up Variance Estimates
% Replace NaN variances with maximum valid variance
XkBMEv_month(isnan(XkBMEv_month)) = max(XkBMEv_month(~isnan(XkBMEv_month)));

% Ensure variance is real (remove tiny imaginary components from numerical errors)
if ~isreal(XkBMEv_month)
    XkBMEv_month = real(XkBMEv_month);
end

%% Remove Any Remaining NaN Pairs
validPairs = ~isnan(Y_obs) & ~isnan(YkBMEm);

%% Package Results
valResults.Y_obs = Y_obs(validPairs);           % Observed values (original space)
valResults.Y_est = YkBMEm(validPairs);         % Estimated values (original space)
valResults.Y_estNoGo = XkBMEm_month(validPairs); % Estimates (residual space)
valResults.sk = pk_month(validPairs, 1:2);     % Spatial coordinates
valResults.tk = pk_month(validPairs, 3);       % Time coordinates
valResults.XkBMEv = XkBMEv_month(validPairs);  % Estimation variances
valResults.gok = gok(validPairs);              % Global offset values

nValid = sum(validPairs);
fprintf('    Valid pairs returned: %d\n', nValid);

if nValid > 0
    fprintf('    Obs range: [%.1f, %.1f] %s\n', ...
        min(valResults.Y_obs), max(valResults.Y_obs), obs.Zunit);
    fprintf('    Est range: [%.1f, %.1f] %s\n', ...
        min(valResults.Y_est), max(valResults.Y_est), obs.Zunit);
end

end
