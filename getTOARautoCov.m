function cov = getTOARautoCov(obs, go, temporalModelType, forceEstCov)
% getTOARautoCov - Estimates covariance structure from TOAR residuals
%
% Computes residuals by removing global offset, then fits spatial and temporal
% covariance models for use in BME or kriging estimation.
%
% SYNTAX:
%   cov = getTOARautoCov(obs, go, temporalModelType, forceEstCov)
%
% INPUTS:
%   obs      - Structure from getTOARobservationalData
%   go       - Structure from getTOARglobalOffset
%   temporalModelType - 'holecos' or 'exponential'
%                       default: 'holecos'
%   forceEstCov - Force re-estimation (1) or use saved (0)
%                 default: 0
%
% OUTPUT:
%   cov - Structure with fields:
%         .covmodel  - Cell array of covariance model names
%         .covparam  - Cell array of covariance parameters
%         .var       - Total variance
%         .stmetric  - Space-time metric
%         .rLag, .Cr - Spatial lag and covariance
%         .tLag, .Ct - Temporal lag and covariance
%
% EXAMPLE:
%   obs = getTOARobservationalData('all', [2015 2020]);
%   go = getTOARglobalOffset(obs, 3);
%   cov = getTOARautoCov(obs, go, 'holecos', 0);

if nargin < 3, temporalModelType = 'holecos'; end
if nargin < 4, forceEstCov = 0; end

% Create covariance directories if needed
covDir = '3covariance';
figDir = fullfile(covDir, 'figs');
if ~exist(covDir, 'dir')
    mkdir(covDir);
    fid = fopen(fullfile(covDir, '0readme.txt'), 'w');
    fprintf(fid, 'The files in this folder were created by getTOARautoCov.m\n');
    fprintf(fid, 'Contains covariance models and diagnostic plots\n');
    fclose(fid);
end
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

% Set filenames based on go.scenario and obs.logTransf
covFile = sprintf('Cov_go%d_lt%d.mat', go.scenario, obs.logTransf);
figFile = sprintf('Cov_go%d_lt%d.png', go.scenario, obs.logTransf);
covPath = fullfile(covDir, covFile);
figPath = fullfile(figDir, figFile);

% Check if covariance already exists
if exist(covPath, 'file') && ~forceEstCov
    fprintf('Loading existing covariance from %s\n', covPath);
    load(covPath, 'cov');
    return;
end

fprintf('--- Running getTOARautoCov (Temporal Model: %s) ---\n', temporalModelType);

%% --- Calculate Residuals ---
fprintf('  Computing residuals (Observations - Global Offset)...\n');
Ygo = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, obs.sMS, obs.tME);
Zh = obs.Y - Ygo;

if isempty(Zh) || all(isnan(Zh(:)))
    warning('Residuals are empty or all NaN. Returning pure nugget covariance.');
    cov.covmodel = {'nuggetC'}; cov.covparam = {1}; cov.var = 1; cov.stmetric = NaN;
    return;
end

%% --- Extract coordinates ---
sMS = obs.sMS;
tME = obs.tME;

%% --- Spatial Covariance Calculation & Fitting ---
fprintf('  Calculating and fitting spatial covariance...\n');
D = coord2dist(sMS, sMS);
d = D(D > 0 & isfinite(D));
if isempty(d)
    warning('Could not compute valid distances. Returning pure nugget.');
    cov.covmodel = {'nuggetC'}; cov.covparam = {nanmean(var(Zh,0,1,'omitnan'))}; cov.var = cov.covparam{1}; cov.stmetric = 1000;
    return;
end
edges = [0, quantest(d, [0.05, 0.10, 0.15, 0.20, 0.30, 0.50, 0.75])];
edges = unique(edges);
if length(edges) < 2, edges = [0, max(d)]; end
rLag = [0, 0.5*(edges(1:end-1) + edges(2:end))];
rLagTol = [0, diff(edges)/2.01];
[Cr, ~] = stcov(Zh, sMS, tME, Zh, sMS, tME, rLag, rLagTol, 0, 0);
varSpatial = Cr(1);
if isnan(varSpatial) || varSpatial <= 1e-6, varSpatial = nanmean(var(Zh,0,1,'omitnan')); end

spatialModel = @(params, r) params(1)*exp(-3*r/params(2)) + (varSpatial - params(1))*exp(-3*r/params(3));
initParams_spatial = [0.5*varSpatial, rLag(2), rLag(end)];

lb_spatial = [0, 3, 3];

ub_spatial = [varSpatial, max(rLag)*2, max(rLag)*5];
% ub_spatial = [varSpatial, 50, 50];  % CAP spatial ranges at 50 degrees!

rLag_col = rLag(:); Cr_col = Cr(:); valid_idx = ~isnan(Cr_col) & ~isnan(rLag_col);
opts = optimoptions('lsqcurvefit', 'Display', 'none', 'MaxIterations', 2000);
try
    bestParams_spatial = lsqcurvefit(spatialModel, initParams_spatial, rLag_col(valid_idx), Cr_col(valid_idx), lb_spatial, ub_spatial, opts);
    c1 = bestParams_spatial(1); c2 = varSpatial - c1; ar1 = bestParams_spatial(2); ar2 = bestParams_spatial(3);
catch
    warning('Spatial model fitting failed. Using simplified model.');
    c1 = varSpatial; c2 = 0; ar1 = max(rLag); ar2 = max(rLag);
end

%% --- Temporal Covariance Calculation ---
fprintf('  Calculating experimental temporal covariance...\n');
timeSpan = max(tME) - min(tME);
tLag = 0:1/12:timeSpan;
if isempty(tLag), tLag = 0; end
tLagTol = [0, 0.01*ones(1, length(tLag)-1)];
[Ct, ~] = stcov(Zh, sMS, tME, Zh, sMS, tME, 0, 0, tLag, tLagTol);
varTemporal = Ct(1);
if isnan(varTemporal) || varTemporal <= 0, varTemporal = varSpatial; end

%% --- Temporal Model Fitting ---
fprintf('  Fitting temporal model using ''%s'' model...\n', temporalModelType);
tLag_col = tLag(:); Ct_col = Ct(:);
valid_idx_t = ~isnan(Ct_col) & ~isnan(tLag_col);

switch lower(temporalModelType)
    case 'holecos'
        temporalModel = @(params, t) params(1)*exp(-3*t/params(2)) + (varTemporal - params(1))*cos(pi*t/params(3));
        initParams_temporal = [0.5*varTemporal, 0.2, 0.5];
        lb_temporal = [0, 0, 0];
        ub_temporal = [varTemporal, 2, 2];
        covmodel_t = {'exponentialC', 'holecosC'};
        
        try
            bestParams_temporal = lsqcurvefit(temporalModel, initParams_temporal, tLag_col(valid_idx_t), Ct_col(valid_idx_t), lb_temporal, ub_temporal, opts);
            c3 = bestParams_temporal(1); c4 = varTemporal - c3; at1 = bestParams_temporal(2); at2 = bestParams_temporal(3);
        catch
             warning('Temporal model fitting failed. Using simplified model.');
             c3 = varTemporal; c4 = 0; at1 = 2; at2 = 2;
        end

    case 'exponential'
        at2_fixed = 1000; 
        temporalModel = @(params, t) params(1)*exp(-3*t/params(2)) + (varTemporal - params(1))*exp(-3*t/at2_fixed);
        initParams_temporal = [0.5*varTemporal, 0.5]; 
        lb_temporal = [0, 1/24]; 
        ub_temporal = [varTemporal, 2]; 
        covmodel_t = {'exponentialC', 'exponentialC'};
        
        try
            bestParams_temporal = lsqcurvefit(temporalModel, initParams_temporal, tLag_col(valid_idx_t), Ct_col(valid_idx_t), lb_temporal, ub_temporal, opts);
            c3 = bestParams_temporal(1);
            at1 = bestParams_temporal(2);
            c4 = varTemporal - c3; 
            at2 = at2_fixed;
        catch
             warning('Temporal model fitting failed. Using simplified model.');
             c3 = varTemporal; c4 = 0; at1 = 2; at2 = at2_fixed;
        end
    otherwise
        error('Unknown temporalModelType: %s', temporalModelType);
end

%% --- Assemble Final Covariance Structure ---
fprintf('  Assembling final covariance structure...\n');
v = varSpatial;
c1n = c1/v; c2n = c2/v; c3n = c3/v; c4n = c4/v;
c01 = max(0, c1n*c3n*v); c02 = max(0, c1n*c4n*v);
c03 = max(0, c2n*c3n*v); c04 = max(0, c2n*c4n*v);

cov.covmodel = {['exponentialC/' covmodel_t{1}], ['exponentialC/' covmodel_t{2}], ...
                ['exponentialC/' covmodel_t{1}], ['exponentialC/' covmodel_t{2}]};
cov.rLag = rLag; cov.Cr = Cr;
cov.tLag = tLag; cov.Ct = Ct;
cov.var = v;
cov.covparam = {[c01, ar1, at1], [c02, ar1, at2], [c03, ar2, at1], [c04, ar2, at2]};
totalCov = c01+c02+c03+c04;
if totalCov > 0, cov.stmetric = (c01*ar1/at1 + c02*ar1/at2 + c03*ar2/at1 + c04*ar2/at2) / totalCov;
else, cov.stmetric = 1000; end

%% --- Save Covariance ---
save(covPath, 'cov');
fprintf('  Saved covariance to: %s\n', covPath);

%% --- Save Figure ---
fprintf('  Generating and saving covariance plot...\n');
fig = figure('Visible', 'off');
try 
    ax1 = subplot(2,1,1);
    plot(ax1, rLag, Cr, 'bo', 'MarkerFaceColor','b', 'DisplayName', 'Experimental'); hold(ax1, 'on');
    r_fine = linspace(0, max(rLag_col(valid_idx)), 500); 
    plot(ax1, r_fine, spatialModel(bestParams_spatial, r_fine), 'r-', 'LineWidth', 1.5, 'DisplayName', 'Fitted Model');
    xlabel(ax1, 'Spatial Lag (deg)'); ylabel(ax1, 'Covariance'); title(ax1, 'Spatial Covariance Fit'); grid(ax1, 'on'); legend(ax1, 'show', 'Location','best'); hold(ax1, 'off');

    ax2 = subplot(2,1,2);
    plot(ax2, tLag, Ct, 'bo', 'MarkerFaceColor','b', 'DisplayName', 'Experimental'); hold(ax2, 'on');
    t_fine = linspace(0, max(tLag_col(valid_idx_t)), 500); 
    plot(ax2, t_fine, temporalModel(bestParams_temporal, t_fine), 'r-', 'LineWidth', 1.5, 'DisplayName', 'Fitted Model');
    xlabel(ax2, 'Temporal Lag (Years)'); ylabel(ax2, 'Covariance'); title(ax2, 'Temporal Covariance Fit'); grid(ax2, 'on'); legend(ax2, 'show', 'Location','best'); hold(ax2, 'off');

    sgtitle(fig, sprintf('TOAR Covariance: GO=%d, LT=%d', go.scenario, obs.logTransf), 'FontWeight','bold');

    exportgraphics(fig, figPath, 'Resolution', 150);
    fprintf('  Saved covariance plot to: %s\n', figPath);
catch ME_plot
    warning('Could not generate or save covariance figure: %s', ME_plot.message);
end
if ishandle(fig); close(fig); end

fprintf('--- Finished getTOARautoCov ---\n');
end