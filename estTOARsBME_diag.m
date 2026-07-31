function estTOARsBME_diag(obs, go, cov, KG, KS, BMEparam, estParam, diagParam, dispParam)
% estTOARsBME_diag - Diagnostic BME estimation to identify causes of variance map stripes
%
% Tests different parameter combinations to identify what causes vertical
% stripes in variance/uncertainty maps:
%   1. Lambda2 scaling (soft data variance) - tests if variance magnitude matters
%   2. Grid offset - tests if estimation grid alignment with soft data grid matters
%   3. Grid resolution - tests if estimation grid granularity affects stripes
%
% SYNTAX:
%   estTOARsBME_diag(obs, go, cov, KG, KS, BMEparam, estParam)
%   estTOARsBME_diag(obs, go, cov, KG, KS, BMEparam, estParam, diagParam)
%
% INPUTS:
%   obs      - Structure from getTOARobservationalData
%   go       - Structure from getTOARglobalOffset
%   cov      - Structure from getTOARautoCov
%   KG       - General Knowledge from getTOARknowledgeBase
%   KS       - Site-specific Knowledge from getTOARknowledgeBase
%   BMEparam - BME parameters from getTOARknowledgeBase
%   estParam - Estimation parameters structure (same as estTOARsBMEoptim)
%   diagParam - Diagnostic parameters structure (see below)
%
% DIAGNOSTIC PARAMETERS (diagParam):
%   diagParam.lambda2Scales   - Variance multipliers [0, 0.5, 1.0, 2.0, 5.0, 10]
%   diagParam.gridOffsets     - Grid offsets in degrees [0, 0.125, 0.25]
%   diagParam.gridResolutions - Grid resolutions in degrees [2, 1, 0.5, 0.25, 0.1]
%   diagParam.runMode         - 'lambda2', 'gridOffset', 'both', or 'gridResolution'
%
% OUTPUTS:
%   Saves results to ./5BMEspatialPlots/diagnostic/
%   File naming: diag_res{res}_lambda{l}_offset{o}_time{t}.mat
%   Generates comparison figure showing all scenarios side-by-side
%
% INTERPRETATION:
%   - If stripes disappear with lambda2Scale=0: variance values cause stripes
%   - If stripes disappear with gridOffset>0: grid alignment causes stripes
%   - If stripes change with gridResolution: estimation grid granularity affects stripes

%% ========== DIAGNOSTIC PARAMETERS ==========
% Edit these to customize the diagnostic tests
if nargin < 8 || isempty(diagParam)
    diagParam = struct();
    % Lambda2 (soft data variance) scaling factors
    % 0 = treat soft data as hard data (no measurement error)
    % 1 = original variance (baseline)
    diagParam.lambda2Scales = [0, 0.5, 1.0, 2.0, 5.0, 10];

    % Grid offset in degrees (to test alignment effects)
    % Soft data is typically 0.5° resolution
    % Offset by fractions of that resolution
    diagParam.gridOffsets = [0, 0.125, 0.25];

    % Grid resolution for estimation
    diagParam.gridResolutions = [2, 1, 0.5, 0.25, 0.1];
    diagParam.gridResolutions = 1;

    % Run mode: 'lambda2', 'gridOffset', 'both' or 'gridResolution'
    diagParam.runMode = 'gridResolution';

    % Generate comparison figure at end
    diagParam.generateComparison = false;
end

if nargin < 9 || isempty(dispParam)
    dispParam = struct();
    dispParam.nxpix = 150;            % Number of pixels in x-direction
    dispParam.nypix = 100;            % Number of pixels in y-direction
    dispParam.bufferDist = 0.5;      % Buffer distance for masking (degrees)
    dispParam.bufferType = 'soft';  % 'soft' (gradual fade) or 'hard' (sharp cut)
    dispParam.interpMethod = 'natural';  % Interpolation method for griddata
    dispParam.dxRes = [];             % x-direction grid resolution in degrees (overrides nxpix if provided)
    dispParam.dyRes = [];             % y-direction grid resolution in degrees (overrides nypix if provided)
end

% =============================================

%% Input Validation
if nargin < 7
    error('All 7 input arguments required. See help estTOARsBME_diag');
end

% Validate estParam fields
requiredFields = {'areaCode', 'mapResolution', 'tkVec', 'forceEstimation', 'plotResults'};
for i = 1:length(requiredFields)
    if ~isfield(estParam, requiredFields{i})
        error('estParam missing required field: %s', requiredFields{i});
    end
end

%% Setup
fprintf('\n');
fprintf('============================================================\n');
fprintf('  DIAGNOSTIC BME ESTIMATION - Testing Variance Map Stripes\n');
fprintf('============================================================\n\n');

% Extract parameters
areaCode = estParam.areaCode;
mapResolution = estParam.mapResolution;
tkVec = estParam.tkVec;

% Get BME method info
BMEmethod8digits = BMEparam.BMEmethod8digits;
BMEprobaType = str2double(BMEmethod8digits(8));

% Create diagnostic output directory
diagDir = fullfile('5BMEspatialPlots', 'diagnostic');
if ~exist(diagDir, 'dir')
    mkdir(diagDir);
end

fprintf('Configuration:\n');
fprintf('  BME method: %s\n', BMEmethod8digits);
fprintf('  Global offset scenario: %d\n', go.scenario);
fprintf('  Area code: %d\n', areaCode);
fprintf('  Map resolution: %.2f degrees\n', mapResolution);
fprintf('  Time periods: %d\n', length(tkVec));
fprintf('\nDiagnostic scenarios:\n');
fprintf('  Lambda2 scales: %s\n', mat2str(diagParam.lambda2Scales));
fprintf('  Grid offsets: %s\n', mat2str(diagParam.gridOffsets));
fprintf('  Grid resolutions: %s\n', mat2str(diagParam.gridResolutions));
fprintf('  Run mode: %s\n', diagParam.runMode);
fprintf('\n');

%% Get Area Boundaries
% Area boundaries are needed for filtering grids in the main loop
[axMS_est, ~] = getTOARareaBoundaries(areaCode);
fprintf('Estimation area: [%.1f, %.1f] x [%.1f, %.1f]\n', axMS_est(1), axMS_est(2), axMS_est(3), axMS_est(4));

%% Reformat soft data for STUG
if ~strcmpi(BMEparam.dataFormat, 'stug')
    error('Diagnostic only supports dataFormat ''stug''');
end

fprintf('Preparing soft data (STUG format)...\n');

if iscell(KS.softdata)
    nSoftDatasets = length(KS.softdata);
    soft_data = cell(size(KS.softdata));
    p_soft = cell(size(KS.softdata));
    z_soft = cell(size(KS.softdata));
    vs_soft_base = cell(size(KS.softdata));  % Base variance (unscaled)

    for ii = 1:nSoftDatasets
        soft_data{ii} = reformat_stg_to_stug(KS.softdata{ii}, 'modelName', KS.softdata{ii}.modelName, 'resolution', 0.5);
        p_soft{ii} = KS.softdata{ii}.p;
        z_soft{ii} = KS.softdata{ii}.z;
        % Full-cube (Zvar(:)) variance, index-aligned with the sub2ind index from
        % neighbours_stug_optimized; KS.softdata{ii}.vs is compact (valid-only) and mis-indexes.
        vs_soft_base{ii} = soft_data{ii}.vs;  % Store base variance
        fprintf('  Soft dataset %d: %d points\n', ii, length(z_soft{ii}));
    end
elseif ~isempty(KS.softdata)
    nSoftDatasets = 1;
    soft_data = reformat_stg_to_stug(KS.softdata);
    p_soft = soft_data.p;
    z_soft = soft_data.z;
    vs_soft_base = soft_data.vs;
else
    error('No soft data available for diagnostic');
end

%% Determine scenarios to run
switch diagParam.runMode
    case 'lambda2'
        lambda2Scales = diagParam.lambda2Scales;
        gridOffsets = 0;  % Only baseline
        gridResolutions = mapResolution;  % Only baseline
    case 'gridOffset'
        lambda2Scales = 1.0;  % Only baseline
        gridOffsets = diagParam.gridOffsets;
        gridResolutions = mapResolution;  % Only baseline
    case 'both'
        lambda2Scales = diagParam.lambda2Scales;
        gridOffsets = diagParam.gridOffsets;
        gridResolutions = mapResolution;  % Only baseline
    case 'gridResolution'
        lambda2Scales = 1.0;  % Only baseline
        gridOffsets = 0;  % Only baseline
        gridResolutions = diagParam.gridResolutions;
    otherwise
        error('Invalid runMode: %s. Valid options: lambda2, gridOffset, both, gridResolution', diagParam.runMode);
end

nLambda = length(lambda2Scales);
nOffset = length(gridOffsets);
nResolution = length(gridResolutions);
nScenarios = nLambda * nOffset * nResolution;

if strcmp(diagParam.runMode, 'gridResolution')
    fprintf('\nRunning %d scenarios (%d resolutions)\n', nScenarios, nResolution);
else
    fprintf('\nRunning %d scenarios (%d lambda2 x %d offsets)\n', nScenarios, nLambda, nOffset);
end

%% Storage for results
% Store results for each scenario (for comparison plot)
results = struct();
results.lambda2Scales = lambda2Scales;
results.gridOffsets = gridOffsets;
results.gridResolutions = gridResolutions;
results.XkBMEm = cell(nLambda, nOffset, nResolution);
results.XkBMEv = cell(nLambda, nOffset, nResolution);
results.sk = cell(nLambda, nOffset, nResolution);

%% Main Diagnostic Loop
tk = tkVec(1);  % Use first time period for diagnostic
fprintf('\nUsing time period: %.4f\n', tk);

scenarioCount = 0;
for iRes = 1:nResolution
    currentResolution = gridResolutions(iRes);

    % Create base grid for this resolution
    fprintf('\n=== Resolution %.2f degrees ===\n', currentResolution);
    sk_base_res = getTOARmapGrid(currentResolution, estParam.keepOnlyLand, estParam.includeAntarctica);

    % Add locations of monitoring sites
    sk_base_res = [sk_base_res; obs.sMS];

    % Remove duplicate points
    [~, uniqueIdx] = unique(sk_base_res, 'rows');
    sk_base_res = sk_base_res(uniqueIdx, :);

    % Filter grid to estimation area
    inArea = (sk_base_res(:,1) >= axMS_est(1)) & (sk_base_res(:,1) <= axMS_est(2)) & ...
             (sk_base_res(:,2) >= axMS_est(3)) & (sk_base_res(:,2) <= axMS_est(4));
    sk_base_res = sk_base_res(inArea, :);

    fprintf('  Grid for resolution %.2f: %d points\n', currentResolution, size(sk_base_res, 1));

    for iLambda = 1:nLambda
        lambda2Scale = lambda2Scales(iLambda);

        % Scale soft data variance
        if iscell(vs_soft_base)
            vs_soft_scaled = cell(size(vs_soft_base));
            for ii = 1:length(vs_soft_base)
                if lambda2Scale == 0
                    % Use very small variance (effectively hard data)
                    vs_soft_scaled{ii} = ones(size(vs_soft_base{ii})) * 1e-6;
                else
                    vs_soft_scaled{ii} = vs_soft_base{ii} * lambda2Scale;
                end
            end
        else
            if lambda2Scale == 0
                vs_soft_scaled = ones(size(vs_soft_base)) * 1e-6;
            else
                vs_soft_scaled = vs_soft_base * lambda2Scale;
            end
        end

        for iOffset = 1:nOffset
            gridOffset = gridOffsets(iOffset);
            scenarioCount = scenarioCount + 1;

            fprintf('\n--- Scenario %d/%d: res=%.2f, lambda2=%.2f, offset=%.3f ---\n', ...
                scenarioCount, nScenarios, currentResolution, lambda2Scale, gridOffset);

            % Check if already estimated
            scenarioFile = sprintf('diag_res%.2f_lambda%.1f_offset%.3f_time%.2f.mat', ...
                currentResolution, lambda2Scale, gridOffset, tk);
            scenarioPath = fullfile(diagDir, scenarioFile);

            if exist(scenarioPath, 'file') && ~estParam.forceEstimation
                fprintf('  Results exist, loading: %s\n', scenarioFile);
                loaded = load(scenarioPath, 'BMEs');
                % Store for comparison plot
                results.XkBMEm{iLambda, iOffset, iRes} = loaded.BMEs.XkBMEm;
                results.XkBMEv{iLambda, iOffset, iRes} = loaded.BMEs.XkBMEv;
                results.sk{iLambda, iOffset, iRes} = loaded.BMEs.sk;

                % Plot if requested
                if estParam.plotResults > 0
                    % Create scenario-specific plot directory
                    scenarioPlotDir = fullfile(diagDir, sprintf('res%.2f_lambda%.1f_offset%.3f', currentResolution, lambda2Scale, gridOffset));
                    if ~exist(scenarioPlotDir, 'dir')
                        mkdir(scenarioPlotDir);
                    end
                    estParam.figDir = scenarioPlotDir;

                    plotTOARsBME(obs, go, loaded.BMEs, BMEparam, estParam, dispParam);
                    plotTOARsBMEvar(obs, go, loaded.BMEs, BMEparam, estParam, dispParam);
                end
                continue;
            end

            % Apply grid offset
            sk = sk_base_res;
            if gridOffset ~= 0
                sk(:,1) = sk(:,1) + gridOffset;  % Offset longitude
                sk(:,2) = sk(:,2) + gridOffset;  % Offset latitude
                fprintf('  Grid offset applied: +%.3f degrees\n', gridOffset);
            end

            % Store grid for this scenario
            results.sk{iLambda, iOffset, iRes} = sk;

            % Create space-time estimation points
            pk = [sk, tk * ones(size(sk, 1), 1)];

            % Perform BME estimation
            fprintf('  Estimating %d points...\n', size(pk, 1));
            tic;

            [XkBMEm, XkBMEv] = krigingME_stug_multi(pk, KS.harddata.p, p_soft, KS.harddata.z, ...
                z_soft, vs_soft_scaled, KG.covmodel, KG.covparam, BMEparam.nhmax, BMEparam.nsmax, ...
                BMEparam.dmax, BMEparam.order, BMEparam.options, KS.harddata, soft_data);

            elapsedTime = toc;
            fprintf('  Completed in %.1f seconds\n', elapsedTime);

            % QC check
            nNaNs = sum(isnan(XkBMEm));
            nNegVar = sum(XkBMEv < 0);
            fprintf('  QC: %d NaN means, %d negative variances\n', nNaNs, nNegVar);

            % Clean up
            XkBMEm(isnan(XkBMEm)) = 0;
            XkBMEv(XkBMEv < 0) = 0;
            XkBMEv = real(XkBMEv);

            % Store results
            results.XkBMEm{iLambda, iOffset, iRes} = XkBMEm;
            results.XkBMEv{iLambda, iOffset, iRes} = XkBMEv;

            % Save individual scenario result
            scenarioFile = sprintf('diag_res%.2f_lambda%.1f_offset%.3f_time%.2f.mat', ...
                currentResolution, lambda2Scale, gridOffset, tk);
            scenarioPath = fullfile(diagDir, scenarioFile);

            % Add global offset back to get final predictions
            gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, sk, tk);
            YkBMEm = XkBMEm + gok;

            % Package results (full structure for plotting)
            BMEs = struct();
            BMEs.sk = sk;
            BMEs.tk = tk;
            BMEs.XkBMEm = XkBMEm;
            BMEs.XkBMEv = XkBMEv;
            BMEs.gok = gok;
            BMEs.YkBMEm = YkBMEm;
            BMEs.lambda2Scale = lambda2Scale;
            BMEs.gridOffset = gridOffset;
            BMEs.gridResolution = currentResolution;
            BMEs.estGridArea = axMS_est;
            BMEs.areaCode = areaCode;
            BMEs.mapResolution = currentResolution;

            % Add observations at this time for plotting
            iME = find(abs(obs.tME - tk) < 1e-6);
            if ~isempty(iME)
                validObs = ~isnan(obs.Y(:, iME));
                if any(validObs)
                    BMEs.sMSobs = obs.sMS(validObs, :);
                    BMEs.Yobs = obs.Y(validObs, iME);
                    Xh = obs.Y - stmeaninterp(go.sMS, go.tME, go.ms, go.mt, obs.sMS, obs.tME);
                    BMEs.Xobs = Xh(validObs, iME);
                else
                    BMEs.sMSobs = [];
                    BMEs.Yobs = [];
                    BMEs.Xobs = [];
                end
            else
                BMEs.sMSobs = [];
                BMEs.Yobs = [];
                BMEs.Xobs = [];
            end

            save(scenarioPath, 'BMEs', '-v7.3');
            fprintf('  Saved: %s\n', scenarioFile);

            % Print variance statistics
            stdDev = sqrt(XkBMEv);
            fprintf('  Std Dev: mean=%.3f, min=%.3f, max=%.3f\n', ...
                mean(stdDev, 'omitnan'), min(stdDev), max(stdDev));

            % Plot if requested
            if estParam.plotResults > 0
                % Create scenario-specific plot directory
                scenarioPlotDir = fullfile(diagDir, sprintf('res%.2f_lambda%.1f_offset%.3f', currentResolution, lambda2Scale, gridOffset));
                if ~exist(scenarioPlotDir, 'dir')
                    mkdir(scenarioPlotDir);
                end
                estParam.figDir = scenarioPlotDir;

                plotTOARsBME(obs, go, BMEs, BMEparam, estParam, dispParam);
                plotTOARsBMEvar(obs, go, BMEs, BMEparam, estParam, dispParam);
            end
        end
    end
end

%% Generate Comparison Figure
if diagParam.generateComparison
    fprintf('\n=== Generating Comparison Figure ===\n');

    % Load border data if available
    bordersAvailable = false;
    if exist('1data/borderdata.mat', 'file')
        try
            load('1data/borderdata.mat', 'places', 'lon', 'lat');
            bordersAvailable = true;
        catch
        end
    end

    if strcmp(diagParam.runMode, 'gridResolution')
        % Resolution-specific comparison figure (horizontal layout)
        fig = figure('Position', [50, 50, 350*nResolution, 350], 'Color', 'w');

        % Determine common color limits across all resolutions
        allStd = [];
        for iR = 1:nResolution
            allStd = [allStd; sqrt(results.XkBMEv{1, 1, iR})];
        end
        climLimits = prctile(allStd(~isnan(allStd) & ~isinf(allStd)), [2, 98]);

        for iRes = 1:nResolution
            subplot(1, nResolution, iRes);

            sk = results.sk{1, 1, iRes};
            stdDev = sqrt(results.XkBMEv{1, 1, iRes});

            scatter(sk(:,1), sk(:,2), 8, stdDev, 'filled');
            colormap(jet);
            clim(climLimits);

            xlim([axMS_est(1), axMS_est(2)]);
            ylim([axMS_est(3), axMS_est(4)]);

            % Add borders
            if bordersAvailable
                hold on;
                for k = 1:length(places)
                    if ~isempty(lon{k})
                        plot(lon{k}, lat{k}, 'k-', 'LineWidth', 0.3);
                    end
                end
                hold off;
            end

            axis equal tight;
            title(sprintf('Res=%.2f° (%d pts)', gridResolutions(iRes), size(sk, 1)), ...
                'FontSize', 10);
            xlabel('Longitude');

            if iRes == 1
                ylabel('Latitude');
            end

            if iRes == nResolution
                colorbar;
            end
        end

        sgtitle(sprintf('Diagnostic: Grid Resolution Comparison (time=%.2f)', tk), ...
            'FontSize', 14, 'FontWeight', 'bold');

        comparisonFile = sprintf('comparison_gridResolution_time%.2f.png', tk);

    else
        % Lambda2 x gridOffset comparison figure (grid layout)
        fig = figure('Position', [50, 50, 400*nOffset, 300*nLambda], 'Color', 'w');

        % Determine common color limits across all scenarios
        allStd = [];
        for iL = 1:nLambda
            for iO = 1:nOffset
                allStd = [allStd; sqrt(results.XkBMEv{iL, iO, 1})];
            end
        end
        climLimits = prctile(allStd(~isnan(allStd) & ~isinf(allStd)), [2, 98]);

        for iLambda = 1:nLambda
            for iOffset = 1:nOffset
                subplotIdx = (iLambda - 1) * nOffset + iOffset;
                subplot(nLambda, nOffset, subplotIdx);

                sk = results.sk{iLambda, iOffset, 1};
                stdDev = sqrt(results.XkBMEv{iLambda, iOffset, 1});

                scatter(sk(:,1), sk(:,2), 8, stdDev, 'filled');
                colormap(jet);
                clim(climLimits);

                % Set xlim and ylim to estimation area boundaries for consistency
                xlim([axMS_est(1), axMS_est(2)]);
                ylim([axMS_est(3), axMS_est(4)]);

                % Add borders
                if bordersAvailable
                    hold on;
                    for k = 1:length(places)
                        if ~isempty(lon{k})
                            plot(lon{k}, lat{k}, 'k-', 'LineWidth', 0.3);
                        end
                    end
                    hold off;
                end

                axis equal tight;
                title(sprintf('\\lambda_2=%.1f, off=%.2f', lambda2Scales(iLambda), gridOffsets(iOffset)), ...
                    'FontSize', 10);

                if iOffset == 1
                    ylabel(sprintf('\\lambda_2 = %.1f', lambda2Scales(iLambda)), 'FontWeight', 'bold');
                end
                if iLambda == 1
                    xlabel(sprintf('offset = %.2f°', gridOffsets(iOffset)));
                end

                % Only show colorbar on right edge
                if iOffset == nOffset
                    colorbar;
                end
            end
        end

        sgtitle(sprintf('Diagnostic: Std Dev Maps (time=%.2f)', tk), ...
            'FontSize', 14, 'FontWeight', 'bold');

        comparisonFile = sprintf('comparison_lambda2_gridOffset_time%.2f.png', tk);
    end

    % Save comparison figure
    comparisonPath = fullfile(diagDir, comparisonFile);
    print(fig, comparisonPath, '-dpng', '-r200');
    fprintf('Comparison figure saved: %s\n', comparisonPath);

    % Keep figure open for inspection
    fprintf('\nFigure kept open for inspection.\n');
end
end
