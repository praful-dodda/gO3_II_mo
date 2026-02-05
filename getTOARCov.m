function cov = getTOARCov(obs, go, varargin)
% getTOARCov - Compute or load cached covariance model for the selected GO scenario
%
% SYNTAX:
%   cov = getTOARCov(obs, go, varargin)
%
% INPUTS:
%   obs - Observational data structure
%   go  - Global offset data structure
%   varargin - Optional arguments:
%     'temporalModelType' - Temporal covariance model type (default: 'holecos')
%     'yearRange'         - Year range for covariance computation (default: set from obs)
%     'forceCov'          - Force recomputation (default: 0)
%     'covPlot'           - Plot covariance results (default: 0)
%     'version'           - to specify what covariance function to use (default: 'updated')
%
% OUTPUTS:
%   cov - Computed or loaded covariance model
%
% EXAMPLE:
% ...

%% Input validation
if nargin < 2
    error('At least 2 inputs required: obs and go');
end

%% Parse inputs
p = inputParser;
addParameter(p, 'temporalModelType', 'holecos', @(x) ischar(x) || isstring(x));
addParameter(p, 'yearRange', [], @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'forceCov', 0, @(x) isnumeric(x) && ismember(x, [0 1]));
addParameter(p, 'covPlot', 0, @(x) isnumeric(x) && ismember(x, [-1 0 1]));
addParameter(p, 'version', 'updated', @(x) ischar(x) || isstring(x));

parse(p, temporalModelType,  yearRange, varargin{:});
opts = p.Results;

%% Setup Cache directory
covDir = './3covariance/';
if ~exist(covDir, 'dir')
    mkdir(covDir);
    fid = fopen(fullfile(covDir, '0readme.txt'), 'w');
    fprintf(fid, 'Fold-specific covariance models for Checker-Board Validation\n');
    fprintf(fid, 'Created by getTOARautoCov_CBV.m\n');
    fprintf(fid, 'Each file contains covariance computed using only training stations for that fold\n');
    fprintf(fid, '\nFilename format: Cov_go{scenario}_lt{logTransf}_{tempModel}_CBV_box{size}_fold{fold}.mat\n');
    fclose(fid);
end

%% Create cache filename with year range
if isempty(yearRange) || any(isnan(yearRange))
    yearRange = [min(floor(obs.tME(:))), max(ceil(obs.tME(:)))];
else
    yearRange = yearRange;
end

covFile = sprintf('Cov_go%d_lt%d_%s_%d-%d.mat', ...
    go.scenario, obs.logTransf, temporalModelType, yearRange(1), yearRange(2));
covPath = fullfile(covDir, covFile);

%% Check cache
if exist(covPath, 'file') && ~opts.forceCov
    fprintf('      Loading cached Cov from: %s\n', covFile);
    load(covPath, 'cov');
    return;
end

%% Compute covariance
fprintf('      Computing Cov (go %d, %s, years %d-%d)...\n', ...
    go.scenario, temporalModelType, yearRange(1), yearRange(2));

if strcmpi(opts.version, 'updated')
    cov = getTOARautoCov_updated(obs, go, temporalModelType, 0, 1);
else
    cov = getTOARautoCov(obs, go, temporalModelType, 0, 1);
end


%% Save to cache
fprintf('        Saving Cov to cache...\n');
save(covPath, 'cov', '-v7.3');
fprintf('        Cov computed and cached.\n');

%% Create diagnostic plots if requested
if opts.covPlot == 1
    plotTOARcovariance(cov, 'obs', obs, 'go', go, 'visible', 'on');
end

end