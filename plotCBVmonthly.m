function plotCBVmonthly(monthlyStats, valParam, varargin)
% plotCBVmonthly - Monthly and seasonal breakdown of CBV performance,
%   with optional multi-model comparison.
%
% SYNTAX:
%   plotCBVmonthly(monthlyStats, valParam)
%   plotCBVmonthly(monthlyStats, valParam, monthlyStats2, monthlyStats3, ...)
%
% INPUTS:
%   monthlyStats - Table from aggregateCBVmonthlyStats (primary method)
%   valParam     - valParam struct used when running CBV (for labels/paths)
%   varargin     - Additional monthlyStats tables for other BME methods
%
% PRODUCES (saved to 7validation/CBV/figures/):
%   Figure 1 — Seasonal cycle:    CBV_monthly_seasonal_BME[method]_go[scenario].png
%   Figure 2 — Time series:       CBV_monthly_timeseries_BME[method]_go[scenario].png
%   Figure 3 — Model comparison:  CBV_monthly_modelcomp_BME[method]_go[scenario].png
%              (Figure 3 only produced when multiple methods are supplied)
%
% EXAMPLE:
%   % Single method
%   plotCBVmonthly(T1, valParam);
%
%   % Compare three methods
%   plotCBVmonthly(T1, valParam, T2, T3);
%
% SEE ALSO:
%   aggregateCBVmonthlyStats, plotCBVresults, saveTOARfigure

%% Setup
figDir = fullfile('7validation', 'CBV', 'figures');
if ~exist(figDir, 'dir'), mkdir(figDir); end

monthAbbr = {'Jan','Feb','Mar','Apr','May','Jun', ...
             'Jul','Aug','Sep','Oct','Nov','Dec'};

nMethods = 1 + length(varargin);
allStats = [{monthlyStats}, varargin];

%% Resolve method labels (same logic as plotCBVresults.m lines 249-261)
methodNames = cell(1, nMethods);
for i = 1:nMethods
    T = allStats{i};
    ud = T.Properties.UserData;
    if ~isempty(ud) && isstruct(ud) && isfield(ud, 'BMEmethod')
        methodNames{i} = ud.BMEmethod;
    elseif i == 1
        methodNames{i} = valParam.BMEmethod;
    else
        methodNames{i} = sprintf('Method %d', i);
    end
end

colors = lines(nMethods);

%% Primary method label for filenames
primaryMethod  = valParam.BMEmethod;
goScenario     = valParam.goScenario;

fprintf('plotCBVmonthly: %d method(s) — %s\n', nMethods, strjoin(methodNames, ', '));

%% ================================================================
%% FIGURE 1: Seasonal cycle
%% Rows: R2 | RMSE | NMB | ME   (2x2 subplots)
%% ================================================================

metrics_seas     = {'R2',   'RMSE',  'NMB',  'ME'};
metricLabels_seas = {'R²',   'RMSE (ppbv)', 'NMB (%)', 'ME (ppbv)'};
reflines_seas    = {NaN,     NaN,     0,      0};

fig1 = figure('Position', [100 100 1200 800], 'Visible', 'off');

for iMetric = 1:4
    ax = subplot(2, 2, iMetric);
    hold(ax, 'on');

    for iMethod = 1:nMethods
        [mu, sg] = monthlySeasonalStats(allStats{iMethod}, metrics_seas{iMetric});

        xv = (1:12)';
        % Shaded uncertainty band (±1 std across years and folds)
        validBand = isfinite(mu) & isfinite(sg);
        if any(validBand)
            xFill = [xv(validBand); flipud(xv(validBand))];
            yFill = [mu(validBand) + sg(validBand); ...
                     flipud(mu(validBand) - sg(validBand))];
            fill(ax, xFill, yFill, colors(iMethod,:), ...
                'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off');
        end
        % Mean line
        plot(ax, xv, mu, '-o', 'Color', colors(iMethod,:), ...
            'LineWidth', 2, 'MarkerSize', 6, ...
            'DisplayName', methodNames{iMethod});
    end

    % Reference line for bias panels
    refVal = reflines_seas{iMetric};
    if ~isnan(refVal)
        yline(refVal, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
    end

    set(ax, 'XTick', 1:12, 'XTickLabel', monthAbbr, 'XLim', [0.5 12.5]);
    xlabel(ax, 'Month');
    ylabel(ax, metricLabels_seas{iMetric});
    title(ax, metricLabels_seas{iMetric});
    grid(ax, 'on');
    if iMetric == 1
        legend(ax, 'Location', 'best', 'Interpreter', 'none');
    end
end

sgtitle(fig1, sprintf('Seasonal Cycle in CBV Performance — GO%d (shading = \\pm1 std across years)', ...
    goScenario));

basename1 = sprintf('CBV_monthly_seasonal_BME%s_go%d', primaryMethod, goScenario);
saveTOARfigure(fig1, basename1, figDir, 'dpi', 300);
close(fig1);

%% ================================================================
%% FIGURE 2: Chronological time series
%% Two stacked panels: RMSE (top), R² (bottom)
%% ================================================================

metrics_ts      = {'RMSE', 'R2'};
metricLabels_ts = {'RMSE (ppbv)', 'R²'};

fig2 = figure('Position', [100 100 1400 700], 'Visible', 'off');

for iMetric = 1:2
    ax = subplot(2, 1, iMetric);
    hold(ax, 'on');

    for iMethod = 1:nMethods
        T = allStats{iMethod};

        % Group by (Year, Month), average across folds
        uniqueYM  = unique([T.Year, T.Month], 'rows');   % sorted ascending
        nYM       = size(uniqueYM, 1);
        tDecimal  = NaN(nYM, 1);
        metricVals = NaN(nYM, 1);

        for k = 1:nYM
            yr = uniqueYM(k,1);  mo = uniqueYM(k,2);
            idx = (T.Year == yr) & (T.Month == mo);
            tDecimal(k)    = yr + (mo - 0.5) / 12;
            metricVals(k)  = mean(T.(metrics_ts{iMetric})(idx), 'omitnan');
        end

        plot(ax, tDecimal, metricVals, '-', 'Color', colors(iMethod,:), ...
            'LineWidth', 1.5, 'DisplayName', methodNames{iMethod});
    end

    xlabel(ax, 'Year');
    ylabel(ax, metricLabels_ts{iMetric});
    title(ax, sprintf('%s — Monthly Time Series', metricLabels_ts{iMetric}));
    legend(ax, 'Location', 'best', 'Interpreter', 'none');
    grid(ax, 'on');
end

sgtitle(fig2, sprintf('Monthly CBV Performance Over Time — GO%d', goScenario));

basename2 = sprintf('CBV_monthly_timeseries_BME%s_go%d', primaryMethod, goScenario);
saveTOARfigure(fig2, basename2, figDir, 'dpi', 300);
close(fig2);

%% ================================================================
%% FIGURE 3: Model comparison — grouped bars per calendar month
%% Only produced when nMethods >= 2
%% ================================================================

if nMethods < 2
    fprintf('plotCBVmonthly: skipping model comparison figure (single method).\n');
    fprintf('plotCBVmonthly: figures saved to %s\n', figDir);
    return;
end

metrics_comp      = {'RMSE', 'NMB'};
metricLabels_comp = {'RMSE (ppbv)', 'NMB (%)'};

fig3 = figure('Position', [100 100 1400 600], 'Visible', 'off');

for iMetric = 1:2
    ax = subplot(1, 2, iMetric);
    hold(ax, 'on');

    % Build [12 x nMethods] matrix of seasonal means
    barData = NaN(12, nMethods);
    for iMethod = 1:nMethods
        [mu, ~] = monthlySeasonalStats(allStats{iMethod}, metrics_comp{iMetric});
        barData(:, iMethod) = mu;
    end

    hb = bar(ax, 1:12, barData, 'grouped');
    for iMethod = 1:nMethods
        hb(iMethod).FaceColor = colors(iMethod,:);
        hb(iMethod).DisplayName = methodNames{iMethod};
    end

    % Reference line for NMB
    if strcmp(metrics_comp{iMetric}, 'NMB')
        yline(0, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
    end

    set(ax, 'XTick', 1:12, 'XTickLabel', monthAbbr);
    xlabel(ax, 'Month');
    ylabel(ax, metricLabels_comp{iMetric});
    title(ax, metricLabels_comp{iMetric});
    legend(ax, 'Location', 'best', 'Interpreter', 'none');
    grid(ax, 'on');
end

sgtitle(fig3, sprintf('Model Comparison by Calendar Month — GO%d', goScenario));

basename3 = sprintf('CBV_monthly_modelcomp_BME%s_go%d', primaryMethod, goScenario);
saveTOARfigure(fig3, basename3, figDir, 'dpi', 300);
close(fig3);

fprintf('plotCBVmonthly: all figures saved to %s\n', figDir);

end  % main function


%% ================================================================
%% Local helper
%% ================================================================
function [mu, sg] = monthlySeasonalStats(T, metric)
% monthlySeasonalStats  Average a metric by calendar month.
%
% Returns [12x1] vectors: mu = mean, sg = std
% Averages over all rows sharing the same Month value (across years and folds).

mu = NaN(12, 1);
sg = NaN(12, 1);

for m = 1:12
    vals = T.(metric)(T.Month == m);
    vals = vals(isfinite(vals));
    if numel(vals) >= 2
        mu(m) = mean(vals);
        sg(m) = std(vals);
    elseif numel(vals) == 1
        mu(m) = vals;
        sg(m) = 0;
    end
end

end
