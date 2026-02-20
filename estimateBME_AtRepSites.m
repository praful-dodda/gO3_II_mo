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
%           .BMEmean    - BME mean estimates [nTimes × 1]
%           .BMEstd     - BME std dev estimates [nTimes × 1]
%           .BMEvar     - BME variance estimates [nTimes × 1]
%           .nObsUsed   - Number of obs used per time [nTimes × 1]

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

%% Create estimation points for all sites × times
sk_all = [];
tk_all = [];
siteIndices = [];

for iReg = 1:nRegions
    regionName = regions{iReg};
    site = repSites.(regionName);

    for iTime = 1:nTimes
        sk_all = [sk_all; site.lon, site.lat];
        tk_all = [tk_all; tkVec(iTime)];
        siteIndices = [siteIndices; iReg];
    end
end

% Create space-time estimation points
pk = [sk_all, tk_all];

if opts.verbose
    fprintf('  Total estimation points: %d (= %d sites × %d times)\n\n', ...
        size(pk, 1), nRegions, nTimes);
end

%% Estimate at all sites

if opts.verbose
    fprintf('  Running BME estimation...\n');
    tic;
end

XkBMEm_all = nan(size(pk, 1), 1);
XkBMEv_all = nan(size(pk, 1), 1);
nObsUsed_all = zeros(size(pk, 1), 1);

if ~opts.performValidation
    % Standard estimation: Use all observations for all sites (more efficient)

    % Prepare soft data
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

    % Run BME estimation for all sites at once (vectorized)
    try
        [XkBMEm_all, XkBMEv_all] = krigingME_stug_multi(pk, KS.harddata.p, p_soft, ...
            KS.harddata.z, z_soft, vs_soft, KG.covmodel, KG.covparam, ...
            BMEparam.nhmax, BMEparam.nsmax, BMEparam.dmax, BMEparam.order, ...
            BMEparam.options, KS.harddata, soft_data);
        
        % print the number of NaNs and negative variances for debugging
        nNaNs = sum(isnan(XkBMEm_all));
        nNegVar = sum(XkBMEv_all < 0);
        fprintf('    BME estimation completed with %d NaN means and %d negative variances\n', nNaNs, nNegVar);

        XkBMEm_all(isnan(XkBMEm_all)) = 0;  % Fix NaN means (if any)
        XkBMEv_all(XkBMEv_all < 0) = 0;  % Fix negative variances

        nObsUsed_all(:) = size(KS.harddata.p, 1);

        % add global offset back to get final estimates
        gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, unique(sk_all, 'rows'), tk_all');
        YkBMEm_all = XkBMEm_all + gok;

    catch ME
        if opts.verbose
            warning('BME estimation failed: %s', ME.message);
        end
    end

else
    % Leave-one-out validation: Process each region separately

    for iReg = 1:nRegions
        regionName = regions{iReg};
        site = repSites.(regionName);

        % Find estimation points for this site
        siteIdx = (siteIndices == iReg);
        pk_site = pk(siteIdx, :);

        % Create leave-one-out hard data (exclude obs near this site)
        distToSite = sqrt((KS.harddata.p(:,1) - site.lon).^2 + ...
                         (KS.harddata.p(:,2) - site.lat).^2);
        keepObs = distToSite > opts.exclusionRadius;

        % Filter hard data
        KS_loo = KS;
        KS_loo.harddata.p = KS.harddata.p(keepObs, :);
        KS_loo.harddata.z = KS.harddata.z(keepObs);

        nObsUsed_all(siteIdx) = sum(keepObs);

        % Prepare soft data (same for all, no filtering needed)
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

        % Run BME estimation for this site
        try
            [XkBMEm, XkBMEv] = krigingME_stug_multi(pk_site, KS_loo.harddata.p, p_soft, ...
                KS_loo.harddata.z, z_soft, vs_soft, KG.covmodel, KG.covparam, ...
                BMEparam.nhmax, BMEparam.nsmax, BMEparam.dmax, BMEparam.order, ...
                BMEparam.options, KS_loo.harddata, soft_data);

            XkBMEm_all(siteIdx) = XkBMEm;
            XkBMEv_all(siteIdx) = XkBMEv;

        catch ME
            if opts.verbose
                warning('BME estimation failed for %s: %s', regionName, ME.message);
            end
        end

        if opts.verbose && mod(iReg, 5) == 0
            fprintf('    Completed %d/%d sites...\n', iReg, nRegions);
        end
    end
end



if opts.verbose
    fprintf('  Estimation completed in %.1f seconds\n', toc);
end

%% Reshape results back to site × time structure
for iReg = 1:nRegions
    regionName = regions{iReg};
    site = repSites.(regionName);

    % Extract results for this site
    siteIdx = (siteIndices == iReg);
    BMEmean = YkBMEm_all(siteIdx);
    BMEvar = XkBMEv_all(siteIdx);

    % Ensure variances are non-negative (fix for complex number warnings)
    BMEvar(BMEvar < 0) = 0;
    BMEstd = sqrt(BMEvar);

    nObsUsed = nObsUsed_all(siteIdx);

    % Store results
    siteEstimates.estimates.(regionName).regionName = regionName;
    siteEstimates.estimates.(regionName).lon = site.lon;
    siteEstimates.estimates.(regionName).lat = site.lat;
    siteEstimates.estimates.(regionName).BMEmean = BMEmean;
    siteEstimates.estimates.(regionName).BMEstd = BMEstd;
    siteEstimates.estimates.(regionName).BMEvar = BMEvar;
    siteEstimates.estimates.(regionName).nObsUsed = nObsUsed;
end

% Add metadata for tracking and documentation
siteEstimates.metadata.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
siteEstimates.metadata.nSites = nRegions;
siteEstimates.metadata.nTimes = nTimes;
siteEstimates.metadata.totalPoints = size(pk, 1);
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
