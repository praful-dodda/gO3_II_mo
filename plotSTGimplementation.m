function plotSTGimplementation(overrides)
% plotSTGimplementation.m - Illustrative (schematic) figures of the novel
% Space-Time-Grid (STG) BME neighbor-search IMPLEMENTATION, contrasted with the
% original Space-Time-Vector (STV) neighbor search (Serre et al.; Abbott et al.).
%
% These figures explain the METHOD/implementation only (NOT benchmark results),
% using a small synthetic toy grid so the diagrams are readable.
%
% Produces (in paper-3-figures/stg_defense):
%   (1) DATA FORMAT     - STV (flattened, n independent entries) vs
%                         STG (nMS x nME grid with missingness)
%   (2) NEIGHBOR SEARCH - on the space-time plane:
%         STV: distance to ALL n points -> sort ~n -> nmaxneighb
%         STG: nMS spatial + nME temporal distances (reused via dimensional
%              separation) -> adaptive candidate box -> sort small set -> nmaxneighb
%   (3) COST SCHEMATIC  - algorithmic operation counts for the toy grid
%                         (illustrates where the speedup comes from)
%
% USAGE (from repo root):
%   plotSTGimplementation

close all;

%% ---- Config -------------------------------------------------------
if nargin < 1 || isempty(overrides); overrides = struct(); end
cfg.nMS = 12; cfg.nME = 8; cfg.missing = 0.15;
cfg.est = [6.2 5.4];          % estimation point [space(1-D), time]
cfg.stmetric = 1.0;            % combined dist = |ds| + stmetric*|dt|
cfg.nmaxneighb = 6;
cfg.seed = 3;
cfg.outDir = fullfile('paper-3-figures','stg_defense');
for fn = fieldnames(overrides)'; cfg.(fn{1}) = overrides.(fn{1}); end
if ~exist(cfg.outDir,'dir'); mkdir(cfg.outDir); end

rng(cfg.seed);
sStations = sort(linspace(0.5, 11.5, cfg.nMS) + 0.20*randn(1,cfg.nMS));
tEvents   = 1:cfg.nME;
mask      = rand(cfg.nMS, cfg.nME) > cfg.missing;     % true = observed
[I,J] = find(mask);
P = [sStations(I).', tEvents(J).'];                    % valid (space,time) points
n = size(P,1);
missFrac = 1 - n/(cfg.nMS*cfg.nME);

% STG neighbor selection (consistent with the text)
d = abs(P(:,1)-cfg.est(1)) + cfg.stmetric*abs(P(:,2)-cfg.est(2));
[~,ord] = sort(d); sel = ord(1:min(cfg.nmaxneighb,n));
dSpatialMax = max(abs(P(sel,1)-cfg.est(1)));
timeWin     = dSpatialMax / cfg.stmetric;
candMask = abs(P(:,1)-cfg.est(1)) <= dSpatialMax+1e-9 & abs(P(:,2)-cfg.est(2)) <= timeWin+1e-9;
selMask = false(n,1); selMask(sel) = true;

cap = 'Illustrative schematic — synthetic toy grid';
col.obs=[0.30 0.55 0.90]; col.miss=[0.90 0.90 0.90]; col.est=[0.90 0.20 0.15];
col.cand=[1.00 0.85 0.45]; col.sel=[0.10 0.65 0.30];

fprintf('\n=== STG implementation figures (toy grid nMS=%d nME=%d, n=%d) -> %s ===\n', ...
    cfg.nMS, cfg.nME, n, cfg.outDir);

%% ====================================================================
%   (1) Data format: STV vs STG
% ====================================================================
fSTV = @(ax) drawSTVcloud(ax, P, cfg.est, n, col);
fSTG = @(ax) drawSTGgrid(ax, mask, missFrac, cfg.nMS, cfg.nME, col);

saveOne(fSTV, fullfile(cfg.outDir,'stg_dataformat_stv.png'), [620 560]);
saveOne(fSTG, fullfile(cfg.outDir,'stg_dataformat_stg.png'), [680 560]);
f = figure('Color','w','Position',[50 60 1320 600]);
tl = tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
title(tl,'Data representation: Space-Time Vector (STV) vs Space-Time Grid (STG)','FontWeight','bold','FontSize',14);
subtitle(tl, cap, 'FontAngle','italic');
fSTV(nexttile(tl)); fSTG(nexttile(tl));
exportgraphics(f, fullfile(cfg.outDir,'stg_dataformat_combined.png'),'Resolution',200); close(f);
fprintf('  saved data-format figures\n');

%% ====================================================================
%   (2) Neighbor search: STV brute-force vs STG dimensional separation
% ====================================================================
gSTV = @(ax) drawNeighborSTV(ax, P, cfg.est, n, col);
gSTG = @(ax) drawNeighborSTG(ax, P, sStations, tEvents, cfg.est, ...
                             candMask, selMask, dSpatialMax, timeWin, cfg, col);

saveOne(gSTV, fullfile(cfg.outDir,'stg_neighbor_stv.png'), [640 600]);
saveOne(gSTG, fullfile(cfg.outDir,'stg_neighbor_stg.png'), [720 600]);
f = figure('Color','w','Position',[40 50 1420 640]);
tl = tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
title(tl,'Neighbor selection on the space-time plane: STV vs STG','FontWeight','bold','FontSize',14);
subtitle(tl, cap, 'FontAngle','italic');
gSTV(nexttile(tl)); gSTG(nexttile(tl));
exportgraphics(f, fullfile(cfg.outDir,'stg_neighbor_combined.png'),'Resolution',200); close(f);
fprintf('  saved neighbor-search figures\n');

%% ====================================================================
%   (3) Cost schematic (algorithmic operation counts for the toy grid)
% ====================================================================
f = figure('Color','w','Position',[80 80 980 460]);
tl = tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
title(tl,'Where the STG speedup comes from (algorithmic operation count)','FontWeight','bold','FontSize',13);
subtitle(tl, cap, 'FontAngle','italic');

ax = nexttile(tl);
cats = categorical({'Distance calcs','Sort pool'}); cats = reordercats(cats,{'Distance calcs','Sort pool'});
stv = [2*n,            n];
stg = [cfg.nMS+cfg.nME, sum(candMask)];
b = bar(ax, cats, [stv; stg].'); b(1).FaceColor=[0.75 0.4 0.3]; b(2).FaceColor=[0.30 0.55 0.90];
legend(ax,{'STV','STG'},'Location','northeast'); grid(ax,'on');
ylabel(ax,'operations (toy grid)'); title(ax,'Per estimation point');
for k=1:2
    text(ax, k-0.15, stv(k), num2str(stv(k)),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',9);
    text(ax, k+0.15, stg(k), num2str(stg(k)),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',9);
end

ax = nexttile(tl); axis(ax,'off');
msg = {
 '\bfSTV\rm: distance to all n points  (n spatial + n temporal),'
 '       then sort \approx n candidates.'
 ''
 '\bfSTG\rm: distance to n_{MS} stations + n_{ME} events only'
 '       (each reused across the other dimension),'
 '       then sort a small adaptive candidate set.'
 ''
 'Distance-phase speedup \approx n_{ME}   when n_{MS} \gg \alpha n_{ME}'
 '                       \approx n_{MS}/\alpha when n_{MS} \ll \alpha n_{ME}'
 ''
 sprintf('Toy grid: n_{MS}=%d, n_{ME}=%d, missingness=%.0f%%, n=%d', ...
         cfg.nMS, cfg.nME, 100*missFrac, n)
 };
text(ax, 0.02, 0.95, msg, 'Units','normalized','VerticalAlignment','top','FontSize',11,'Interpreter','tex');

exportgraphics(f, fullfile(cfg.outDir,'stg_cost_schematic.png'),'Resolution',200); close(f);
fprintf('  saved cost schematic\n');

fprintf('\n=== DONE. Figures in %s ===\n', cfg.outDir);

end  % main


%% ====================================================================
%   LOCAL HELPERS
% ====================================================================

function saveOne(drawFcn, pth, sz)
    f = figure('Color','w','Position',[100 100 sz],'Visible','off');
    drawFcn(axes(f)); %#ok<LAXES>
    exportgraphics(f, pth, 'Resolution', 200); close(f);
end

function drawSTVcloud(ax, P, est, n, col)
    hold(ax,'on');
    scatter(ax, P(:,1), P(:,2), 34, [0.55 0.55 0.55], 'filled', 'MarkerFaceAlpha',0.85);
    scatter(ax, est(1), est(2), 170, col.est, 'p', 'filled', 'MarkerEdgeColor','k');
    box(ax,'on'); grid(ax,'on');
    xlabel(ax,'Space (1-D illustration)'); ylabel(ax,'Time (event)');
    title(ax, sprintf('STV: %d independent space/time entries', n));
    text(ax,0.5,-0.16,'each (lon, lat, t, z) stored separately — grid structure not represented', ...
        'Units','normalized','HorizontalAlignment','center','FontAngle','italic','FontSize',9);
    hL = scatter(ax,nan,nan,30,[0.55 0.55 0.55],'filled');
    hE = scatter(ax,nan,nan,120,col.est,'p','filled','MarkerEdgeColor','k');
    legend(ax,[hL hE],{'observation','estimation point'},'Location','northwest');
    hold(ax,'off');
end

function drawSTGgrid(ax, mask, missFrac, nMS, nME, col)
    hold(ax,'on');
    for i = 1:nMS
        for j = 1:nME
            if mask(i,j); fc = col.obs; else; fc = col.miss; end
            rectangle(ax,'Position',[j-0.5 i-0.5 1 1],'FaceColor',fc,'EdgeColor','w','LineWidth',1);
            if ~mask(i,j)
                plot(ax, j, i, 'x', 'Color',[0.6 0.6 0.6], 'MarkerSize',7, 'LineWidth',1.2);
            end
        end
    end
    set(ax,'YDir','reverse'); axis(ax,[0.5 nME+0.5 0.5 nMS+0.5]);
    xticks(ax,1:nME); yticks(ax,1:nMS);
    xlabel(ax,'Measurement events  (n_{ME})'); ylabel(ax,'Monitoring stations  (n_{MS})');
    title(ax, sprintf('STG: %d \\times %d grid,  missingness = %.0f%%', nMS, nME, 100*missFrac));
    hO = patch(ax,nan,nan,col.obs); hM = patch(ax,nan,nan,col.miss);
    legend(ax,[hO hM],{'observed','missing (NaN)'},'Location','eastoutside');
    box(ax,'on');
    hold(ax,'off');
end

function drawNeighborSTV(ax, P, est, n, col)
    hold(ax,'on');
    % distance lines to ALL points (the cost)
    for k = 1:n
        plot(ax, [est(1) P(k,1)], [est(2) P(k,2)], '-', 'Color',[0.7 0.7 0.7 0.5], 'LineWidth',0.4);
    end
    scatter(ax, P(:,1), P(:,2), 34, [0.45 0.45 0.45], 'filled');
    scatter(ax, est(1), est(2), 180, col.est, 'p', 'filled', 'MarkerEdgeColor','k');
    box(ax,'on'); grid(ax,'on');
    xlabel(ax,'Space (1-D illustration)'); ylabel(ax,'Time (event)');
    title(ax,'STV neighbor search (brute force)');
    text(ax, 0.02, 0.98, sprintf(['Step 1: distance to ALL n points\n          (n spatial + n temporal)\n' ...
        'Step 2: sort \\approx n candidates \\rightarrow n_{maxneighb}']), ...
        'Units','normalized','VerticalAlignment','top','BackgroundColor',[1 1 1 0.8], ...
        'EdgeColor',[.5 .5 .5],'Margin',4,'FontSize',9,'Interpreter','tex');
    hold(ax,'off');
end

function drawNeighborSTG(ax, P, sStations, tEvents, est, candMask, selMask, dSpatialMax, timeWin, cfg, col)
    hold(ax,'on');
    xl = [0 12]; yl = [0.2 cfg.nME+0.8];
    % adaptive candidate box
    rectangle(ax,'Position',[est(1)-dSpatialMax, est(2)-timeWin, 2*dSpatialMax, 2*timeWin], ...
        'FaceColor',[col.cand 0.30],'EdgeColor',[0.85 0.6 0.1],'LineStyle','--','LineWidth',1.2);
    % all points, candidates, selected
    scatter(ax, P(:,1), P(:,2), 30, [0.7 0.7 0.7], 'filled');
    scatter(ax, P(candMask,1), P(candMask,2), 36, [0.5 0.5 0.5], 'filled');
    scatter(ax, P(selMask,1),  P(selMask,2),  60, col.sel, 'filled', 'MarkerEdgeColor','k');
    % station axis (nMS) along bottom, event axis (nME) along left
    yb = yl(1)+0.15; xb = xl(1)+0.25;
    scatter(ax, sStations, repmat(yb,1,cfg.nMS), 26, 'k', '^', 'filled');
    scatter(ax, repmat(xb,1,cfg.nME), tEvents, 26, 'k', '>', 'filled');
    % example reused-distance arrows
    [~,ks] = sort(abs(sStations-est(1))); ks = ks(2);
    plot(ax,[est(1) sStations(ks)],[est(2) est(2)],'-','Color',[0.2 0.2 0.6],'LineWidth',1.5);
    plot(ax,[est(1) est(1)],[est(2) tEvents(end)],'-','Color',[0.6 0.2 0.2],'LineWidth',1.5);
    scatter(ax, est(1), est(2), 180, col.est, 'p', 'filled', 'MarkerEdgeColor','k');
    axis(ax,[xl yl]); box(ax,'on'); grid(ax,'on');
    xlabel(ax,'Space (1-D illustration)'); ylabel(ax,'Time (event)');
    title(ax,'STG neighbor search (dimensional separation)');
    text(ax, 0.02, 0.98, sprintf(['Step 1: n_{MS} spatial + n_{ME} temporal distances\n' ...
        '          (each reused across the other axis)\n' ...
        'Step 2: adaptive candidate box \\rightarrow sort small set']), ...
        'Units','normalized','VerticalAlignment','top','BackgroundColor',[1 1 1 0.8], ...
        'EdgeColor',[.5 .5 .5],'Margin',4,'FontSize',9,'Interpreter','tex');
    % legend
    hC = patch(ax,nan,nan,col.cand); hS = scatter(ax,nan,nan,50,col.sel,'filled','MarkerEdgeColor','k');
    hT = scatter(ax,nan,nan,26,'k','^','filled'); hV = scatter(ax,nan,nan,26,'k','>','filled');
    legend(ax,[hC hS hT hV], {'candidate box','selected n_{maxneighb}','stations (n_{MS})','events (n_{ME})'}, ...
        'Location','southoutside','Orientation','horizontal');
    hold(ax,'off');
end
