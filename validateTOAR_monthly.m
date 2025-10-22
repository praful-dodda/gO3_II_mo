function valResults = validateTOAR_monthly(obs, go, cov, BMEparam, valYear, valMonth)
% validateTOAR_monthly - Perform LOOCV for a single month
%
% SYNTAX:
%   valResults = validateTOAR_monthly(obs, go, cov, BMEparam, valYear, valMonth)
%
% INPUTS:
%   obs       - Observational data structure
%   go        - Global offset structure
%   cov       - Covariance structure
%   BMEparam  - BME parameters
%   valYear   - Year to validate (e.g., 2016)
%   valMonth  - Month to validate (1-12)
%
% OUTPUTS:
%   valResults - Structure with validation results for this month

%% Define Time Window
% Target month boundaries
monthStart = valYear + (valMonth - 1) / 12;
monthEnd = valYear + valMonth / 12;

% Temporal window for training data (month ± search radius)
temporalWindow = BMEparam.dmax(2);  % in years
windowStart = monthStart - temporalWindow;
windowEnd = monthEnd + temporalWindow;

fprintf('    Target month: %.4f - %.4f\n', monthStart, monthEnd);
fprintf('    Training window: %.4f - %.4f (±%.2f years)\n', ...
    windowStart, windowEnd, temporalWindow);

%% Filter Observations to Time Window
% Find observations within the training window
inWindow = (obs.tME >= windowStart) & (obs.tME < windowEnd);

if sum(inWindow) == 0
    warning('No observations in time window');
    valResults = [];
    return;
end

% Extract subset
tME_window = obs.tME(inWindow);
Y_window = obs.Y(:, inWindow);

fprintf('    Time periods in window: %d\n', sum(inWindow));

%% Convert to Space-Time Format
% Convert from STG to STV format
[ch, zh] = valstg2stv(Y_window, obs.sMS, tME_window);

% Remove NaN values
validIdx = ~isnan(zh);
ch = ch(validIdx, :);
zh = zh(validIdx);

nObs = length(zh);
fprintf('    Valid observations: %d\n', nObs);

if nObs < 10
    warning('Too few observations (%d) for validation', nObs);
    valResults = [];
    return;
end

%% Remove Global Offset in Batches
fprintf('    Removing global offset...\n');

% Process in batches to avoid memory issues
batchSize = 5000;
goh = NaN(nObs, 1);

for iBatch = 1:batchSize:nObs
    idxBatch = iBatch:min(iBatch + batchSize - 1, nObs);
    goh(idxBatch) = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, ...
        ch(idxBatch, 1:2), ch(idxBatch, 3));

    if mod(iBatch, 10000) == 1 && iBatch > 1
        fprintf('      Processed %d/%d observations\n', iBatch, nObs);
    end
end

% Residuals (remove GO)
xh = zh - goh;

%% Perform Leave-One-Out Cross Validation
fprintf('    Performing LOOCV...\n');
tic;

XkBMEm = NaN(nObs, 1);
XkBMEv = NaN(nObs, 1);

% Progress tracking
progressInterval = max(1, floor(nObs / 20));  % Update every 5%

for i = 1:nObs
    if mod(i, progressInterval) == 0
        fprintf('      Progress: %d/%d (%.0f%%)\n', i, nObs, 100*i/nObs);
    end

    % Estimation point
    pk = ch(i, :);

    % Training data (all except i)
    ch_train = ch([1:i-1, i+1:end], :);
    xh_train = xh([1:i-1, i+1:end]);

    % Skip if not in exact target month
    if pk(3) < monthStart || pk(3) >= monthEnd
        continue;
    end

    try
        % Perform kriging (hard data only, no soft data for validation)
        [moments, ~] = BMEprobaMoments(pk, ch_train, [], xh_train, ...
            [], [], [], [], cov.covmodel, cov.covparam, ...
            BMEparam.nhmax, 0, BMEparam.dmax, cov.order, []);

        XkBMEm(i) = moments(1);
        XkBMEv(i) = moments(2);
    catch ME
        warning('Kriging failed for observation %d: %s', i, ME.message);
        XkBMEm(i) = NaN;
        XkBMEv(i) = NaN;
    end
end

elapsedTime = toc;
fprintf('    LOOCV completed in %.1f seconds\n', elapsedTime);

%% Process Results
% Add global offset back
gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, ch(:, 1:2), ch(:, 3));
YkBMEm = XkBMEm + gok;

% Clean up variance
XkBMEv(isnan(XkBMEv)) = max(XkBMEv(~isnan(XkBMEv)));
XkBMEv = real(XkBMEv);

% Filter to exact month and valid predictions
inTargetMonth = (ch(:, 3) >= monthStart) & (ch(:, 3) < monthEnd);
validPredictions = ~isnan(YkBMEm);
keepIdx = inTargetMonth & validPredictions;

%% Package Results
valResults.Y_obs = zh(keepIdx);
valResults.Y_est = YkBMEm(keepIdx);
valResults.Y_estNoGo = XkBMEm(keepIdx);
valResults.sk = ch(keepIdx, 1:2);
valResults.tk = ch(keepIdx, 3);
valResults.XkBMEv = XkBMEv(keepIdx);
valResults.gok = gok(keepIdx);

nValid = sum(keepIdx);
fprintf('    Results for target month: %d valid pairs\n', nValid);

if nValid > 0
    fprintf('    Obs range: [%.1f, %.1f]\n', min(valResults.Y_obs), max(valResults.Y_obs));
    fprintf('    Est range: [%.1f, %.1f]\n', min(valResults.Y_est), max(valResults.Y_est));
end

end
