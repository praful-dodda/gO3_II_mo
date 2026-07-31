function plotRCVdefense(overrides)
% plotRCVdefense.m - Defense/paper visualizations of RADIAL cross-validation (RCV)
% using DUMMY (synthetic) data to demonstrate the workflow and figure format.
%
% RCV (Abbott et al., 2025): each station's observations are held out and
% re-estimated from a training set lying OUTSIDE a radius r of that station.
% Increasing r removes ever-nearer data, probing each method's ability to
% estimate at increasing distance from monitors. Skill is the Pearson (pR) and
% Spearman (sR) correlation between held-out obs and re-estimates; pR/sR vs r
% are the "RCV curves" (here averaged over 2011-2016, band = inter-annual spread).
%
% Produces:
%   (A) SCHEME illustration - a target station with a growing exclusion disk;
%       training points outside, held-out points inside (synthetic network).
%   (B) RCV CURVES - dummy pR and sR vs radius for each method, mean +/- spread.
%
% NOTE: all numbers here are SYNTHETIC - this only demonstrates the process.
%
% USAGE (from repo root):
%   plotRCVdefense

close all;

%% ---- Config (defaults; override via struct arg) -------------------
if nargin < 1 || isempty(overrides); overrides = struct(); end
cfg.radii   = 0:0.5:10;                 % CV radius (degrees)
cfg.schemeRadii = [1 3 5];              % radii shown in the scheme panels (deg)
cfg.years   = 2011:2016;               % averaging period
cfg.outDir  = fullfile('paper-3-figures','rcv_defense');
cfg.seed    = 7;
% Dummy methods: name, color, and pR/sR decay params (pHi at r=0 -> pLo as r->inf, scale L)
cfg.methods = struct( ...
    'name',  {'BME (obs only)',        'Ordinary kriging'}, ...
    'color', {[0.20 0.45 0.95],        [0.90 0.45 0.10]}, ...
    'pHi',   {0.93,                     0.90}, ...
    'pLo',   {0.66,                     0.52}, ...
    'L',     {4.5,                      3.0});
for fn = fieldnames(overrides)'; cfg.(fn{1}) = overrides.(fn{1}); end
if ~exist(cfg.outDir,'dir'); mkdir(cfg.outDir); end

rng(cfg.seed);   % reproducible synthetic data
nM = numel(cfg.methods);
caption = 'Synthetic data — illustrates RCV workflow';

fprintf('\n=== RCV defense figures (DUMMY data) -> %s ===\n', cfg.outDir);

%% ====================================================================
%   (A) Scheme illustration: synthetic station network + growing radius
% ====================================================================
S = makeDummyNetwork(260);                  % Nx2 synthetic [lon lat] in [0 12]x[0 10]
[~, it] = min(sum((S - [6 5]).^2, 2));      % target station near centre
target = S(it,:);
dom = [min(S(:,1))-0.5 max(S(:,1))+0.5 min(S(:,2))-0.5 max(S(:,2))+0.5];

drawOne = @(ax,r) drawRCVscheme(ax, S, it, r, dom);

% individual scheme panels
for r = cfg.schemeRadii
    f = figure('Color','w','Position',[80 80 620 560],'Visible','off');
    drawOne(axes(f), r); %#ok<LAXES>
    pth = fullfile(cfg.outDir, sprintf('rcv_scheme_r%02d.png', r));
    exportgraphics(f, pth, 'Resolution', 200); close(f);
    fprintf('  saved %s\n', pth);
end

% combined 1 x N
f = figure('Color','w','Position',[40 60 560*numel(cfg.schemeRadii) 600]);
tl = tiledlayout(f,1,numel(cfg.schemeRadii),'TileSpacing','compact','Padding','compact');
title(tl, 'Radial cross-validation: held-out station with increasing exclusion radius', ...
    'FontWeight','bold','FontSize',14);
subtitle(tl, caption, 'FontAngle','italic');
for r = cfg.schemeRadii; drawOne(nexttile(tl), r); end
schemeCombined = fullfile(cfg.outDir, 'rcv_scheme_combined.png');
exportgraphics(f, schemeCombined, 'Resolution', 200); close(f);
fprintf('  saved %s\n', schemeCombined);

%% ====================================================================
%   (B) RCV curves: dummy pR and sR vs radius, mean +/- inter-annual spread
% ====================================================================
R = cfg.radii(:); nR = numel(R); nY = numel(cfg.years);
pR = cell(nM,1); sR = cell(nM,1);          % each: nY x nR
for m = 1:nM
    base = cfg.methods(m).pHi - (cfg.methods(m).pHi - cfg.methods(m).pLo) .* (1 - exp(-R/cfg.methods(m).L));
    pYears = zeros(nY,nR); sYears = zeros(nY,nR);
    for iy = 1:nY
        yrOff = 0.015*randn;                                   % per-year offset
        pYears(iy,:) = min(0.99, max(0.3, base' + yrOff + 0.008*randn(1,nR)));
        sYears(iy,:) = min(0.99, max(0.3, base' - 0.035 + yrOff + 0.010*randn(1,nR)));  % sR slightly below pR
    end
    pR{m} = pYears; sR{m} = sYears;
end

% individual curve figures
drawCurves(newAxFig(), R, pR, cfg.methods, 'Pearson correlation  p_R', caption);
pPng = fullfile(cfg.outDir,'rcv_curve_pR.png'); exportgraphics(gcf,pPng,'Resolution',200); close(gcf);
fprintf('  saved %s\n', pPng);

drawCurves(newAxFig(), R, sR, cfg.methods, 'Spearman rank correlation  s_R', caption);
sPng = fullfile(cfg.outDir,'rcv_curve_sR.png'); exportgraphics(gcf,sPng,'Resolution',200); close(gcf);
fprintf('  saved %s\n', sPng);

% combined pR | sR
fc = figure('Color','w','Position',[60 60 1180 520]);
tlc = tiledlayout(fc,1,2,'TileSpacing','compact','Padding','compact');
title(tlc, sprintf('RCV skill vs exclusion radius (averaged %d–%d)', cfg.years(1), cfg.years(end)), ...
    'FontWeight','bold','FontSize',14);
subtitle(tlc, caption, 'FontAngle','italic');
drawCurves(nexttile(tlc), R, pR, cfg.methods, 'Pearson correlation  p_R', '');
drawCurves(nexttile(tlc), R, sR, cfg.methods, 'Spearman rank correlation  s_R', '');
curvesCombined = fullfile(cfg.outDir,'rcv_curves_combined.png');
exportgraphics(fc, curvesCombined, 'Resolution', 200); close(fc);
fprintf('  saved %s\n', curvesCombined);

fprintf('\n=== DONE. Figures in %s ===\n', cfg.outDir);

end  % main


%% ====================================================================
%   LOCAL HELPERS
% ====================================================================

function S = makeDummyNetwork(n)
% Synthetic station coords: uniform background + two denser clusters.
    nb = round(0.6*n);
    bg = [rand(nb,1)*12, rand(nb,1)*10];
    c1 = [3 7] + 0.9*randn(round(0.22*n),2);
    c2 = [8.5 3.5] + 1.1*randn(n-nb-size(c1,1),2);
    S = [bg; c1; c2];
    S(:,1) = min(12, max(0, S(:,1)));
    S(:,2) = min(10, max(0, S(:,2)));
end

function drawRCVscheme(ax, S, it, r, dom)
    lon = S(:,1); lat = S(:,2); target = S(it,:);
    d = sqrt((lon-target(1)).^2 + (lat-target(2)).^2);
    excl = d <= r;  excl(it) = false;       % within radius (excluded from training)
    train = d > r;                           % training set (outside radius)
    hold(ax,'on');
    % exclusion disk
    th = linspace(0,2*pi,200);
    patch(ax, target(1)+r*cos(th), target(2)+r*sin(th), [0.85 0.85 0.85], ...
        'FaceAlpha',0.45,'EdgeColor',[0.4 0.4 0.4],'LineStyle','--','LineWidth',1.0);
    % points
    scatter(ax, lon(train), lat(train), 16, [0.20 0.45 0.95], 'filled', 'MarkerFaceAlpha',0.8);
    scatter(ax, lon(excl),  lat(excl),  16, [0.6 0.6 0.6], 'o');                 % excluded (hollow grey)
    scatter(ax, target(1), target(2), 160, [0.90 0.20 0.15], 'p', 'filled', 'MarkerEdgeColor','k');  % target
    axis(ax, dom); daspect(ax,[1 1 1]); box(ax,'on');
    xlabel(ax,'Longitude (°)'); ylabel(ax,'Latitude (°)');
    title(ax, sprintf('Exclusion radius = %g°   (n_{train} = %d)', r, sum(train)));
    % proxies for legend
    hT = scatter(ax,nan,nan,30,[0.20 0.45 0.95],'filled');
    hE = scatter(ax,nan,nan,30,[0.6 0.6 0.6],'o');
    hS = scatter(ax,nan,nan,120,[0.90 0.20 0.15],'p','filled','MarkerEdgeColor','k');
    legend(ax,[hS hE hT],{'Held-out station','Excluded (within r)','Training (outside r)'}, ...
        'Location','southoutside','Orientation','horizontal');
    hold(ax,'off');
end

function ax = newAxFig()
    f = figure('Color','w','Position',[100 100 620 520]); ax = axes(f);
end

function drawCurves(ax, R, data, methods, ylab, caption)
% data: cell{nM} each nY x nR. Plot mean over years with +/-1 std band.
    hold(ax,'on'); h = gobjects(numel(methods),1);
    for m = 1:numel(methods)
        Y = data{m}; mu = mean(Y,1); sd = std(Y,0,1); col = methods(m).color;
        patch(ax, [R; flipud(R)], [mu(:)-sd(:); flipud(mu(:)+sd(:))], col, ...
            'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
        h(m) = plot(ax, R, mu, '-o', 'Color', col, 'MarkerFaceColor', col, ...
            'LineWidth', 1.8, 'MarkerSize', 4);
    end
    grid(ax,'on'); box(ax,'on');
    xlabel(ax,'Cross-validation radius (°)'); ylabel(ax, ylab);
    xlim(ax,[min(R) max(R)]); ylim(ax,[0.4 1]);
    legend(ax, h, {methods.name}, 'Location','southwest');
    title(ax, ylab);
    if ~isempty(caption)
        text(ax, 0.98, 0.04, caption, 'Units','normalized', 'HorizontalAlignment','right', ...
            'FontAngle','italic', 'FontSize',8, 'Color',[0.4 0.4 0.4]);
    end
    hold(ax,'off');
end
