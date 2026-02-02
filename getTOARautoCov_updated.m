function cov = getTOARautoCov_updated(obs, go, temporalModelType, forceEstCov, inValidation)
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
%   inValidation - Flag indicating if this is for validation (1) or training (0)
%                  default: 0
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
if nargin < 5, inValidation = 0; end

% Create covariance directories if needed
covDir = '3covariance';
figDir = fullfile(covDir, 'figs');

if inValidation
    covDir = fullfile(covDir, 'validation');
    figDir = fullfile(covDir, 'figs');
end

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

% Extract year range from obs.tME
if isfield(obs, 'tME') && ~isempty(obs.tME)
    tME_years = year(datetime(obs.tME, 'ConvertFrom', 'datenum'));
    yearStart = min(tME_years);
    yearEnd = max(tME_years);
else
    yearStart = NaN;
    yearEnd = NaN;
end

% Set filenames including temporal model and year range
if ~isnan(yearStart) && ~isnan(yearEnd)
    covFile = sprintf('Cov_go%d_lt%d_%s_%d-%d.mat', ...
        go.scenario, obs.logTransf, temporalModelType, yearStart, yearEnd);
    figFile = sprintf('Cov_go%d_lt%d_%s_%d-%d.png', ...
        go.scenario, obs.logTransf, temporalModelType, yearStart, yearEnd);
else
    % Fallback if year range unavailable
    covFile = sprintf('Cov_go%d_lt%d_%s.mat', go.scenario, obs.logTransf, temporalModelType);
    figFile = sprintf('Cov_go%d_lt%d_%s.png', go.scenario, obs.logTransf, temporalModelType);
end

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
    cov.covmodel = {'nuggetC'}; cov.covparam = {mean(var(Zh,0,1,'omitnan'), "omitmissing")}; cov.var = cov.covparam{1}; cov.stmetric = 1000;
    return;
end
edges = [0, quantest(d, [0.05, 0.10, 0.15, 0.20, 0.30, 0.50, 0.75])];
edges = unique(edges);
if length(edges) < 2, edges = [0, max(d)]; end
rLag = [0, 0.5*(edges(1:end-1) + edges(2:end))];
rLagTol = [0, diff(edges)/2.01];
[Cr, ~] = stcov(Zh, sMS, tME, Zh, sMS, tME, rLag, rLagTol, 0, 0);
varSpatial = Cr(1);
if isnan(varSpatial) || varSpatial <= 1e-6, varSpatial = mean(var(Zh,0,1,'omitnan'), "omitmissing"); end

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

% Add small nugget for numerical stability (2% of variance)
nuggetFrac = 0.02;
nuggetVar = nuggetFrac * varTemporal;
effectiveVar = varTemporal - nuggetVar;  % Variance available for structured components

switch lower(temporalModelType)
    case 'holecos'
        % CORRECTED: Proper damped holecos model
        % holecosC(t) = sigma^2 * exp(-3*t/a) * cos(pi*t/a)
        % We fit: c3*exp(-3*t/at1) + c4*exp(-3*t/at2)*cos(pi*t/at2)
        %         ^-- exponentialC     ^-- holecosC (damped!)
        
        temporalModel = @(params, t) params(1)*exp(-3*t/params(2)) + ...
                                     (effectiveVar - params(1))*exp(-3*t/params(3)).*cos(pi*t/params(3));
        
        % Initial parameters: [c3, at1 (exp range), at2 (holecos range)]
        % at2 controls BOTH damping and period - for annual cycle, at2 ≈ 0.5 years
        initParams_temporal = [0.3*effectiveVar, 0.15, 0.5];
        
        % Bounds - constrain holecos range to give reasonable seasonal behavior
        lb_temporal = [0, 0.01, 0.3];      % at2 >= 0.3 ensures damping before full oscillation
        ub_temporal = [effectiveVar, 1, 1]; % at2 <= 1 keeps period reasonable
        
        covmodel_t = {'exponentialC', 'holecosC'};
        
        try
            bestParams_temporal = lsqcurvefit(temporalModel, initParams_temporal, ...
                tLag_col(valid_idx_t), Ct_col(valid_idx_t), lb_temporal, ub_temporal, opts);
            c3 = bestParams_temporal(1); 
            c4 = effectiveVar - c3; 
            at1 = bestParams_temporal(2); 
            at2 = bestParams_temporal(3);
            
            % CRITICAL CHECK: Ensure holecos coefficient is stable
            % If c4 is too large relative to c3, the model can still be ill-conditioned
            if c4 > 0.7 * effectiveVar
                warning('Holecos component dominates (%.1f%%). Rebalancing for stability.', 100*c4/effectiveVar);
                c4 = 0.7 * effectiveVar;
                c3 = effectiveVar - c4;
            end
            
        catch ME
            warning('Temporal model fitting failed: %s. Using simplified model.', ME.message);
            c3 = 0.7*effectiveVar; c4 = 0.3*effectiveVar; at1 = 0.2; at2 = 0.5;
        end

    case 'exponential'
        % Your existing exponential code is fine
        at2_fixed = 1000; 
        temporalModel = @(params, t) params(1)*exp(-3*t/params(2)) + ...
                                     (effectiveVar - params(1))*exp(-3*t/at2_fixed);
        initParams_temporal = [0.5*effectiveVar, 0.5]; 
        lb_temporal = [0, 1/24]; 
        ub_temporal = [effectiveVar, 2]; 
        covmodel_t = {'exponentialC', 'exponentialC'};
        
        try
            bestParams_temporal = lsqcurvefit(temporalModel, initParams_temporal, ...
                tLag_col(valid_idx_t), Ct_col(valid_idx_t), lb_temporal, ub_temporal, opts);
            c3 = bestParams_temporal(1);
            at1 = bestParams_temporal(2);
            c4 = effectiveVar - c3; 
            at2 = at2_fixed;
        catch
            warning('Temporal model fitting failed. Using simplified model.');
            c3 = effectiveVar; c4 = 0; at1 = 2; at2 = at2_fixed;
        end
        
    otherwise
        error('Unknown temporalModelType: %s', temporalModelType);
end

%% --- Assemble Final Covariance Structure (WITH NUGGET) ---
fprintf('  Assembling final covariance structure...\n');
v = varSpatial;

% Include nugget in the model
c1n = c1/v; c2n = c2/v; c3n = c3/v; c4n = c4/v;
c01 = max(0, c1n*c3n*v); 
c02 = max(0, c1n*c4n*v);
c03 = max(0, c2n*c3n*v); 
c04 = max(0, c2n*c4n*v);

% Add nugget as first component
cov.covmodel = {'nuggetC/nuggetC', ...  % NUGGET FOR STABILITY
                ['exponentialC/' covmodel_t{1}], ['exponentialC/' covmodel_t{2}], ...
                ['exponentialC/' covmodel_t{1}], ['exponentialC/' covmodel_t{2}]};

cov.covparam = {nuggetVar, ...  % Nugget variance
                [c01, ar1, at1], [c02, ar1, at2], ...
                [c03, ar2, at1], [c04, ar2, at2]};

cov.rLag = rLag; cov.Cr = Cr;
cov.tLag = tLag; cov.Ct = Ct;
cov.var = v;

% Adjust stmetric calculation to account for nugget
totalCov = c01+c02+c03+c04;
if totalCov > 0
    cov.stmetric = (c01*ar1/at1 + c02*ar1/at2 + c03*ar2/at1 + c04*ar2/at2) / totalCov;
else
    cov.stmetric = 1000;
end

% Store metadata for file naming and plotting
cov.temporalModel = temporalModelType;
if ~isnan(yearStart) && ~isnan(yearEnd)
    cov.yearRange = [yearStart, yearEnd];
end

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

    % Enhanced title with all metadata
    if ~isnan(yearStart) && ~isnan(yearEnd)
        sgtitle(fig, sprintf('TOAR Covariance: GO=%d, LT=%d, %s, %d-%d', ...
            go.scenario, obs.logTransf, upper(temporalModelType), yearStart, yearEnd), 'FontWeight','bold');
    else
        sgtitle(fig, sprintf('TOAR Covariance: GO=%d, LT=%d, %s', ...
            go.scenario, obs.logTransf, upper(temporalModelType)), 'FontWeight','bold');
    end

    exportgraphics(fig, figPath, 'Resolution', 150);
    fprintf('  Saved covariance plot to: %s\n', figPath);
catch ME_plot
    fprintf(1, 'Could not generate or save covariance figure: %s', ME_plot.message);
end
if ishandle(fig); close(fig); end

fprintf('--- Finished getTOARautoCov ---\n');
end