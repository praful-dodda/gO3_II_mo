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
%   Figure 1 — Seasonal cycle:       CBV_monthly_seasonal_BME[method]_go[scenario].png
%   Figure 2 — Time series:          CBV_monthly_timeseries_BME[method]_go[scenario].png
%   Figures 3-6 only when nMethods >= 2:
%   Figure 3 — Model comparison:     CBV_monthly_modelcomp_BME[method]_go[scenario].png
%   Figure 4 — Delta vs baseline:    CBV_monthly_delta_BME[method]_go[scenario].png
%   Figure 5 — Winner by month:      CBV_monthly_winner_BME[method]_go[scenario].png
%   Figure 6 — Temporal stability:   CBV_monthly_stability_BME[method]_go[scenario].png
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
    fprintf('plotCBVmonthly: single method — Figures 1-2 saved to %s\n', figDir);
else

%% ================================================================
%% FIGURE 3: Grouped bars — RMSE and NMB per calendar month
%% ================================================================

metrics_comp      = {'RMSE', 'NMB'};
metricLabels_comp = {'RMSE (ppbv)', 'NMB (%)'};

fig3 = figure('Position', [100 100 1400 600], 'Visible', 'off');

for iMetric = 1:2
    ax = subplot(1, 2, iMetric);
    hold(ax, 'on');

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

%% ================================================================
%% FIGURE 4: Incremental improvement vs. baseline (Method 1)
%% Mirrors plotSoftDataContribution waterfall at monthly resolution
%% ================================================================
% Positive Δ R² = improvement; negative Δ RMSE = improvement

[mu_base_R2,   sg_base_R2]   = monthlySeasonalStats(allStats{1}, 'R2');
[mu_base_RMSE, sg_base_RMSE] = monthlySeasonalStats(allStats{1}, 'RMSE');

fig4 = figure('Position', [100 100 1200 700], 'Visible', 'off');

delta_metrics = {'R2',   'RMSE'};
delta_labels  = {'Δ R²', 'Δ RMSE (ppbv)'};
base_mu       = {mu_base_R2,   mu_base_RMSE};
base_sg       = {sg_base_R2,   sg_base_RMSE};
improve_sign  = [1, -1];   % +1: higher=better; -1: lower=better

for iMetric = 1:2
    ax = subplot(2, 1, iMetric);
    hold(ax, 'on');

    for iMethod = 2:nMethods
        [mu_m, sg_m] = monthlySeasonalStats(allStats{iMethod}, delta_metrics{iMetric});

        delta_mu = (mu_m - base_mu{iMetric}) * improve_sign(iMetric);
        delta_sg = sqrt(sg_m.^2 + base_sg{iMetric}.^2);   % propagated uncertainty

        xv = (1:12)';
        validBand = isfinite(delta_mu) & isfinite(delta_sg);
        if any(validBand)
            xFill = [xv(validBand); flipud(xv(validBand))];
            yFill = [delta_mu(validBand) + delta_sg(validBand); ...
                     flipud(delta_mu(validBand) - delta_sg(validBand))];
            fill(ax, xFill, yFill, colors(iMethod,:), ...
                'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
        plot(ax, xv, delta_mu, '-o', 'Color', colors(iMethod,:), ...
            'LineWidth', 2, 'MarkerSize', 6, ...
            'DisplayName', sprintf('%s vs baseline', methodNames{iMethod}));
    end

    yline(0, 'k--', 'LineWidth', 1.5, 'HandleVisibility', 'off');
    set(ax, 'XTick', 1:12, 'XTickLabel', monthAbbr, 'XLim', [0.5 12.5]);
    xlabel(ax, 'Month');
    ylabel(ax, delta_labels{iMetric});
    title(ax, delta_labels{iMetric});
    legend(ax, 'Location', 'best', 'Interpreter', 'none');
    grid(ax, 'on');
end

sgtitle(fig4, sprintf('Improvement Over Baseline (%s) by Month — GO%d (shading = \\pm1 std)', ...
    methodNames{1}, goScenario));

basename4 = sprintf('CBV_monthly_delta_BME%s_go%d', primaryMethod, goScenario);
saveTOARfigure(fig4, basename4, figDir, 'dpi', 300);
close(fig4);

%% ================================================================
%% FIGURE 5: Winner-by-month heatmap
%% Mirrors plotTemporalTrends winner analysis at monthly resolution
%% Rows = metrics, Columns = Jan-Dec, cell = winning method
%% ================================================================

metrics_win        = {'R2',  'RMSE', 'MAE', 'NMB'};
metricLabels_win   = {'R²',  'RMSE', 'MAE', 'NMB'};
higherIsBetter_win = [true, false, false, false];

winnerMat = NaN(4, 12);
for iMetric = 1:4
    for m = 1:12
        muVals = NaN(nMethods, 1);
        for iMethod = 1:nMethods
            [mu_all, ~] = monthlySeasonalStats(allStats{iMethod}, metrics_win{iMetric});
            muVals(iMethod) = mu_all(m);
        end
        if all(isnan(muVals)), continue; end
        if higherIsBetter_win(iMetric)
            [~, winnerMat(iMetric, m)] = max(muVals);
        else
            [~, winnerMat(iMetric, m)] = min(muVals);
        end
    end
end

fig5 = figure('Position', [100 100 1200 400], 'Visible', 'off');
ax5  = axes(fig5);
hold(ax5, 'on');

for iMetric = 1:4
    for m = 1:12
        w = winnerMat(iMetric, m);
        if isnan(w), continue; end
        rectangle(ax5, 'Position', [m-0.5, iMetric-0.5, 1, 1], ...
            'FaceColor', colors(w,:), 'EdgeColor', 'w', 'LineWidth', 1.5);
        % Short label (first 10 chars)
        label = methodNames{w};
        if length(label) > 10, label = label(1:10); end
        text(ax5, m, iMetric, label, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', 7, 'FontWeight', 'bold', 'Color', 'w');
    end
end

set(ax5, 'XTick', 1:12, 'XTickLabel', monthAbbr, ...
         'YTick', 1:4,  'YTickLabel', metricLabels_win, ...
         'XLim', [0.5 12.5], 'YLim', [0.5 4.5]);
xlabel(ax5, 'Month');
ylabel(ax5, 'Metric');
title(ax5, sprintf('Winner by Month and Metric — GO%d  (color = winning method)', goScenario));

% Legend entries
for iMethod = 1:nMethods
    patch(ax5, NaN, NaN, colors(iMethod,:), 'DisplayName', methodNames{iMethod});
end
legend(ax5, 'Location', 'bestoutside', 'Interpreter', 'none');

basename5 = sprintf('CBV_monthly_winner_BME%s_go%d', primaryMethod, goScenario);
saveTOARfigure(fig5, basename5, figDir, 'dpi', 300);
close(fig5);

%% ================================================================
%% FIGURE 6: Temporal stability — CV and std of RMSE by month
%% Mirrors plotTemporalTrends CV figure at monthly resolution
%% Lower CV = more stable performance year-to-year for that month
%% ================================================================

fig6 = figure('Position', [100 100 1200 500], 'Visible', 'off');
ax6L = subplot(1, 2, 1);
ax6R = subplot(1, 2, 2);
hold(ax6L, 'on');
hold(ax6R, 'on');

for iMethod = 1:nMethods
    T = allStats{iMethod};

    mu_rmse = NaN(12, 1);
    sg_rmse = NaN(12, 1);
    cv_rmse = NaN(12, 1);
    for m = 1:12
        vals = T.RMSE(T.Month == m);
        vals = vals(isfinite(vals));
        if numel(vals) >= 2
            mu_rmse(m) = mean(vals);
            sg_rmse(m) = std(vals);
            cv_rmse(m) = sg_rmse(m) / mu_rmse(m);
        end
    end

    plot(ax6L, 1:12, cv_rmse, '-o', 'Color', colors(iMethod,:), ...
        'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', methodNames{iMethod});
    plot(ax6R, 1:12, sg_rmse, '-o', 'Color', colors(iMethod,:), ...
        'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', methodNames{iMethod});
end

set(ax6L, 'XTick', 1:12, 'XTickLabel', monthAbbr, 'XLim', [0.5 12.5]);
xlabel(ax6L, 'Month');
ylabel(ax6L, 'CV of RMSE (std / mean)');
title(ax6L, 'Temporal Stability — CV of RMSE');
legend(ax6L, 'Location', 'best', 'Interpreter', 'none');
grid(ax6L, 'on');

set(ax6R, 'XTick', 1:12, 'XTickLabel', monthAbbr, 'XLim', [0.5 12.5]);
xlabel(ax6R, 'Month');
ylabel(ax6R, 'Std of RMSE (ppbv)');
title(ax6R, 'Temporal Stability — Absolute Std');
legend(ax6R, 'Location', 'best', 'Interpreter', 'none');
grid(ax6R, 'on');

sgtitle(fig6, sprintf('Year-to-Year RMSE Stability by Month — GO%d  (lower = more stable)', goScenario));

basename6 = sprintf('CBV_monthly_stability_BME%s_go%d', primaryMethod, goScenario);
saveTOARfigure(fig6, basename6, figDir, 'dpi', 300);
close(fig6);

fprintf('plotCBVmonthly: all 6 figures saved to %s\n', figDir);

end  % if nMethods >= 2

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
