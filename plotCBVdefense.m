function plotCBVdefense(overrides)
% plotCBVdefense.m - Defense-presentation visualizations of checker-board
% validation (CBV) contrasting a SMALL (5 deg) and LARGE (20 deg) hold-out box.
%
% Produces two complementary views, for box sizes 5 deg and 20 deg:
%   (A) SCHEME maps    - the checkerboard hold-out pattern over the TOAR-II
%                        station network (training vs validation), both folds.
%                        Method-independent (illustrates the validation design).
%   (B) PERFORMANCE     - actual obs-vs-predicted at held-out stations, pooled
%                        across folds + all available years, with metrics
%                        (R^2, RMSE, MAE, NMB, IOA, FAC2). Reads the saved CBV
%                        annual result files in 7validation/CBV.
%
% Reuses: getTOARobservationalData, getCheckerBoard (hold-out masks),
%   calculateValidationStats (pooled metrics), 1data/borderdata.mat (borders).
%
% USAGE (from repo root, BMELIB on path):
%   plotCBVdefense                                     % default = 13000313-06
%   plotCBVdefense(struct('method','10000133'))        % obs-only, etc.

close all;

%% ---- Config (defaults; override via struct arg) -------------------
if nargin < 1 || isempty(overrides); overrides = struct(); end
cfg.method     = '13000313-06';     % best-fusion (M3fusion + OMI-MLS)
cfg.go         = 3;
cfg.boxSizes   = [5 20];            % small vs large hold-out box (deg)
cfg.schemeYear = 2016;             % year whose station network illustrates the scheme
cfg.perfYears  = [];               % [] = all available years for this method/box
cfg.schemeRegion = [-180 180 -60 83];
cfg.outDir     = fullfile('paper-3-figures','CBV_defense');
for fn = fieldnames(overrides)'; cfg.(fn{1}) = overrides.(fn{1}); end

cfg.cbvDir = fullfile('7validation','CBV');
if ~exist(cfg.outDir,'dir'); mkdir(cfg.outDir); end
cfg.base = sprintf('%s_go%d', cfg.method, cfg.go);

trainCol = [0.20 0.45 0.95];   trainBox = [0.80 0.88 1.00];
valCol   = [0.90 0.30 0.15];   valBox   = [1.00 0.86 0.72];

fprintf('\n=== CBV defense figures: method %s, go %d, boxes %s ===\n', ...
    cfg.method, cfg.go, mat2str(cfg.boxSizes));

B = loadBorders();

%% ====================================================================
%   (A) Checkerboard SCHEME maps
% ====================================================================
fprintf('\n-- Scheme maps (station network %d) --\n', cfg.schemeYear);
obs = getTOARobservationalData('all', [cfg.schemeYear cfg.schemeYear], 0);
sMS = obs.sMS;

schemeHandles = containers.Map();   % key 'box_fold' -> draw fcn
for bs = cfg.boxSizes
    for fold = [1 2]
        [trMask, vaMask] = getCheckerBoard(sMS, bs, fold, 0);
        key = sprintf('b%g_f%d', bs, fold);
        schemeHandles(key) = @(ax) drawScheme(ax, sMS, trMask, vaMask, bs, fold, ...
            cfg.schemeRegion, B, trainCol, valCol, trainBox, valBox);
        % individual panel
        f = figure('Color','w','Position',[80 80 1100 620],'Visible','off');
        h = schemeHandles(key); h(axes(f)); %#ok<LAXES>
        pth = fullfile(cfg.outDir, sprintf('scheme_box%02d_fold%d_%s.png', bs, fold, cfg.base));
        exportgraphics(f, pth, 'Resolution', 200); close(f);
        fprintf('  saved %s\n', pth);
    end
end

% Combined 2x2: rows = box size, cols = fold
fc = figure('Color','w','Position',[40 40 1700 1000]);
tlc = tiledlayout(fc, numel(cfg.boxSizes), 2, 'TileSpacing','compact','Padding','compact');
title(tlc, sprintf('Checker-board validation hold-out pattern  (TOAR-II network, %d)', cfg.schemeYear), ...
    'FontWeight','bold','FontSize',14);
for bs = cfg.boxSizes
    for fold = [1 2]
        h = schemeHandles(sprintf('b%g_f%d', bs, fold)); h(nexttile(tlc));
    end
end
schemeCombined = fullfile(cfg.outDir, sprintf('scheme_combined_%s.png', cfg.base));
exportgraphics(fc, schemeCombined, 'Resolution', 200);
fprintf('  saved %s\n', schemeCombined);

%% ====================================================================
%   (B) Validation PERFORMANCE at 5 deg vs 20 deg
% ====================================================================
fprintf('\n-- Performance (reading %s) --\n', cfg.cbvDir);
perf = struct();         % perf(i): box, Yo, Ye, stats, nyears
axLim = [10 95];
for i = 1:numel(cfg.boxSizes)
    bs = cfg.boxSizes(i);
    [Yo, Ye, ny, yrs] = gatherCBV(cfg.cbvDir, cfg.method, cfg.go, bs, cfg.perfYears);
    if isempty(Yo)
        warning('No CBV result files for box %g deg (method %s). Skipping performance.', bs, cfg.method);
        perf(i).box = bs; perf(i).Yo = []; continue;
    end
    st = calculateValidationStats(Yo, Ye);
    perf(i).box = bs; perf(i).Yo = Yo; perf(i).Ye = Ye;
    perf(i).stats = st; perf(i).nyears = ny; perf(i).years = yrs;
    fprintf('  box %4.1f: N=%d, R2=%.3f, RMSE=%.2f, MAE=%.2f, NMB=%.1f%%  (%d years)\n', ...
        bs, st.N, st.R2, st.RMSE, st.MAE, st.NMB, ny);

    % individual scatter
    f = figure('Color','w','Position',[100 100 620 620],'Visible','off');
    drawPerfScatter(axes(f), Yo, Ye, st, bs, axLim); %#ok<LAXES>
    pth = fullfile(cfg.outDir, sprintf('perf_scatter_box%02d_%s.png', bs, cfg.base));
    exportgraphics(f, pth, 'Resolution', 200); close(f);
    fprintf('  saved %s\n', pth);
end

% Combined side-by-side scatter
have = find(arrayfun(@(p) ~isempty(p.Yo), perf));
if ~isempty(have)
    fp = figure('Color','w','Position',[60 60 560*numel(have) 600]);
    tlp = tiledlayout(fp,1,numel(have),'TileSpacing','compact','Padding','compact');
    title(tlp, sprintf('CBV held-out skill vs hold-out box size  |  %s', prettyMethod(cfg.method)), ...
        'FontWeight','bold','FontSize',14);
    for k = have
        drawPerfScatter(nexttile(tlp), perf(k).Yo, perf(k).Ye, perf(k).stats, perf(k).box, axLim);
    end
    perfCombined = fullfile(cfg.outDir, sprintf('perf_combined_%s.png', cfg.base));
    exportgraphics(fp, perfCombined, 'Resolution', 200);
    fprintf('  saved %s\n', perfCombined);

    % Metrics bar comparison (R2 & RMSE)
    fb = figure('Color','w','Position',[80 80 760 380]);
    tlb = tiledlayout(fb,1,2,'TileSpacing','compact','Padding','compact');
    boxes = arrayfun(@(p) p.box, perf(have));
    r2s   = arrayfun(@(p) p.stats.R2,   perf(have));
    rmses = arrayfun(@(p) p.stats.RMSE, perf(have));
    cats  = categorical(arrayfun(@(b) sprintf('%g°', b), boxes, 'UniformOutput', false));
    ax = nexttile(tlb); b1=bar(ax, cats, r2s, 0.5); b1.FaceColor=[0.2 0.5 0.8];
    ylabel(ax,'R^2'); title(ax,'R^2 vs box size'); grid(ax,'on'); ylim(ax,[0 1]);
    for j=1:numel(r2s); text(ax,j,r2s(j),sprintf('%.3f',r2s(j)),'HorizontalAlignment','center','VerticalAlignment','bottom'); end
    ax = nexttile(tlb); b2=bar(ax, cats, rmses, 0.5); b2.FaceColor=[0.85 0.4 0.3];
    ylabel(ax,'RMSE (ppb)'); title(ax,'RMSE vs box size'); grid(ax,'on');
    for j=1:numel(rmses); text(ax,j,rmses(j),sprintf('%.2f',rmses(j)),'HorizontalAlignment','center','VerticalAlignment','bottom'); end
    title(tlb, sprintf('Skill degradation with hold-out scale  |  %s', prettyMethod(cfg.method)),'FontWeight','bold');
    metricsBar = fullfile(cfg.outDir, sprintf('perf_metrics_bar_%s.png', cfg.base));
    exportgraphics(fb, metricsBar, 'Resolution', 200);
    fprintf('  saved %s\n', metricsBar);
end

fprintf('\n=== DONE. Figures in %s ===\n', cfg.outDir);

end  % main


%% ====================================================================
%   LOCAL HELPERS
% ====================================================================

function drawScheme(ax, sMS, trMask, vaMask, bs, fold, R, B, trainCol, valCol, trainBox, valBox)
    lon = sMS(:,1); lat = sMS(:,2);
    hold(ax,'on');
    % Checkerboard box fill (consistent parity with getCheckerBoard)
    lonRef = floor(min(lon)/bs)*bs; latRef = floor(min(lat)/bs)*bs;
    lonE = lonRef:bs:(max(lon)+bs);  latE = latRef:bs:(max(lat)+bs);
    [trV,trF,vaV,vaF] = checkerPatches(lonE, latE, fold);
    patch(ax,'Faces',trF,'Vertices',trV,'FaceColor',trainBox,'EdgeColor',[.7 .7 .7],'LineWidth',0.2,'FaceAlpha',0.85);
    patch(ax,'Faces',vaF,'Vertices',vaV,'FaceColor',valBox,  'EdgeColor',[.7 .7 .7],'LineWidth',0.2,'FaceAlpha',0.85);
    % Borders
    drawBorders(ax, B, [0.45 0.45 0.45]);
    % Stations
    scatter(ax, lon(trMask), lat(trMask), 6, trainCol, 'filled', 'MarkerFaceAlpha',0.7);
    scatter(ax, lon(vaMask), lat(vaMask), 6, valCol,   'filled', 'MarkerFaceAlpha',0.7);
    axis(ax, R); box(ax,'on'); set(ax,'Layer','top');
    daspect(ax,[1 1 1]);
    xlabel(ax,'Longitude'); ylabel(ax,'Latitude');
    title(ax, sprintf('Box %g°  |  Fold %d   (train %d / val %d)', ...
        bs, fold, sum(trMask), sum(vaMask)));
    % legend proxies
    hT = scatter(ax, nan, nan, 30, trainCol, 'filled');
    hV = scatter(ax, nan, nan, 30, valCol, 'filled');
    legend(ax, [hT hV], {'Training','Validation'}, 'Location','southwest');
    hold(ax,'off');
end

function [trV,trF,vaV,vaF] = checkerPatches(lonE, latE, fold)
% Build patch vertex/face lists for training and validation boxes.
    nC = numel(lonE)-1; nR = numel(latE)-1;
    trV = []; trF = []; vaV = []; vaF = [];
    for c = 1:nC
        for r = 1:nR
            isBlack = mod((c-1)+(r-1),2)==0;
            isTrain = (fold==1 && isBlack) || (fold==2 && ~isBlack);
            v = [lonE(c) latE(r); lonE(c+1) latE(r); lonE(c+1) latE(r+1); lonE(c) latE(r+1)];
            if isTrain
                trF(end+1,:) = size(trV,1) + (1:4); trV = [trV; v]; %#ok<AGROW>
            else
                vaF(end+1,:) = size(vaV,1) + (1:4); vaV = [vaV; v]; %#ok<AGROW>
            end
        end
    end
end

function drawPerfScatter(ax, Yo, Ye, st, bs, axLim)
    hold(ax,'on');
    if exist('binscatter','file')
        hb = binscatter(ax, Yo, Ye, [80 80]);
        ax.ColorScale = 'log'; colormap(ax, parula);
        cb = colorbar(ax); cb.Label.String = 'count';
    else
        scatter(ax, Yo, Ye, 4, 'filled', 'MarkerFaceAlpha', 0.04);
    end
    plot(ax, axLim, axLim, 'k-', 'LineWidth', 1.2);                 % 1:1
    xf = axLim; plot(ax, xf, st.Slope*xf + st.Intercept, 'r--', 'LineWidth', 1.2);  % regression
    axis(ax, [axLim axLim]); daspect(ax,[1 1 1]); box(ax,'on'); grid(ax,'on');
    xlabel(ax,'Observed MDA8 O_3 (ppb)'); ylabel(ax,'BME predicted (ppb)');
    title(ax, sprintf('Hold-out box %g°', bs));
    txt = sprintf(['N = %s\nR^2 = %.3f\nRMSE = %.2f ppb\nMAE = %.2f ppb\n' ...
                   'NMB = %.1f%%\nIOA = %.3f\nFAC2 = %.0f%%\nslope = %.2f'], ...
        addComma(st.N), st.R2, st.RMSE, st.MAE, st.NMB, st.IOA, st.FAC2, st.Slope);
    text(ax, 0.04, 0.96, txt, 'Units','normalized', 'VerticalAlignment','top', ...
        'BackgroundColor',[1 1 1 0.75], 'EdgeColor',[.5 .5 .5], 'Margin',4, 'FontSize',9);
    hold(ax,'off');
end

function [Yo, Ye, nYears, yrs] = gatherCBV(cbvDir, method, go, box, yearsWanted)
% Pool Y_obs / Y_est across folds (and years) from annual CBV result files.
    Yo = []; Ye = []; yrs = [];
    patt = sprintf('CBV_BME%s_go%d_box%.1f_fold*.mat', method, go, box);
    f = dir(fullfile(cbvDir, patt));
    rx = sprintf('^CBV_BME%s_go%d_box%.1f_fold(\\d+)_(\\d{4})\\.mat$', ...
        regexptranslate('escape',method), go, box);
    for i = 1:numel(f)
        tok = regexp(f(i).name, rx, 'tokens', 'once');   % excludes leak-tagged variants
        if isempty(tok); continue; end
        yr = str2double(tok{2});
        if ~isempty(yearsWanted) && ~ismember(yr, yearsWanted); continue; end
        S = load(fullfile(cbvDir, f(i).name), 'annualResults');
        if ~isfield(S,'annualResults'); continue; end
        Yo = [Yo; S.annualResults.Y_obs(:)]; %#ok<AGROW>
        Ye = [Ye; S.annualResults.Y_est(:)]; %#ok<AGROW>
        yrs = [yrs; yr]; %#ok<AGROW>
    end
    yrs = unique(yrs); nYears = numel(yrs);
end

function B = loadBorders()
    B = struct('ok',false,'lon',{{}},'lat',{{}});
    if exist(fullfile('1data','borderdata.mat'),'file')
        try
            bd = load(fullfile('1data','borderdata.mat'), 'lon','lat');
            B.ok = true; B.lon = bd.lon; B.lat = bd.lat;
        catch; end
    end
end

function drawBorders(ax, B, col)
    if ~B.ok; return; end
    for k = 1:numel(B.lon)
        if ~isempty(B.lon{k}); plot(ax, B.lon{k}, B.lat{k}, '-', 'Color', col, 'LineWidth', 0.3); end
    end
end

function s = prettyMethod(m)
    map = struct('x13000313_06','Obs + M3fusion + OMI-MLS', ...
                 'x13000313_02','Obs + M3fusion', 'x10000133','Observations only');
    key = ['x' strrep(m,'-','_')];
    if isfield(map,key); s = sprintf('%s (%s)', m, map.(key)); else; s = m; end
end

function s = addComma(n)
    s = regexprep(num2str(n), '(\d)(?=(\d{3})+$)', '$1,');
end
