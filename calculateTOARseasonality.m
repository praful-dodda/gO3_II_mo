function seasonality = calculateTOARseasonality(obs, minDataPoints)
% calculateTOARseasonality - Calculate seasonal phase and amplitude for TOAR stations
%
% Analyzes seasonal patterns in ozone data, extracting peak timing and
% amplitude for each station. Useful for distinguishing NH/SH patterns.
%
% SYNTAX:
%   seasonality = calculateTOARseasonality(obs, minDataPoints)
%
% INPUTS:
%   obs            - Structure from getTOARobservationalData
%   minDataPoints  - Minimum valid months required per station (default: 24)
%
% OUTPUTS:
%   seasonality - Structure with fields:
%     .lat          - [nMS x 1] Station latitudes
%     .lon          - [nMS x 1] Station longitudes
%     .hemisphere   - [nMS x 1] 'NH' or 'SH' designation
%     .peakMonth    - [nMS x 1] Month of maximum ozone (1-12)
%     .minMonth     - [nMS x 1] Month of minimum ozone (1-12)
%     .climatology  - [nMS x 12] Monthly climatology (ppb)
%     .amplitude    - [nMS x 1] Seasonal amplitude (ppb)
%     .phase        - [nMS x 1] Phase from sine fit (degrees, 0-360)
%     .R2           - [nMS x 1] R² of sine fit
%     .annualMean   - [nMS x 1] Annual mean ozone (ppb)
%     .nValid       - [nMS x 1] Number of valid data points
%     .isValid      - [nMS x 1] Logical, meets quality criteria

if nargin < 2, minDataPoints = 24; end

nStations = size(obs.Z, 1);
nMonths = length(obs.tME);

fprintf('=== Calculating Seasonal Patterns ===\n');
fprintf('  Stations: %d\n', nStations);
fprintf('  Time periods: %d\n', nMonths);

%% Initialize Output
seasonality.lat = obs.sMS(:, 2);
seasonality.lon = obs.sMS(:, 1);
seasonality.hemisphere = cell(nStations, 1);
seasonality.peakMonth = NaN(nStations, 1);
seasonality.minMonth = NaN(nStations, 1);
seasonality.climatology = NaN(nStations, 12);
seasonality.amplitude = NaN(nStations, 1);
seasonality.phase = NaN(nStations, 1);
seasonality.R2 = NaN(nStations, 1);
seasonality.annualMean = NaN(nStations, 1);
seasonality.nValid = zeros(nStations, 1);
seasonality.isValid = false(nStations, 1);

%% Process Each Station
fprintf('  Processing stations');
for iStation = 1:nStations
    if mod(iStation, 100) == 0
        fprintf('.');
    end
    
    % Get time series
    Z_station = obs.Z(iStation, :);
    validData = ~isnan(Z_station);
    seasonality.nValid(iStation) = sum(validData);
    
    % Skip if insufficient data
    if sum(validData) < minDataPoints
        continue;
    end
    
    % Hemisphere designation
    lat = obs.sMS(iStation, 2);
    if lat > 0
        seasonality.hemisphere{iStation} = 'NH';
    else
        seasonality.hemisphere{iStation} = 'SH';
    end
    
    % Annual mean
    seasonality.annualMean(iStation) = mean(Z_station, 'omitnan');
    
    %% Calculate Monthly Climatology
    % Extract month from decimal year
    monthOfYear = mod(obs.tME - obs.tME(1), 1) * 12 + 1;
    monthOfYear = round(monthOfYear);
    monthOfYear(monthOfYear > 12) = 12;
    monthOfYear(monthOfYear < 1) = 1;
    
    for iMonth = 1:12
        monthMask = (monthOfYear == iMonth) & validData;
        if sum(monthMask) > 0
            seasonality.climatology(iStation, iMonth) = mean(Z_station(monthMask));
        end
    end
    
    % Skip if climatology has gaps
    if sum(~isnan(seasonality.climatology(iStation, :))) < 12
        continue;
    end
    
    %% Simple Peak/Min Month Detection
    [~, seasonality.peakMonth(iStation)] = max(seasonality.climatology(iStation, :));
    [~, seasonality.minMonth(iStation)] = min(seasonality.climatology(iStation, :));
    
    % Amplitude (peak-to-trough)
    seasonality.amplitude(iStation) = max(seasonality.climatology(iStation, :)) - ...
                                       min(seasonality.climatology(iStation, :));
    
    %% Sinusoidal Fit
    % Fit: O3(month) = A + B*sin(2*pi*month/12 + phi)
    monthVec = 1:12;
    climatology_detrend = seasonality.climatology(iStation, :) - seasonality.annualMean(iStation);
    
    % Initial guess: [amplitude, phase]
    % Phase in radians, convert peak month to phase
    initialPhase = 2*pi*(seasonality.peakMonth(iStation) - 3)/12;  % Peak at phase=pi/2
    initialAmp = seasonality.amplitude(iStation) / 2;
    
    try
        % Fit function
        fitfun = @(p, x) p(1) * sin(2*pi*x/12 + p(2));
        
        % Nonlinear least squares
        options = optimset('Display', 'off');
        params = lsqcurvefit(fitfun, [initialAmp, initialPhase], ...
            monthVec, climatology_detrend, [-inf, -2*pi], [inf, 2*pi], options);
        
        % Extract results
        fittedAmp = abs(params(1));
        fittedPhase = params(2);
        
        % Normalize phase to 0-360 degrees
        fittedPhase = mod(fittedPhase * 180/pi, 360);
        seasonality.phase(iStation) = fittedPhase;
        
        % Calculate R²
        fitted = fitfun(params, monthVec);
        residuals = climatology_detrend - fitted;
        SSres = sum(residuals.^2);
        SStot = sum((climatology_detrend - mean(climatology_detrend)).^2);
        seasonality.R2(iStation) = 1 - SSres/SStot;
        
    catch
        % If fit fails, use NaN
        seasonality.phase(iStation) = NaN;
        seasonality.R2(iStation) = NaN;
    end
    
    %% Quality Check
    % Valid if: sufficient data, good fit, reasonable amplitude
    seasonality.isValid(iStation) = ...
        seasonality.nValid(iStation) >= minDataPoints && ...
        seasonality.R2(iStation) > 0.3 && ...
        seasonality.amplitude(iStation) > 2;  % At least 2 ppb seasonality
end

fprintf(' Done.\n');

%% Summary Statistics
validStations = sum(seasonality.isValid);
NHstations = sum(strcmp(seasonality.hemisphere, 'NH') & seasonality.isValid);
SHstations = sum(strcmp(seasonality.hemisphere, 'SH') & seasonality.isValid);

fprintf('\n  Summary:\n');
fprintf('    Valid stations: %d / %d (%.1f%%)\n', validStations, nStations, 100*validStations/nStations);
fprintf('    Northern Hemisphere: %d\n', NHstations);
fprintf('    Southern Hemisphere: %d\n', SHstations);

% NH statistics
if NHstations > 0
    NHmask = strcmp(seasonality.hemisphere, 'NH') & seasonality.isValid;
    fprintf('    NH peak month: %.1f ± %.1f (mean ± std)\n', ...
        mean(seasonality.peakMonth(NHmask)), std(seasonality.peakMonth(NHmask)));
    fprintf('    NH amplitude: %.1f ± %.1f ppb\n', ...
        mean(seasonality.amplitude(NHmask)), std(seasonality.amplitude(NHmask)));
end

% SH statistics
if SHstations > 0
    SHmask = strcmp(seasonality.hemisphere, 'SH') & seasonality.isValid;
    SHpeaks = seasonality.peakMonth(SHmask);
    % Adjust for circular mean (handle Dec-Jan wrap)
    SHpeaks_adj = SHpeaks;
    SHpeaks_adj(SHpeaks < 6) = SHpeaks(SHpeaks < 6) + 12;
    fprintf('    SH peak month: %.1f ± %.1f (mean ± std)\n', ...
        mod(mean(SHpeaks_adj), 12), std(SHpeaks_adj));
    fprintf('    SH amplitude: %.1f ± %.1f ppb\n', ...
        mean(seasonality.amplitude(SHmask)), std(seasonality.amplitude(SHmask)));
end

fprintf('===================================\n\n');

end