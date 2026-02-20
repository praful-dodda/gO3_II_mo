function siteEstimates = estimateBME_AtRepSites(repSites, obs, go, cov, KG, KS, BMEparam, tkVec, varargin)
% estimateBME_AtRepSites - BME estimation at representative sites
%
% Performs BME estimation at exact representative site locations, with optional
% leave-one-out cross-validation (excludes nearby observations per site)
%
% SYNTAX:
%   siteEstimates = estimateBME_AtRepSites(repSites, obs, go, cov, KG, KS, BMEparam, tkVec)
%   siteEstimates = estimateBME_AtRepSites(..., 'Name', Value)
%
% INPUTS:
%   repSites    - Representative sites structure from selectRepresentativeSites
%   obs         - Observation structure from getTOARobservationalData
%   go          - Global offset structure from getTOARglobalOffset
%   cov         - Covariance structure from getTOARautoCov
%   KG          - Knowledge of geometry from getTOARknowledgeBase
%   KS          - Knowledge of statistics from getTOARknowledgeBase
%   BMEparam    - BME parameters structure
%   tkVec       - Time periods to estimate (decimal years)
%
% OPTIONAL PARAMETERS:
%   'performValidation' - Enable leave-one-out validation (default: false)
%   'exclusionRadius'   - Radius (degrees) to exclude obs for leave-one-out (default: 0.5)
%                         Only used when performValidation is true
%   'saveResults'       - Save results to file (default: true)
%   'outputDir'         - Output directory (default: '5BMEspatialPlots')
%   'verbose'           - Print progress (default: true)
%
% OUTPUTS:
%   siteEstimates - Structure with fields:
%       .sites          - Copy of repSites input
%       .tkVec          - Time periods estimated
%       .estimates      - Struct array with fields for each site:
%           .regionName - Region name
%           .lon, .lat  - Site coordinates
%           .XkBMEmean  - BME residual mean estimates [nTimes × 1]
%           .XkBMEstd   - BME residual std dev estimates [nTimes × 1]
%           .XkBMEvar   - BME residual variance estimates [nTimes × 1]
%           .YkBMEmean  - Final prediction with global offset [nTimes × 1]
%           .nObsUsed   - Number of obs used per time [nTimes × 1]
%           .BMEmean    - Alias for YkBMEmean (backward compatibility)
%           .BMEstd     - Alias for XkBMEstd (backward compatibility)
%           .BMEvar     - Alias for XkBMEvar (backward compatibility)

%% Parse inputs
p = inputParser;
addRequired(p, 'repSites', @isstruct);
addRequired(p, 'obs', @isstruct);
addRequired(p, 'go', @isstruct);
addRequired(p, 'cov', @isstruct);
addRequired(p, 'KG', @isstruct);
addRequired(p, 'KS', @isstruct);
addRequired(p, 'BMEparam', @isstruct);
addRequired(p, 'tkVec', @isnumeric);
addParameter(p, 'performValidation', false, @islogical);
addParameter(p, 'exclusionRadius', 0.5, @isnumeric);
addParameter(p, 'saveResults', true, @islogical);
addParameter(p, 'outputDir', '5BMEspatialPlots', @ischar);
addParameter(p, 'verbose', true, @islogical);

parse(p, repSites, obs, go, cov, KG, KS, BMEparam, tkVec, varargin{:});
opts = p.Results;

%% Setup
if opts.verbose
    fprintf('\n=== BME Estimation at Representative Sites ===\n');
    if opts.performValidation
        fprintf('  Mode: Leave-one-out validation\n');
        fprintf('  Exclusion radius: %.2f degrees\n', opts.exclusionRadius);
    else
        fprintf('  Mode: Standard estimation (all observations)\n');
    end
end

regions = fieldnames(repSites);
nRegions = length(regions);
nTimes = length(tkVec);

if opts.verbose
    fprintf('  Sites: %d\n', nRegions);
    fprintf('  Time periods: %d\n', nTimes);
    fprintf('  BME method: %s\n', BMEparam.BMEmethod);
end

%% Initialize output structure
siteEstimates = struct();
siteEstimates.sites = repSites;
siteEstimates.tkVec = tkVec;
siteEstimates.BMEmethod = BMEparam.BMEmethod;
siteEstimates.performValidation = opts.performValidation;
siteEstimates.exclusionRadius = opts.exclusionRadius;
siteEstimates.estimates = struct();

%% Create estimation points for all sites
sk = [];
for iReg = 1:nRegions
    regionName = regions{iReg};
    site = repSites.(regionName);
    sk = [sk; site.lon, site.lat];
end

if opts.verbose
    fprintf('  Total estimation points: %d sites × %d times = %d\n\n', ...
        nRegions, nTimes, nRegions * nTimes);
end

%% Estimate at all sites

if opts.verbose
    fprintf('  Running BME estimation...\n');
    tic;
end

XkBMEm_all = nan(nRegions, nTimes);
XkBMEv_all = nan(nRegions, nTimes);
YkBMEm_all = nan(nRegions, nTimes);
nObsUsed_all = zeros(nRegions, nTimes);

if ~opts.performValidation
    % Standard estimation: Use all observations, loop through each time period

    % Prepare soft data once (same for all time periods)
    if iscell(KS.softdata)
        soft_data = cell(size(KS.softdata));
        p_soft = cell(size(KS.softdata));
        z_soft = cell(size(KS.softdata));
        vs_soft = cell(size(KS.softdata));

        for ii = 1:length(KS.softdata)
            soft_data{ii} = reformat_stg_to_stug(KS.softdata{ii});
            p_soft{ii} = soft_data{ii}.p;
            z_soft{ii} = soft_data{ii}.z;
            vs_soft{ii} = soft_data{ii}.vs;
        end
    else
        if ~isempty(KS.softdata)
            soft_data = reformat_stg_to_stug(KS.softdata);
            p_soft = soft_data.p;
            z_soft = soft_data.z;
            vs_soft = soft_data.vs;
        else
            soft_data = [];
            p_soft = [];
            z_soft = [];
            vs_soft = [];
        end
    end

    % Loop through each time period (following estTOARsBME pattern)
    for iTime = 1:nTimes
        tk = tkVec(iTime);

        if opts.verbose && (iTime == 1 || mod(iTime, 6) == 0 || iTime == nTimes)
            fprintf('    Time %d/%d (%.2f)...\n', iTime, nTimes, tk);
        end

        % Create space-time estimation points for this time
        pk = [sk, kron(tk, 1 + 0*sk(:,1))];

        % Run BME estimation for all sites at this time
        try
            [XkBMEm, XkBMEv] = krigingME_stug_multi(pk, KS.harddata.p, p_soft, ...
                KS.harddata.z, z_soft, vs_soft, KG.covmodel, KG.covparam, ...
                BMEparam.nhmax, BMEparam.nsmax, BMEparam.dmax, BMEparam.order, ...
                BMEparam.options, KS.harddata, soft_data);

            % Replace NaNs in XkBMEm with 0s
            XkBMEm(isnan(XkBMEm)) = 0;

            % Add global offset back to get final predictions (following estTOARsBME)
            gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, sk, tk);
            YkBMEm = XkBMEm + gok;

            % Store results
            XkBMEm_all(:, iTime) = XkBMEm;
            XkBMEv_all(:, iTime) = XkBMEv;
            YkBMEm_all(:, iTime) = YkBMEm;
            nObsUsed_all(:, iTime) = size(KS.harddata.p, 1);

        catch ME
            if opts.verbose
                warning('BME estimation failed at time %.2f: %s', tk, ME.message);
            end
        end
    end

else
    % Leave-one-out validation: Process each site and each time period separately

    % Prepare soft data once (same for all, no filtering needed)
    if iscell(KS.softdata)
        soft_data = cell(size(KS.softdata));
        p_soft = cell(size(KS.softdata));
        z_soft = cell(size(KS.softdata));
        vs_soft = cell(size(KS.softdata));

        for ii = 1:length(KS.softdata)
            soft_data{ii} = reformat_stg_to_stug(KS.softdata{ii});
            p_soft{ii} = soft_data{ii}.p;
            z_soft{ii} = soft_data{ii}.z;
            vs_soft{ii} = soft_data{ii}.vs;
        end
    else
        if ~isempty(KS.softdata)
            soft_data = reformat_stg_to_stug(KS.softdata);
            p_soft = soft_data.p;
            z_soft = soft_data.z;
            vs_soft = soft_data.vs;
        else
            soft_data = [];
            p_soft = [];
            z_soft = [];
            vs_soft = [];
        end
    end

    % Loop through each time period
    for iTime = 1:nTimes
        tk = tkVec(iTime);

        if opts.verbose && (iTime == 1 || mod(iTime, 6) == 0 || iTime == nTimes)
            fprintf('    Time %d/%d (%.2f)...\n', iTime, nTimes, tk);
        end

        % Process each region at this time
        for iReg = 1:nRegions
            regionName = regions{iReg};
            site = repSites.(regionName);

            % Create space-time estimation point for this site at this time
            pk_site = [site.lon, site.lat, tk];

            % Create leave-one-out hard data (exclude obs near this site)
            distToSite = sqrt((KS.harddata.p(:,1) - site.lon).^2 + ...
                             (KS.harddata.p(:,2) - site.lat).^2);
            keepObs = distToSite > opts.exclusionRadius;

            % Filter hard data
            KS_loo = KS;
            KS_loo.harddata.p = KS.harddata.p(keepObs, :);
            KS_loo.harddata.z = KS.harddata.z(keepObs);

            nObsUsed_all(iReg, iTime) = sum(keepObs);

            % Run BME estimation for this site at this time
            try
                [XkBMEm, XkBMEv] = krigingME_stug_multi(pk_site, KS_loo.harddata.p, p_soft, ...
                    KS_loo.harddata.z, z_soft, vs_soft, KG.covmodel, KG.covparam, ...
                    BMEparam.nhmax, BMEparam.nsmax, BMEparam.dmax, BMEparam.order, ...
                    BMEparam.options, KS_loo.harddata, soft_data);

                % Replace NaNs with 0s
                XkBMEm(isnan(XkBMEm)) = 0;

                % Add global offset back to get final predictions
                gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, [site.lon, site.lat], tk);
                YkBMEm = XkBMEm + gok;

                % Store results
                XkBMEm_all(iReg, iTime) = XkBMEm;
                XkBMEv_all(iReg, iTime) = XkBMEv;
                YkBMEm_all(iReg, iTime) = YkBMEm;

            catch ME
                if opts.verbose
                    warning('BME estimation failed for %s at time %.2f: %s', regionName, tk, ME.message);
                end
            end
        end
    end
end

if opts.verbose
    fprintf('  Estimation completed in %.1f seconds\n', toc);
end

%% Package results by site
for iReg = 1:nRegions
    regionName = regions{iReg};
    site = repSites.(regionName);

    % Extract results for this site (across all times)
    XkBMEmean = XkBMEm_all(iReg, :)';  % Residual mean [nTimes × 1]
    XkBMEvar = XkBMEv_all(iReg, :)';   % Residual variance [nTimes × 1]
    YkBMEmean = YkBMEm_all(iReg, :)';  % Final prediction with GO [nTimes × 1]
    nObsUsed = nObsUsed_all(iReg, :)'; % Obs count [nTimes × 1]

    % Ensure variances are non-negative (fix for complex number warnings)
    XkBMEvar(XkBMEvar < 0) = 0;
    XkBMEstd = sqrt(XkBMEvar);

    % Store results
    siteEstimates.estimates.(regionName).regionName = regionName;
    siteEstimates.estimates.(regionName).lon = site.lon;
    siteEstimates.estimates.(regionName).lat = site.lat;
    siteEstimates.estimates.(regionName).XkBMEmean = XkBMEmean;  % Residual mean
    siteEstimates.estimates.(regionName).XkBMEstd = XkBMEstd;    % Residual std
    siteEstimates.estimates.(regionName).XkBMEvar = XkBMEvar;    % Residual variance
    siteEstimates.estimates.(regionName).YkBMEmean = YkBMEmean;  % Final prediction (with GO)
    siteEstimates.estimates.(regionName).nObsUsed = nObsUsed;

    % Backward compatibility fields for plotting functions
    siteEstimates.estimates.(regionName).BMEmean = YkBMEmean;  % Final prediction (for compatibility)
    siteEstimates.estimates.(regionName).BMEvar = XkBMEvar;    % Variance (for compatibility)
    siteEstimates.estimates.(regionName).BMEstd = XkBMEstd;    % Std dev (for compatibility)
end

% Add metadata for tracking and documentation
siteEstimates.metadata.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
siteEstimates.metadata.nSites = nRegions;
siteEstimates.metadata.nTimes = nTimes;
siteEstimates.metadata.totalPoints = nRegions * nTimes;
siteEstimates.metadata.covModel = KG.covmodel;
siteEstimates.metadata.covParam = KG.covparam;

%% Save results
if opts.saveResults
    if ~exist(opts.outputDir, 'dir')
        mkdir(opts.outputDir);
    end

    saveFile = fullfile(opts.outputDir, ...
        sprintf('site_estimates_%s.mat', BMEparam.BMEmethod));
    save(saveFile, 'siteEstimates', '-v7.3');

    if opts.verbose
        fprintf('  Saved results to: %s\n', saveFile);
    end
end

if opts.verbose
    fprintf('  Site estimation complete\n\n');
end

end
