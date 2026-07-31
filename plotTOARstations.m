function plotTOARstations(overrides)
% plotTOARstations.m - Defense/paper visualization of the TOAR-II monitoring
% network: station LOCATIONS for a given year on a world map.
%
% Loads TOAR-II observational data (reuses getTOARobservationalData), keeps the
% stations that report at least one valid monthly MDA8 value in the target year,
% and plots them on a world map with country borders. Two figures:
%   (A) plain network map (all stations one color)         -> *_network.png
%   (B) stations colored by their annual-mean MDA8 ozone   -> *_meanO3.png
%
% USAGE (from repo root, BMELIB on path):
%   plotTOARstations                              % default: year 2015
%   plotTOARstations(struct('year',2018))

close all;

%% ---- Config (defaults; override via struct arg) -------------------
if nargin < 1 || isempty(overrides); overrides = struct(); end
cfg.year    = 2015;
cfg.dataDir = fullfile('.', '1data', 'TOAR-II');
cfg.borderFile = fullfile('.', '1data', 'borderdata.mat');
cfg.outDir  = 'paper-3-figures';
cfg.markerSize = 14;
for fn = fieldnames(overrides)'; cfg.(fn{1}) = overrides.(fn{1}); end
if ~exist(cfg.outDir, 'dir'); mkdir(cfg.outDir); end

fprintf('\n=== TOAR-II station map for %d -> %s ===\n', cfg.year, cfg.outDir);

%% ---- Load observations (cached) -----------------------------------
% Single-year window keeps it light; obs.Z is [nStation x nMonth].
obs = getTOARobservationalData('all', [cfg.year cfg.year]);

% Months belonging to the target year
yrMonths = floor(obs.tME) == cfg.year;
Zyr = obs.Z(:, yrMonths);

% Keep stations with >=1 valid monthly value in the year
hasData   = any(~isnan(Zyr), 2);
lon       = obs.sMS(hasData, 1);
lat       = obs.sMS(hasData, 2);
meanO3    = mean(Zyr(hasData, :), 2, 'omitnan');
nStations = numel(lon);
fprintf('  %d stations report valid data in %d (of %d total)\n', ...
    nStations, cfg.year, size(obs.Z,1));

%% ---- Country borders ----------------------------------------------
border = [];
if exist(cfg.borderFile, 'file')
    S = load(cfg.borderFile, 'places', 'lon', 'lat');
    for k = 1:numel(S.places)
        if ~isempty(S.lon{k})
            border = [border; [S.lon{k}(:), S.lat{k}(:)]; [NaN NaN]]; %#ok<AGROW>
        end
    end
end

%% ====================================================================
%   (A) Plain network map
% ====================================================================
f = figure('Color','w','Position',[60 60 1200 620],'Visible','off');
ax = axes(f); drawBaseMap(ax, border);
scatter(ax, lon, lat, cfg.markerSize, [0.85 0.20 0.15], 'filled', ...
    'MarkerFaceAlpha', 0.75, 'MarkerEdgeColor','none');
title(ax, sprintf('TOAR-II monitoring network — %d  (%d stations)', cfg.year, nStations), ...
    'FontWeight','bold','FontSize',14);
pthA = fullfile(cfg.outDir, sprintf('toar_stations_%d_network.png', cfg.year));
exportgraphics(f, pthA, 'Resolution', 200); close(f);
fprintf('  saved %s\n', pthA);

%% ====================================================================
%   (B) Stations colored by annual-mean MDA8 ozone
% ====================================================================
f = figure('Color','w','Position',[60 60 1200 620],'Visible','off');
ax = axes(f); drawBaseMap(ax, border);
scatter(ax, lon, lat, cfg.markerSize+6, meanO3, 'filled', ...
    'MarkerFaceAlpha', 0.85, 'MarkerEdgeColor',[0.2 0.2 0.2], 'LineWidth',0.2);
try, colormap(ax, NoraColormap); catch, colormap(ax, parula); end
clo = prctile(meanO3, 2); chi = prctile(meanO3, 98);
if chi > clo; clim(ax, [clo chi]); end
cb = colorbar(ax); cb.Label.String = 'Annual-mean MDA8 O_3 (ppb)';
title(ax, sprintf('TOAR-II stations colored by %d annual-mean MDA8 ozone  (%d stations)', ...
    cfg.year, nStations), 'FontWeight','bold','FontSize',14);
pthB = fullfile(cfg.outDir, sprintf('toar_stations_%d_meanO3.png', cfg.year));
exportgraphics(f, pthB, 'Resolution', 200); close(f);
fprintf('  saved %s\n', pthB);

fprintf('=== DONE ===\n');
end  % main


%% ====================================================================
%   LOCAL HELPER
% ====================================================================
function drawBaseMap(ax, border)
    hold(ax,'on');
    if ~isempty(border)
        plot(ax, border(:,1), border(:,2), '-', 'Color',[0.6 0.6 0.6], 'LineWidth',0.4);
    end
    axis(ax, [-180 180 -90 90]); daspect(ax,[1 1 1]); box(ax,'on');
    set(ax,'XTick',-180:60:180,'YTick',-90:30:90);
    xlabel(ax,'Longitude (°)'); ylabel(ax,'Latitude (°)');
end
