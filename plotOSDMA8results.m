function figPaths = plotOSDMA8results(pooled, osdma8Stats, cfg)
% plotOSDMA8results - Diagnostic plots for OSDMA8 validation
%
% Produces three figures (mirroring the CBV Phase-1 style):
%   1. Reference-vs-test OSDMA8 scatter, one panel per box size (1:1 line,
%      R2/RMSE/N annotation)
%   2. Metrics (R2, RMSE, NMB, N) vs box size
%   3. Regional R2 heatmap (region x box size)
%
% INPUTS:
%   pooled      - struct with column vectors: ref, test, lon, lat, box, fold, year
%   osdma8Stats - summary table from runOSDMA8validation
%   cfg         - config struct (uses BMEmethod, goScenario, refSource,
%                 testSource, outDir)
%
% OUTPUT:
%   figPaths - cell array of saved figure paths
%
% SEE ALSO: runOSDMA8validation, saveTOARfigure, assignRegions

figPaths = {};
saveDir = fullfile(cfg.outDir, 'figs');
base = sprintf('BME%s_go%d', cfg.BMEmethod, cfg.goScenario);
refLab  = sprintf('OSDMA8 %s (ppb)', strrep(cfg.refSource, '_', '\_'));
testLab = sprintf('OSDMA8 %s (ppb)', strrep(cfg.testSource, '_', '\_'));

% Year range covered by this run (for clear labelling).
yrs = unique(pooled.year(:)).';
if isscalar(yrs)
    yrLabel = sprintf('%d', yrs);
else
    yrLabel = sprintf('%d-%d (grouped, %d yrs)', min(yrs), max(yrs), numel(yrs));
end

boxes = unique(pooled.box);
nB = numel(boxes);

%% Figure 1: scatter per box size (pooled over folds & years)
nCol = min(nB, 3); nRow = ceil(nB/nCol);
fig1 = figure('Visible', 'off', ...
    'Position', [100 100 max(640, 430*nCol) 200+400*nRow]);
for ib = 1:nB
    m = pooled.box == boxes(ib);
    r = pooled.ref(m); t = pooled.test(m);
    subplot(nRow, nCol, ib); hold on;

    scatter(r, t, 12, [0.2 0.4 0.8], 'filled', 'MarkerFaceAlpha', 0.3);
    lo = min([r; t]); hi = max([r; t]);
    if ~isempty(lo) && isfinite(lo)
        plot([lo hi], [lo hi], 'k--', 'LineWidth', 1.5);
        xlim([lo hi]); ylim([lo hi]);
    end
    axis square; grid on;

    R2 = NaN; RMSE = NaN; N = numel(r);
    if N >= 2
        cc = corrcoef(r, t); R2 = cc(1,2)^2;
        RMSE = sqrt(mean((t - r).^2));
    end
    text(0.05, 0.95, sprintf('R^2 = %.3f\nRMSE = %.2f ppb\nN = %d', R2, RMSE, N), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 9, ...
        'BackgroundColor', 'w', 'EdgeColor', 'k');
    xlabel(refLab); ylabel(testLab);
    title(sprintf('Box %.1f%c  |  %s', boxes(ib), char(176), yrLabel), 'FontSize', 10);
end
sgtitle({sprintf('OSDMA8 validation: %s vs %s', ...
            strrep(cfg.refSource,'_','\_'), strrep(cfg.testSource,'_','\_')), ...
         sprintf('%s  |  years %s  |  completeness: %s', ...
            strrep(base,'_','\_'), yrLabel, cfg.completeness)}, ...
         'FontSize', 11);
figPaths{end+1} = saveTOARfigure(fig1, ['OSDMA8_scatter_' base], saveDir, 'dpi', 300);
close(fig1);

%% Figure 2: metrics vs box size (averaged over folds/years)
metrics = {'R2','RMSE','NMB','N'};
fig2 = figure('Visible', 'off', 'Position', [100 100 900 700]);
for k = 1:4
    mname = metrics{k};
    subplot(2,2,k); hold on; grid on;
    if ismember(mname, osdma8Stats.Properties.VariableNames)
        mv = nan(nB,1);
        for ib = 1:nB
            sel = osdma8Stats.BoxSize == boxes(ib);
            mv(ib) = mean(osdma8Stats.(mname)(sel), 'omitnan');
        end
        plot(boxes, mv, '-o', 'LineWidth', 1.5, 'MarkerFaceColor', [0.2 0.4 0.8]);
        if strcmp(mname, 'NMB'), yline(0, 'k--'); end
    end
    xlabel(sprintf('Box size (%c)', char(176))); ylabel(mname);
    title(mname);
end
sgtitle(sprintf('OSDMA8 metrics vs box size  |  %s  |  years %s', ...
    strrep(base,'_','\_'), yrLabel), 'FontSize', 11);
figPaths{end+1} = saveTOARfigure(fig2, ['OSDMA8_metrics_by_box_' base], saveDir, 'dpi', 300);
close(fig2);

%% Figure 3: regional R2 heatmap (region x box)
regs = assignRegions(pooled.lon, pooled.lat);
uReg = unique(regs, 'stable');
R2map = nan(numel(uReg), nB);
Nmap  = zeros(numel(uReg), nB);
for ir = 1:numel(uReg)
    for ib = 1:nB
        m = strcmp(regs, uReg{ir}) & (pooled.box == boxes(ib));
        r = pooled.ref(m); t = pooled.test(m);
        Nmap(ir,ib) = numel(r);
        if numel(r) >= 2
            cc = corrcoef(r, t); R2map(ir,ib) = cc(1,2)^2;
        end
    end
end

fig3 = figure('Visible', 'off', 'Position', [100 100 200+120*nB 120+40*numel(uReg)]);
imagesc(R2map, 'AlphaData', ~isnan(R2map)); colorbar; caxis([0 1]);
set(gca, 'XTick', 1:nB, 'XTickLabel', compose('%.1f', boxes), ...
    'YTick', 1:numel(uReg), 'YTickLabel', uReg);
xlabel(sprintf('Box size (%c)', char(176))); ylabel('Region');
title(sprintf('OSDMA8 R^2 by region  |  %s  |  years %s', ...
    strrep(base,'_','\_'), yrLabel), 'FontSize', 11);
for ir = 1:numel(uReg)
    for ib = 1:nB
        if Nmap(ir,ib) > 0
            txt = sprintf('%.2f\n(n=%d)', R2map(ir,ib), Nmap(ir,ib));
            text(ib, ir, txt, 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', 'FontSize', 8);
        end
    end
end
figPaths{end+1} = saveTOARfigure(fig3, ['OSDMA8_regional_' base], saveDir, 'dpi', 300);
close(fig3);

fprintf('Saved %d OSDMA8 figures to %s\n', numel(figPaths), saveDir);
end
