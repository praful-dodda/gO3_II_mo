function estTOARsBME(obs, go, ~, KG, KS, BMEparam, estParam, dispParam)
% estTOARsBME - BME spatial estimation of TOAR ozone concentrations
%
% Performs Bayesian Maximum Entropy estimation on a spatial grid for
% specified time periods, using space-time grid (STG) format
%
% SYNTAX:
%   estTOARsBME(obs, go, cov, KG, KS, BMEparam, estParam)
%   estTOARsBME(obs, go, cov, KG, KS, BMEparam, estParam, dispParam)
%
% INPUTS:
%   obs      - Structure from getTOARobservationalData
%   go       - Structure from getTOARglobalOffset
%   cov      - Structure from getTOARautoCov
%   KG       - General Knowledge from getTOARknowledgeBase
%   KS       - Site-specific Knowledge from getTOARknowledgeBase
%   BMEparam - BME parameters from getTOARknowledgeBase
%   estParam - Estimation parameters structure:
%              .areaCode        - Area code (0-10, see getTOARareaBoundaries)
%              .mapResolution   - Grid resolution in degrees (default: 0.25)
%              .tkVec           - Vector of times to estimate (decimal years)
%              .forceEstimation - Force re-estimation (1) or use saved (0)
%              .plotResults     - Plot level (0=none, 1=basic, 2=detailed)
%              .gridOffset      - Offset for estimation grid in degrees (default: 0.05)
%                                 Avoids alignment artifacts with soft data grids
%              .smoothVariance  - Optional variance smoothing to reduce grid artifacts:
%                                 0 = no smoothing (default)
%                                 scalar > 0 = smoothing radius in degrees (recommended: 1-2)
%   dispParam - Display parameters (optional):
%              .nxpix        - Number of pixels in x-direction (default: 150)
%              .nypix        - Number of pixels in y-direction (default: 100)
%              .bufferDist   - Buffer distance for masking in degrees (default: 0.5)
%              .bufferType   - 'soft' (gradual fade) or 'hard' (sharp cut) (default: 'soft')
%              .interpMethod - Interpolation method: 'natural' (default), 'linear', etc.
%              .dxRes        - Display grid x-resolution in degrees (default: 0.125)
%                              Overrides nxpix when provided
%              .dyRes        - Display grid y-resolution in degrees (default: 0.125)
%                              Overrides nypix when provided
%
% OUTPUTS:
%   Saves BME estimation results to ./5BMEspatialPlots/ directory
%   Each file contains: sk, tk, XkBMEm, XkBMEv, YkBMEm, gok, observations
%
% EXAMPLE:
%   obs = getTOARobservationalData('all', [2015 2020]);
%   go = getTOARglobalOffset(obs, 3);
%   cov = getTOARautoCov(obs, go);
%   [KG, KS, BMEparam] = getTOARknowledgeBase(obs, go, cov, [], '10000132');
%
%   estParam.areaCode = 2;           % Europe
%   estParam.mapResolution = 0.25;   % 0.25 degree estimation grid
%   estParam.gridOffset = 0.05;      % 0.05 degree offset to avoid alignment artifacts
%   estParam.tkVec = 2015:1/12:2016; % Monthly for 2015
%   estParam.forceEstimation = 0;
%   estParam.plotResults = 1;
%
%   estTOARsBME(obs, go, cov, KG, KS, BMEparam, estParam);

%% Input Validation
if nargin < 7
    error('All 7 input arguments required. See help estTOARsBME');
end

% Validate estParam fields
requiredFields = {'areaCode', 'mapResolution', 'tkVec', 'forceEstimation', 'plotResults'};
for i = 1:length(requiredFields)
    if ~isfield(estParam, requiredFields{i})
        error('estParam missing required field: %s', requiredFields{i});
    end
end

% Set default grid offset (0.05 deg avoids alignment with soft data grids)
if ~isfield(estParam, 'gridOffset')
    estParam.gridOffset = 0.05;
end

%% Display Parameters
% Defaults based on diagnostic analysis (estTOARsBME_diag):
%   - 'natural' interpolation reduces grid-aligned stripe artifacts
%   - 0.125 deg display resolution provides smooth maps from 0.25 deg estimation grid
if nargin < 8 || isempty(dispParam)
    dispParam = struct();
end
if ~isfield(dispParam, 'nxpix'),        dispParam.nxpix = 150; end
if ~isfield(dispParam, 'nypix'),        dispParam.nypix = 100; end
if ~isfield(dispParam, 'bufferDist'),   dispParam.bufferDist = 0.5; end
if ~isfield(dispParam, 'bufferType'),   dispParam.bufferType = 'soft'; end
if ~isfield(dispParam, 'interpMethod'), dispParam.interpMethod = 'natural'; end
if ~isfield(dispParam, 'dxRes'),        dispParam.dxRes = 0.125; end
if ~isfield(dispParam, 'dyRes'),        dispParam.dyRes = 0.125; end

%% Setup
fprintf('=== TOAR BME Spatial Estimation ===\n');

% Extract parameters
areaCode = estParam.areaCode;
mapResolution = estParam.mapResolution;
tkVec = estParam.tkVec;
forceEstimation = estParam.forceEstimation;
plotResults = estParam.plotResults;

% Get BME method info
BMEmethod8digits = BMEparam.BMEmethod8digits;
BMEprobaType = str2double(BMEmethod8digits(8));

% Create output directory
BMEsDir = '5BMEspatialPlots';
if ~exist(BMEsDir, 'dir')
    mkdir(BMEsDir);
    fid = fopen(fullfile(BMEsDir, '0readme.txt'), 'w');
    fprintf(fid, 'BME estimation results for TOAR ozone data\n');
    fprintf(fid, 'Generated by estTOARsBME.m\n');
    fprintf(fid, 'File naming: BME{method}_go{scenario}_lt{logtransf}_area{code}_res{resolution}_{format}_land{flag}_time{YYYY.YY}.mat\n');
    fprintf(fid, 'where {format} is stv (space-time vector), stg (space-time grid), or stug (space-time unstructured grid)\n');
    fprintf(fid, 'and {flag} is 1 (land-only points) or 0 (all points including ocean)\n');
    fclose(fid);
end

% Base filename for this configuration
% Include keepOnlyLand flag: land1 (only land) or land0 (all points)
keepOnlyLand = 1;  % Default to land-only estimation
if isfield(estParam, 'keepOnlyLand')
    keepOnlyLand = estParam.keepOnlyLand;
end

BMEsFileBase = sprintf('BME%s_go%d_lt%d_area%d_res%.2f_%s_land%d', ...
    BMEmethod8digits, go.scenario, obs.logTransf, areaCode, mapResolution, BMEparam.dataFormat, keepOnlyLand);

fprintf('Configuration:\n');
fprintf('  BME method: %s\n', BMEmethod8digits);
fprintf('  Global offset scenario: %d\n', go.scenario);
fprintf('  Area code: %d\n', areaCode);
fprintf('  Estimation grid resolution: %.2f degrees\n', mapResolution);
fprintf('  Grid offset: %.3f degrees\n', estParam.gridOffset);
fprintf('  Display grid resolution: %.3f x %.3f degrees\n', dispParam.dxRes, dispParam.dyRes);
fprintf('  Interpolation method: %s\n', dispParam.interpMethod);
fprintf('  Number of time periods: %d\n', length(tkVec));

%% Create Estimation Grid

fprintf('\nCreating estimation grid...\n');

% Get area boundaries
[axMS_est, ~] = getTOARareaBoundaries(areaCode);

% Create spatial grid (coastBuffer dilates the land mask; popCoverFile guarantees
% every populated cell has a nearby grid node - both default off / legacy behaviour)
coastBuffer = 0;  if isfield(estParam, 'coastBuffer'),  coastBuffer  = estParam.coastBuffer;  end
popCoverFile = ''; if isfield(estParam, 'popCoverFile'), popCoverFile = estParam.popCoverFile; end
sk = getTOARmapGrid(mapResolution, estParam.keepOnlyLand, estParam.includeAntarctica, ...
    [0 0], coastBuffer, popCoverFile);

% Apply grid offset to avoid alignment artifacts with soft data grids
gridOffset = estParam.gridOffset;
if gridOffset ~= 0
    sk(:,1) = sk(:,1) + gridOffset;
    sk(:,2) = sk(:,2) + gridOffset;
    fprintf('  Grid offset applied: +%.3f degrees\n', gridOffset);
end

% add locations of monitoring sites to the estimatio grid
sk = [sk; obs.sMS];

% remove duplicate points
[~, uniqueIdx] = unique(sk, 'rows');
sk = sk(uniqueIdx, :);

% Filter grid to estimation area
inArea = (sk(:,1) >= axMS_est(1)) & (sk(:,1) <= axMS_est(2)) & ...
         (sk(:,2) >= axMS_est(3)) & (sk(:,2) <= axMS_est(4));
sk = sk(inArea, :);

% % Remove observation locations from estimation grid
% obsLocs = obs.sMS;
% [~, duplicateIdx] = ismember(sk, obsLocs, 'rows');
% sk = sk(duplicateIdx == 0, :);

fprintf('  Estimation grid: %d points\n', size(sk, 1));
fprintf('  Spatial extent: [%.1f %.1f] x [%.1f %.1f]\n', ...
    min(sk(:,1)), max(sk(:,1)), min(sk(:,2)), max(sk(:,2)));

%% BME Estimation Loop

fprintf('\nStarting BME estimation...\n');

for iTime = 1:length(tkVec)
    tk = tkVec(iTime);
    
    % Create filename for this time
    BMEsFile = sprintf('%s_time%.2f.mat', BMEsFileBase, tk);
    BMEsPath = fullfile(BMEsDir, BMEsFile);
    
    fprintf('\n[%d/%d] Time = %.2f\n', iTime, length(tkVec), tk);
    
    % Check if already estimated
    if exist(BMEsPath, 'file') && ~forceEstimation
        fprintf('  Results exist, loading...\n');
        load(BMEsPath, 'BMEs');
        
        if plotResults > 0
            % replace NaNs in BMEs.XkBMEm with 0s
            BMEs.XkBMEm(isnan(BMEs.XkBMEm)) = 0;

            % recalculate YkBMEm
            BMEs.YkBMEm = BMEs.XkBMEm + BMEs.gok;

            plotTOARsBME(obs, go, BMEs, BMEparam, estParam, dispParam);
            plotTOARsBMEvar(obs, go, BMEs, BMEparam, estParam, dispParam);
        end
        continue;
    end
    
    % Create space-time estimation points
    pk=[sk kron(tk,1+0*sk(:,1))];
    
    % Perform BME estimation
    fprintf('  Estimating %d points...\n', size(pk, 1));
    tic;
    
    switch BMEprobaType
        case 1  % BMEprobaMoments
            if isempty(KS.softdata.p)
                % Hard data only
                fprintf('    Using BMEprobaMoments (hard data only)...\n');
                [moments, ~] = BMEprobaMoments(pk, KS.harddata.p, [], KS.harddata.z, ...
                    [], [], [], [], KG.covmodel, KG.covparam, ...
                    BMEparam.nhmax, BMEparam.nsmax, BMEparam.dmax, ...
                    BMEparam.order, BMEparam.options);
            else
                % Hard and soft data
                fprintf('    Using BMEprobaMoments (hard + soft data)...\n');
                [moments, ~] = BMEprobaMoments(pk, KS.harddata.p, KS.softdata.p, ...
                    KS.harddata.z, KS.softpdftype, KS.nl, KS.limi, KS.probdens, ...
                    KG.covmodel, KG.covparam, BMEparam.nhmax, BMEparam.nsmax, ...
                    BMEparam.dmax, BMEparam.order, BMEparam.options);
            end
            XkBMEm = moments(:, 1);
            XkBMEv = moments(:, 2);
            
        case 2  % KrigingME
            % Select kriging method based on data format
            switch BMEparam.dataFormat
                case 'stv'
                    fprintf('    Using krigingME (STV format - space-time vector)...\n');
                    % STV format: standard vector-based kriging
                    [XkBMEm, XkBMEv] = krigingME(pk, KS.harddata.p, KS.softdata.p, ...
                        KS.harddata.z, KS.softdata.z, KS.softdata.vs, ...
                        KG.covmodel, KG.covparam, BMEparam.nhmax, BMEparam.nsmax, ...
                        BMEparam.dmax, BMEparam.order);

                case 'stg'
                    fprintf('    Using krigingME_stg (STG format - space-time grid)...\n');
                    % STG format: optimized for regular grids
                    [XkBMEm, XkBMEv] = krigingME_stg(pk, KS.harddata, KS.softdata, ...
                        KG.covmodel, KG.covparam, BMEparam.nhmax, BMEparam.nsmax, ...
                        BMEparam.dmax, BMEparam.order);

                case 'stug'
                    fprintf('    Using krigingME_stug (STUG format - space-time unstructured grid)...\n');
                    % STUG format: fastest for large uniform grids
                    soft_data = reformat_stg_to_stug(KS.softdata);
                    
                    [XkBMEm, XkBMEv] = krigingME_stug(pk, KS.harddata.p, KS.softdata.p, ...
                        KS.harddata.z, KS.softdata.z, KS.softdata.vs, ...
                        KG.covmodel, KG.covparam, BMEparam.nhmax, BMEparam.nsmax, ...
                        BMEparam.dmax, BMEparam.order, 0, KS.harddata, soft_data);

                otherwise
                    error('Invalid dataFormat: %s. Must be ''stv'', ''stg'', or ''stug''', ...
                        BMEparam.dataFormat);
            end

            % Replace NaNs in XkBMEm with 0s
            XkBMEm(isnan(XkBMEm)) = 0;

        case 3  % KrigingME
            % Select kriging method based on data format
            switch BMEparam.dataFormat
                case 'stug'
                    fprintf('    Using krigingME_stug (STUG format - space-time unstructured grid)...\n');
                    % STUG format: fastest for large uniform grids
                    % reformat for all of the softdatasets if it's a cell array
                    if iscell(KS.softdata)
                        soft_data = cell(size(KS.softdata));
                        p_soft = cell(size(KS.softdata));
                        z_soft = cell(size(KS.softdata));
                        vs_soft = cell(size(KS.softdata));

                        for ii = 1:length(KS.softdata)
                            soft_data{ii} = reformat_stg_to_stug(KS.softdata{ii}, 'modelName', KS.softdata{ii}.modelName, 'resolution', 0.5);
                            p_soft{ii} = KS.softdata{ii}.p;
                            z_soft{ii} = KS.softdata{ii}.z;
                            vs_soft{ii} = KS.softdata{ii}.vs;
                        end
                    elseif ~isempty(KS.softdata)
                        % single softdata structure
                        soft_data = reformat_stg_to_stug(KS.softdata);
                        p_soft = soft_data.p;
                        z_soft = soft_data.z;
                        vs_soft = soft_data.vs;
                    else
                        % no soft data
                        soft_data = [];
                        p_soft = [];
                        z_soft = [];
                        vs_soft = [];
                    end
                    % [XkBMEm, XkBMEv] = krigingME_stug(pk, KS.harddata.p, KS.softdata.p, ...
                    %     KS.harddata.z, KS.softdata.z, KS.softdata.vs, ...
                    %     KG.covmodel, KG.covparam, BMEparam.nhmax, BMEparam.nsmax, ...
                    %     BMEparam.dmax, BMEparam.order, 0, KS.harddata, soft_data);
                    [XkBMEm, XkBMEv] = krigingME_stug_multi(pk, KS.harddata.p, p_soft, KS.harddata.z, ...
                        z_soft, vs_soft, KG.covmodel, KG.covparam, BMEparam.nhmax, BMEparam.nsmax, ...
                        BMEparam.dmax, BMEparam.order, BMEparam.options, KS.harddata, soft_data);

                otherwise
                    error('Invalid dataFormat: %s. Must be ''stv'', ''stg'', or ''stug''', ...
                        BMEparam.dataFormat);
            end

            % QC check: print the number of NaNs and negative variances
            nNaNs = sum(isnan(XkBMEm));
            nNegVar = sum(XkBMEv < 0);
            fprintf('    QC Check: %d NaN means, %d negative variances\n', nNaNs, nNegVar);

            XkBMEm(isnan(XkBMEm)) = 0; % Replace NaNs in XkBMEm with 0s
            XkBMEv(XkBMEv<0)=0; % set negative variances to zero
            
        otherwise
            error('Invalid BMEprobaType: %d', BMEprobaType);
    end
    
    elapsedTime = toc;
    fprintf('    Completed in %.1f seconds\n', elapsedTime);
    
    % Add global offset back to get final predictions
    gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, sk, tk);

    YkBMEm = XkBMEm + gok;

    % Debug:
    fprintf('XkBMEm range: [%.2e, %.2e]\n', min(XkBMEm), max(XkBMEm));
    fprintf('gok range: [%.2e, %.2e]\n', min(gok), max(gok));
    fprintf('YkBMEm range: [%.2e, %.2e]\n', min(YkBMEm), max(YkBMEm));
    
    % Clean up variance estimates
    XkBMEv(isnan(XkBMEv)) = max(XkBMEv(~isnan(XkBMEv)));
    XkBMEv = real(XkBMEv);  % Remove any imaginary components

    % Optional variance smoothing to reduce grid-aligned stripe artifacts
    % This uses spatial Gaussian smoothing on the variance field
    if isfield(estParam, 'smoothVariance') && estParam.smoothVariance > 0
        smoothRadius = estParam.smoothVariance;
        fprintf('    Applying variance smoothing (radius = %.2f degrees)...\n', smoothRadius);

        % Gaussian spatial smoothing
        % Weight = exp(-distance^2 / (2*sigma^2)), where sigma = smoothRadius/2
        sigma = smoothRadius / 2;
        XkBMEv_smooth = zeros(size(XkBMEv));

        for idx = 1:length(XkBMEv)
            % Compute distances from this point to all other points
            dists = sqrt((sk(:,1) - sk(idx,1)).^2 + (sk(:,2) - sk(idx,2)).^2);

            % Gaussian weights
            weights = exp(-dists.^2 / (2*sigma^2));
            weights = weights / sum(weights);  % Normalize

            % Weighted average of variance
            XkBMEv_smooth(idx) = sum(weights .* XkBMEv);
        end

        % Replace with smoothed variance
        XkBMEv = XkBMEv_smooth;
        fprintf('    Variance smoothing complete\n');
    end

    % Package results
    BMEs.sk = sk;
    BMEs.tk = tk;
    BMEs.XkBMEm = XkBMEm;           % Residual mean
    BMEs.XkBMEv = XkBMEv;           % Residual variance
    BMEs.gok = gok;                 % Global offset
    BMEs.YkBMEm = YkBMEm;           % Final prediction (with GO)
    BMEs.estGridArea = axMS_est;
    BMEs.areaCode = areaCode;
    BMEs.mapResolution = mapResolution;
    
    % Add observations at this time for plotting
    iME = find(abs(obs.tME - tk) < 1e-6);
    if ~isempty(iME)
        validObs = ~isnan(obs.Y(:, iME));
        if any(validObs)
            BMEs.sMSobs = obs.sMS(validObs, :);
            BMEs.Yobs = obs.Y(validObs, iME);
            
            % Also include residuals
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
    
    % Save results
    fprintf('  Saving results to: %s\n', BMEsFile);
    save(BMEsPath, 'BMEs', '-v7.3');
    
    % Summary statistics
    fprintf('  Results summary:\n');
    fprintf('    Mean prediction: %.2f %s\n', mean(YkBMEm, "omitmissing"), obs.Zunit);
    fprintf('    Std prediction: %.2f %s\n', std(YkBMEm, "omitmissing"), obs.Zunit);
    fprintf('    Mean uncertainty: %.2f %s\n', mean(sqrt(XkBMEv), "omitmissing"), obs.Zunit);
    
    % Plot if requested
    if plotResults > 0
        plotTOARsBME(obs, go, BMEs, BMEparam, estParam, dispParam);
        plotTOARsBMEvar(obs, go, BMEs, BMEparam, estParam, dispParam);
    end
end

fprintf('\n=== BME Estimation Complete ===\n');
fprintf('Results saved in: %s\n', BMEsDir);

end