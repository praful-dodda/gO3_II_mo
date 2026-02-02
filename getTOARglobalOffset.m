function go = getTOARglobalOffset(obs, goScenario, goPlot, forceGOestimation, inValidation, verbose)
% getTOARglobalOffset - Estimates global offset for TOAR ozone data
%
% Models the space/time global offset for TOAR-II ozone data following
% the same methodology as getAPglobalOffset.m
%
% SYNTAX:
%  
% go = getTOARglobalOffset(obs, goScenario, goPlot);
%
% INPUT:
%
% obs         structure containing TOAR observational data from getTOARobservationalData
% goScenario  scalar specifying global offset scenario 
%             0 zero, 1 flat, 2 domain wide, 3 regional, 4 local
%             default: 3
% goPlot      scalar indicating plotting level
%             0 no plots, 1 basic plots, 2 detailed plots, 3 comprehensive plots
%             default: 1
% forceGOestimation scalar indicating whether to force re-estimation of global offset
%                   0 use existing if available, 1 force new estimation
%                   default: 0
% inValidation    scalar indicating if this is for validation (1) or training (0)
%                  default: 0
% verbose       scalar indicating verbosity level (0=quiet, 1=verbose)
%               default: 1
%
% OUTPUT:
% go   structure containing global offset:
%      go.logTransf      scalar   log transform flag
%      go.scenario       scalar   global offset scenario
%      go.sMSraw         nMS x 2  original station coordinates
%      go.tMEraw         1 x nME  original time vector
%      go.msRaw          nMS x 1  raw spatial means
%      go.mtRaw          1 x nME  raw temporal means
%      go.sMS            nMSd x 2 densified spatial coordinates
%      go.tME            1 x nMEd densified time vector
%      go.ms             nMSd x 1 smoothed spatial means
%      go.mt             1 x nMEd smoothed temporal means
%      go.goParam        1 x 5    global offset parameters
%      go.densParam      1 x 6    densification parameters

if nargin < 1, error('obs structure required'); end
if nargin < 2, goScenario = 3; end
if nargin < 3, goPlot = 1; end
if nargin < 4, forceGOestimation = 0; end
if nargin < 5, inValidation = 0; end
if nargin < 6, verbose = 1; end

if isnumeric(obs)
    error('obs must be a structure from getTOARobservationalData');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Input parameters - modify these to change grid resolution

% Resolution of global offset grid
inclvoronoi = 1;       % 1 to include Voronoi vertices 
inclgrid = 1;          % 1 to include a grid
% nxpix = 40;            % Number of pixels in x-direction
% nypix = 25;            % Number of pixels in y-direction 
nxpix = 20;
nypix = 15;
densifytME = 1;        % 1 to densify time
tMEtimeStep = 1/12;    % Monthly time step for densification
densParam = [inclvoronoi inclgrid nxpix nypix densifytME tMEtimeStep]; 
axMS = [-180 180 -60 75];  % Global domain [lonmin lonmax latmin latmax]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Extract year range from obs.tME
if isfield(obs, 'tME') && ~isempty(obs.tME)
    tME_years = year(datetime(obs.tME, 'ConvertFrom', 'datenum'));
    yearStart = min(tME_years);
    yearEnd = max(tME_years);
else
    yearStart = NaN;
    yearEnd = NaN;
end

% Create global offset directory and set filenames
if inValidation==0
    goDir='./2globalOffset';
    % Set filename for saved results including year range
    if ~isnan(yearStart) && ~isnan(yearEnd)
        goFile = sprintf('%sgo_%d_%d-%d.mat', obs.Zname, goScenario, yearStart, yearEnd);
    else
        goFile = sprintf('%sgo_%d.mat', obs.Zname, goScenario);
    end
else
    goDir='./2globalOffset/goValidation';
    % Set filename for saved results including year range
    if ~isnan(yearStart) && ~isnan(yearEnd)
        goFile = sprintf('%sgo_%d_val_%d-%d.mat', obs.Zname, goScenario, yearStart, yearEnd);
    else
        goFile = sprintf('%sgo_%d_val.mat', obs.Zname, goScenario);
    end
end

if ~exist(goDir, 'dir')
    mkdir(goDir);
    fid = fopen(fullfile(goDir, '0readme.txt'), 'w');
    fprintf(fid, 'The files in this folder were created by getTOARglobalOffset.m\n');
    fprintf(fid, 'See help getTOARglobalOffset.m for explanation.\n');
    fclose(fid);
end


% Load existing or compute new global offset
if exist(fullfile(goDir, goFile), 'file') && ~forceGOestimation
    load(fullfile(goDir, goFile), 'go');
    fprintf('Loaded existing global offset from %s\n', goFile);
else
    fprintf('Computing global offset for TOAR data (scenario %d)...\n', goScenario);
    
    % Set global offset parameters based on scenario
    switch goScenario
        case 0, goParam = [NaN NaN NaN NaN 0];           % Zero offset
        case 1, goParam = [10000 10000 10000 10000 0];   % Flat
        case 2, goParam = [180 5 50 20 0];               % Domain wide (global)
        case 3, goParam = [90 2 20 5 0];                 % Regional - spatial
        case 4, goParam = [45 0.5 10 2 0];               % Local - spatial
        case 5, goParam = [90 2 10 2 0];                 % Regional - spatial/temporal
        case 6, goParam = [45 0.5 5 1 0];               % Local - spatial/temporal
        case 7, goParam = [10 0.25 2 1 0];               % Super-Local - spatial/temporal
        case 8, goParam = [90, 5, 20, 5, 1];      % Regional (balanced)
        case 9, goParam = [60, 2, 15, 3, 1];      % Sub-regional
        case 10, goParam = [45, 1, 10, 2, 1];      % Local (with seasonal)
        case 11, goParam = [30, 0.5, 8, 1.5, 1];   % Fine-scale
    end
    
    % Create idMS if it doesn't exist (for compatibility with stmeanDensified)
    if ~isfield(obs, 'idMS')
        % obs.idMS = (1:size(obs.sMS, 1))';  % Simple numeric IDs
        obs.idMS = obs.stationID; % Use station IDs from data
    end
    
    % Calculate space/time mean and remove it from the data
    [msRaw, mssd, mtRaw, mtsd, sMSd, tMEd] = stmeanDensified(...
        obs.Y, obs.sMS, obs.idMS, obs.tME, goParam, densParam, axMS);
    
    % Handle zero scenario
    if goScenario == 0
        mssd = zeros(size(mssd));
        mtsd = zeros(size(mtsd));
    end
    
    % Build output structure
    go.logTransf = obs.logTransf;
    go.scenario = goScenario;
    go.sMSraw = obs.sMS;
    go.tMEraw = obs.tME;
    go.msRaw = msRaw;
    go.mtRaw = mtRaw;
    go.sMS = sMSd;
    go.tME = tMEd;
    go.ms = mssd;
    go.mt = mtsd;
    go.goParam = goParam;
    go.densParam = densParam;

    % Store year range metadata
    if ~isnan(yearStart) && ~isnan(yearEnd)
        go.yearRange = [yearStart, yearEnd];
    end

    % Save results
    save(fullfile(goDir, goFile), 'go');
    fprintf('Global offset saved to %s\n', goFile);
end

if verbose
    fprintf('Global offset scenario %d. \n', go.scenario);
    fprintf('  Radius of spatial neighborhood dNeib (deg.): %.2f\n', go.goParam(1));
    fprintf('  Spatial range of exponential smoothing function ar (deg): %.2f\n', go.goParam(2));
    fprintf('  Radius of temporal neighborhood tNeib (months): %.2f\n', go.goParam(3));
    fprintf('  Temporal range of exponential function smoothing at (months): %.2f\n', go.goParam(4));
    fprintf('  tloop, if tloop>0, the measured events are looped in a cycle of duration tloop (months): %d\n', go.goParam(5));
end

% Generate plots if requested
if goPlot >= 1
    plotTOARglobalOffset(obs, go, goPlot);
end

end