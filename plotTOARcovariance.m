function [figPaths, paramSummary] = plotTOARcovariance(cov, varargin)
% plotTOARcovariance - Modern covariance plotting with comprehensive diagnostics
%
% Creates publication-quality plots of spatial and temporal covariance models
% with experimental variograms and fitted curves. Returns figure paths and
% parameter summary for reporting.
%
% SYNTAX:
%   [figPaths, paramSummary] = plotTOARcovariance(cov)
%   [figPaths, paramSummary] = plotTOARcovariance(cov, 'Name', Value, ...)
%
% INPUTS:
%   cov - Covariance structure from getTOARautoCov, getTOARautoCov_updated,
%         or getTOARautoCov_CBV containing:
%         .covmodel  - Cell array of covariance model names
%         .covparam  - Cell array of covariance parameters
%         .var       - Total variance
%         .stmetric  - Space-time metric
%         .rLag      - Spatial lag vector
%         .Cr        - Experimental spatial covariance
%         .tLag      - Temporal lag vector
%         .Ct        - Experimental temporal covariance
%
% OPTIONAL PARAMETERS:
%   'obs'          - Observation structure (for metadata)
%   'go'           - Global offset structure (for metadata)
%   'saveDir'      - Directory to save figures (default: './3covariance/figs')
%   'filePrefix'   - Prefix for saved filenames (default: 'TOARcov')
%   'dpi'          - Resolution in DPI (default: 300)
%   'visible'      - 'on' or 'off' for figure visibility (default: 'off')
%   'plotStyle'    - 'publication' or 'diagnostic' (default: 'publication')
%   'saveFigs'     - Boolean to save figures (default: true)
%
% OUTPUTS:
%   figPaths     - Cell array of saved figure paths
%   paramSummary - Structure with:
%                  .covmodel    - Model names
%                  .covparam    - Parameters
%                  .var         - Variance
%                  .stmetric    - Space-time metric
%                  .spatialParams - Formatted spatial parameters
%                  .temporalParams - Formatted temporal parameters
%
% EXAMPLE:
%   obs = getTOARobservationalData('all', [2015 2020]);
%   go = getTOARglobalOffset(obs, 3);
%   cov = getTOARautoCov(obs, go, 'holecos', 0);
%   [figPaths, params] = plotTOARcovariance(cov, 'obs', obs, 'go', go, ...
%       'visible', 'on', 'plotStyle', 'publication');
%
% SEE ALSO:
%   getTOARautoCov, getTOARautoCov_updated, getTOARautoCov_CBV, plotTOARcov

%% Parse inputs
p = inputParser;
addRequired(p, 'cov', @isstruct);
addParameter(p, 'obs', struct(), @isstruct);
addParameter(p, 'go', struct(), @isstruct);
addParameter(p, 'saveDir', './3covariance/figs', @ischar);
addParameter(p, 'filePrefix', 'TOARcov', @ischar);
addParameter(p, 'dpi', 300, @isnumeric);
addParameter(p, 'visible', 'off', @(x) ismember(x, {'on', 'off'}));
addParameter(p, 'plotStyle', 'publication', @(x) ismember(x, {'publication', 'diagnostic'}));
addParameter(p, 'saveFigs', true, @islogical);

parse(p, cov, varargin{:});
opts = p.Results;

%% Create save directory if needed
if opts.saveFigs && ~exist(opts.saveDir, 'dir')
    mkdir(opts.saveDir);
end

figPaths = {};

%% Extract metadata from obs and go if available
goScenario = [];
logTransf = [];
Yname = 'Ozone MDA8';
Ylabel = 'ppb';

if ~isempty(fieldnames(opts.go))
    goScenario = opts.go.scenario;
end

if ~isempty(fieldnames(opts.obs))
    if isfield(opts.obs, 'logTransf')
        logTransf = opts.obs.logTransf;
    end
    if isfield(opts.obs, 'Yname')
        Yname = opts.obs.Yname;
    end
    if isfield(opts.obs, 'Ylabel')
        Ylabel = opts.obs.Ylabel;
    end
end

%% Prepare covariance model parameters for fitting curves
% Determine the best-fit spatial model
if isfield(cov, 'rLag') && isfield(cov, 'Cr')
    rLag = cov.rLag;
    Cr = cov.Cr;

    % Create fine-grained distance vector for smooth fitted curve
    validR = rLag(~isnan(Cr));
    if ~isempty(validR) && max(validR) > 0
        r_fine = linspace(0, max(validR), 500);
    else
        r_fine = linspace(0, 1, 500);
    end
else
    rLag = [];
    Cr = [];
    r_fine = [];
end

% Determine the best-fit temporal model
if isfield(cov, 'tLag') && isfield(cov, 'Ct')
    tLag = cov.tLag;
    Ct = cov.Ct;

    % Create fine-grained time vector for smooth fitted curve
    validT = tLag(~isnan(Ct));
    if ~isempty(validT) && max(validT) > 0
        t_fine = linspace(0, max(validT), 500);
    else
        t_fine = linspace(0, 1, 500);
    end
else
    tLag = [];
    Ct = [];
    t_fine = [];
end

%% Evaluate fitted covariance models
% Spatial covariance: C(r, tau=0)
if ~isempty(r_fine) && isfield(cov, 'covmodel') && isfield(cov, 'covparam')
    c1_spatial = [r_fine(:), zeros(length(r_fine), 1), zeros(length(r_fine), 1)];
    c2_spatial = [0, 0, 0];
    Cr_fitted = coord2K(c1_spatial, c2_spatial, cov.covmodel, cov.covparam);
else
    Cr_fitted = [];
end

% Temporal covariance: C(r=0, tau)
if ~isempty(t_fine) && isfield(cov, 'covmodel') && isfield(cov, 'covparam')
    c1_temporal = [zeros(length(t_fine), 1), zeros(length(t_fine), 1), t_fine(:)];
    c2_temporal = [0, 0, 0];
    Ct_fitted = coord2K(c1_temporal, c2_temporal, cov.covmodel, cov.covparam);
else
    Ct_fitted = [];
end

%% Figure 1: Spatial and Temporal Covariance (2-panel)
fig1 = figure('Visible', opts.visible, 'Position', [100, 100, 1200, 500]);

% Panel 1: Spatial Covariance
subplot(1, 2, 1);
hold on;

% Plot experimental values
if ~isempty(rLag) && ~isempty(Cr)
    plot(rLag, Cr, 'o', 'MarkerSize', 8, 'MarkerFaceColor', [0.3 0.6 0.9], ...
        'MarkerEdgeColor', [0.1 0.3 0.6], 'LineWidth', 1.5, 'DisplayName', 'Experimental');
end

% Plot fitted model
if ~isempty(r_fine) && ~isempty(Cr_fitted)
    plot(r_fine, Cr_fitted, '-', 'Color', [0.8 0.2 0.2], 'LineWidth', 2.5, ...
        'DisplayName', 'Fitted Model');
end

xlabel('Spatial Lag r (degrees)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Covariance C(r, \tau=0)', 'FontSize', 12, 'FontWeight', 'bold');
title('Spatial Covariance', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 11);
grid on;
box on;
set(gca, 'FontSize', 11, 'LineWidth', 1.2);

% Add variance line
if isfield(cov, 'var') && ~isnan(cov.var)
    yLim = get(gca, 'YLim');
    if cov.var >= yLim(1) && cov.var <= yLim(2)
        plot(xlim, [cov.var cov.var], '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1, ...
            'DisplayName', sprintf('Variance = %.2f', cov.var));
    end
end

hold off;

% Panel 2: Temporal Covariance
subplot(1, 2, 2);
hold on;

% Plot experimental values
if ~isempty(tLag) && ~isempty(Ct)
    plot(tLag, Ct, 'o', 'MarkerSize', 8, 'MarkerFaceColor', [0.3 0.6 0.9], ...
        'MarkerEdgeColor', [0.1 0.3 0.6], 'LineWidth', 1.5, 'DisplayName', 'Experimental');
end

% Plot fitted model
if ~isempty(t_fine) && ~isempty(Ct_fitted)
    plot(t_fine, Ct_fitted, '-', 'Color', [0.8 0.2 0.2], 'LineWidth', 2.5, ...
        'DisplayName', 'Fitted Model');
end

xlabel('Temporal Lag \tau (years)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Covariance C(r=0, \tau)', 'FontSize', 12, 'FontWeight', 'bold');
title('Temporal Covariance', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 11);
grid on;
box on;
set(gca, 'FontSize', 11, 'LineWidth', 1.2);

% Add variance line
if isfield(cov, 'var') && ~isnan(cov.var)
    yLim = get(gca, 'YLim');
    if cov.var >= yLim(1) && cov.var <= yLim(2)
        plot(xlim, [cov.var cov.var], '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1, ...
            'DisplayName', sprintf('Variance = %.2f', cov.var));
    end
end

hold off;

% Overall title
if ~isempty(goScenario) && ~isempty(logTransf)
    sgtitle(sprintf('%s Covariance Model (GO=%d, LogTransf=%d)', Yname, goScenario, logTransf), ...
        'FontSize', 16, 'FontWeight', 'bold');
else
    sgtitle(sprintf('%s Covariance Model', Yname), 'FontSize', 16, 'FontWeight', 'bold');
end

% Save figure
if opts.saveFigs
    if ~isempty(goScenario) && ~isempty(logTransf)
        filename1 = sprintf('%s_go%d_lt%d_spatial_temporal.png', opts.filePrefix, goScenario, logTransf);
    else
        filename1 = sprintf('%s_spatial_temporal.png', opts.filePrefix);
    end
    figPath1 = fullfile(opts.saveDir, filename1);
    exportgraphics(fig1, figPath1, 'Resolution', opts.dpi);
    figPaths{end+1} = figPath1;
    fprintf('  Saved covariance plot: %s\n', filename1);
end

if strcmp(opts.visible, 'off')
    close(fig1);
end

%% Figure 2: 3D Space-Time Covariance (if diagnostic style)
if strcmp(opts.plotStyle, 'diagnostic') && isfield(cov, 'covmodel') && isfield(cov, 'covparam')
    fig2 = figure('Visible', opts.visible, 'Position', [100, 100, 800, 600]);

    % Create grid for 3D plot
    rg = [0:.01:.08 0.1:.02:.5];  % Spatial lags in degrees
    tg = [0:0.2:0.9 1:0.5:10];     % Temporal lags in years
    [rmg, tmg] = meshgrid(rg, tg);

    % Evaluate covariance model
    c1_3d = [rmg(:), zeros(numel(rmg), 1), tmg(:)];
    c2_3d = [0, 0, 0];
    cmg = coord2K(c1_3d, c2_3d, cov.covmodel, cov.covparam);
    cmg = reshape(cmg, size(rmg));

    % Create 3D surface plot
    hl = mesh(112 * rmg, tmg, cmg);  % Convert degrees to km (1 deg ≈ 112 km)
    shading interp;
    set(gca, 'XDir', 'rev');
    set(gca, 'YDir', 'rev');
    xlabel('Spatial Lag r (km)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Temporal Lag \tau (years)', 'FontSize', 12, 'FontWeight', 'bold');
    zlabel(sprintf('Covariance (%s²)', Ylabel), 'FontSize', 12, 'FontWeight', 'bold');

    if ~isempty(goScenario) && ~isempty(logTransf)
        title(sprintf('3D Space-Time Covariance (GO=%d, LogTransf=%d)', goScenario, logTransf), ...
            'FontSize', 14, 'FontWeight', 'bold');
    else
        title('3D Space-Time Covariance', 'FontSize', 14, 'FontWeight', 'bold');
    end

    colorbar;
    set(gca, 'FontSize', 11, 'LineWidth', 1.2);

    % Save figure
    if opts.saveFigs
        if ~isempty(goScenario) && ~isempty(logTransf)
            filename2 = sprintf('%s_go%d_lt%d_3D.png', opts.filePrefix, goScenario, logTransf);
        else
            filename2 = sprintf('%s_3D.png', opts.filePrefix);
        end
        figPath2 = fullfile(opts.saveDir, filename2);
        exportgraphics(fig2, figPath2, 'Resolution', opts.dpi);
        figPaths{end+1} = figPath2;
        fprintf('  Saved 3D covariance plot: %s\n', filename2);
    end

    if strcmp(opts.visible, 'off')
        close(fig2);
    end
end

%% Extract parameter summary for reporting
paramSummary = struct();
paramSummary.covmodel = cov.covmodel;
paramSummary.covparam = cov.covparam;
paramSummary.var = cov.var;

if isfield(cov, 'stmetric')
    paramSummary.stmetric = cov.stmetric;
else
    paramSummary.stmetric = NaN;
end

% Format spatial and temporal parameters for easy reading
paramSummary.spatialParams = formatCovParams(cov.covmodel, cov.covparam, 'spatial');
paramSummary.temporalParams = formatCovParams(cov.covmodel, cov.covparam, 'temporal');

% Add experimental data stats
if ~isempty(rLag) && ~isempty(Cr)
    paramSummary.spatialLagRange = [min(rLag), max(rLag)];
    paramSummary.spatialCovRange = [min(Cr(~isnan(Cr))), max(Cr(~isnan(Cr)))];
end

if ~isempty(tLag) && ~isempty(Ct)
    paramSummary.temporalLagRange = [min(tLag), max(tLag)];
    paramSummary.temporalCovRange = [min(Ct(~isnan(Ct))), max(Ct(~isnan(Ct)))];
end

end

%% Helper function to format covariance parameters
function paramStr = formatCovParams(covmodel, covparam, dimension)
    % Format covariance parameters for reporting
    %
    % dimension: 'spatial' or 'temporal'

    paramStr = {};

    for i = 1:length(covmodel)
        model = covmodel{i};
        param = covparam{i};

        % Parse model name (e.g., 'exponentialC/holecosC')
        if contains(model, '/')
            parts = strsplit(model, '/');
            spatialModel = parts{1};
            temporalModel = parts{2};
        else
            % Nugget or single component
            spatialModel = model;
            temporalModel = model;
        end

        if strcmp(dimension, 'spatial')
            % Extract spatial component
            if strcmp(spatialModel, 'nuggetC')
                if length(param) == 1
                    paramStr{end+1} = sprintf('Nugget: σ²=%.4f', param(1));
                else
                    paramStr{end+1} = sprintf('Nugget: σ²=%.4f', param(1));
                end
            elseif strcmp(spatialModel, 'exponentialC')
                if length(param) >= 2
                    paramStr{end+1} = sprintf('Exp: σ²=%.4f, ar=%.2f deg', param(1), param(2));
                end
            end
        else
            % Extract temporal component
            if strcmp(temporalModel, 'nuggetC')
                % Already handled in spatial
            elseif strcmp(temporalModel, 'exponentialC')
                if length(param) >= 3
                    paramStr{end+1} = sprintf('Exp: σ²=%.4f, at=%.2f yr', param(1), param(3));
                end
            elseif strcmp(temporalModel, 'holecosC')
                if length(param) >= 3
                    paramStr{end+1} = sprintf('HoleCos: σ²=%.4f, at=%.2f yr', param(1), param(3));
                end
            end
        end
    end

    if isempty(paramStr)
        paramStr = {'No parameters extracted'};
    end
end
