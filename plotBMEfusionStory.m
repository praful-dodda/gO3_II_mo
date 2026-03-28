function figPath = plotBMEfusionStory(ctmRamp, BMEsInput, obs, go, storyParam)
% plotBMEfusionStory - Visualize the complete BME data-fusion story
%
% Creates a multi-panel figure showing the full BME workflow for a region:
%   Row 1 (Mean fields, shared color scale):
%     [1] RAMP-corrected CTM mean (soft data prior)
%     [2] BME fusion mean (posterior)   -- with hard observations overlaid
%     [3] Difference: BME - CTM
%   Row 2 (Uncertainty / std-dev, shared color scale):
%     [4] RAMP-corrected CTM std dev  (sqrt(lambda2))
%     [5] BME fusion std dev  (sqrt(XkBMEv))
%     [6] Uncertainty reduction: CTM_std - BME_std
%
% Optionally a 2x3 "full story" mode showing raw CTM → RAMP → BME if
% storyParam.ctmRaw is supplied (structure with .sMS, .Z fields).
%
% SYNTAX:
%   figPath = plotBMEfusionStory(ctmRamp, BMEsInput, obs, go, storyParam)
%
% INPUTS:
%   ctmRamp   - Structure from loadRAMPdata (RAMP-corrected CTM):
%               .sMS   [nGrid x 2]  lon/lat grid coordinates
%               .tME   [1 x nT]     decimal-year time vector
%               .Z     [nGrid x nT] RAMP mean (lambda1)
%               .Zv    [nGrid x nT] RAMP variance (lambda2)
%               .modelName          string
%   BMEsInput - Either:
%               (a) path to a saved BME .mat result file, OR
%               (b) BMEs struct with .sk, .YkBMEm, .XkBMEv, .sMSobs, .Yobs
%   obs       - Observational data structure from getTOARobservationalData
%               (used for metadata; pass [] to omit hard-data overlay)
%   go        - Global offset structure from getTOARglobalOffset
%               (used for metadata only)
%   storyParam - Display parameters (all optional):
%               .region     [lonMin lonMax latMin latMax]
%                           Default: Europe [-15 40 35 72]
%               .timeIndex  Index into ctmRamp.tME to plot (default: 1)
%               .figDir     Output directory (default: '5BMEspatialPlots/story')
%               .figTitle   Base title string
%               .nxpix      Grid pixels x (default: 200)
%               .nypix      Grid pixels y (default: 150)
%               .interpMethod  griddata method (default: 'natural')
%               .obsMkrSize Observation marker size (default: 60)
%               .ctmRaw     Optional raw-CTM structure with .sMS .Z fields
%                           If provided, layout expands to show raw→RAMP→BME
%               .cmapMean   Colormap for mean panels  (default: NoraColormap or jet)
%               .cmapUnc    Colormap for uncertainty panels (default: hot)
%               .climMeanPct   Percentiles for mean color limits [lo hi] (default [3 97])
%               .climUncPct    Percentiles for unc color limits  [lo hi] (default [0 97])
%
% OUTPUTS:
%   figPath   - Full path of saved PNG figure
%
% EXAMPLE:
%   % Load data
%   ctm  = loadRAMPdata('UKML', [2016 2016]);
%   bmeFile = '5BMEspatialPlots/BME11000112_go3_lt0_area2_res1.00_stug_land1_time2016.00.mat';
%   obs  = getTOARobservationalData('all', [2016 2016]);
%   go   = getTOARglobalOffset(obs, 3, 0);
%
%   p.region     = [-15 40 35 72];   % Europe
%   p.timeIndex  = 1;                % Jan 2016
%   p.figDir     = '5BMEspatialPlots/story';
%   figPath = plotBMEfusionStory(ctm, bmeFile, obs, go, p);

%% ---- Input defaults ------------------------------------------------
if nargin < 5 || isempty(storyParam), storyParam = struct(); end
if ~isfield(storyParam, 'region'),       storyParam.region      = [-15 40 35 72]; end
if ~isfield(storyParam, 'timeIndex'),    storyParam.timeIndex   = 1;              end
if ~isfield(storyParam, 'figDir'),       storyParam.figDir      = fullfile('5BMEspatialPlots','story'); end
if ~isfield(storyParam, 'nxpix'),        storyParam.nxpix       = 200;            end
if ~isfield(storyParam, 'nypix'),        storyParam.nypix       = 150;            end
if ~isfield(storyParam, 'interpMethod'), storyParam.interpMethod= 'natural';      end
if ~isfield(storyParam, 'obsMkrSize'),   storyParam.obsMkrSize  = 60;             end
if ~isfield(storyParam, 'ctmRaw'),       storyParam.ctmRaw      = [];             end
if ~isfield(storyParam, 'climMeanPct'),  storyParam.climMeanPct = [3 97];         end
if ~isfield(storyParam, 'climUncPct'),   storyParam.climUncPct  = [0 97];         end

region = storyParam.region;
iT     = storyParam.timeIndex;

%% ---- Colormaps -------------------------------------------------------
if ~isfield(storyParam, 'cmapMean')
    if exist('NoraColormap.m', 'file')
        storyParam.cmapMean = NoraColormap;
    else
        storyParam.cmapMean = jet(64);
    end
end
if ~isfield(storyParam, 'cmapUnc')
    storyParam.cmapUnc = hot(64);
end

%% ---- Load BME results -----------------------------------------------
if ischar(BMEsInput) || isstring(BMEsInput)
    fprintf('Loading BME results: %s\n', BMEsInput);
    tmp = load(BMEsInput);
    fn  = fieldnames(tmp);
    if length(fn) == 1
        BMEs = tmp.(fn{1});
    else
        BMEs = tmp;
    end
else
    BMEs = BMEsInput;
end

% Ensure required fields
reqBME = {'sk','YkBMEm','XkBMEv'};
for f = reqBME
    if ~isfield(BMEs, f{1})
        error('BMEs missing field: %s', f{1});
    end
end
if ~isfield(BMEs, 'sMSobs'), BMEs.sMSobs = []; end
if ~isfield(BMEs, 'Yobs'),   BMEs.Yobs   = []; end

%% ---- Extract time info ----------------------------------------------
tME_ctm = ctmRamp.tME;
if iT > length(tME_ctm)
    error('timeIndex %d exceeds ctmRamp.tME length (%d)', iT, length(tME_ctm));
end
tVal     = tME_ctm(iT);
yearNum  = floor(tVal);
monthNum = round((tVal - yearNum)*12) + 1;
fprintf('Plotting time: %.4f (Year %d, Month %d)\n', tVal, yearNum, monthNum);

%% ---- Crop CTM data to region ----------------------------------------
ctm_lon = ctmRamp.sMS(:,1);
ctm_lat = ctmRamp.sMS(:,2);
inRegion = ctm_lon >= region(1) & ctm_lon <= region(2) & ...
           ctm_lat >= region(3) & ctm_lat <= region(4);

if sum(inRegion) == 0
    error('No CTM grid points found in region [%.1f %.1f %.1f %.1f]', region);
end

ctm_lon_r   = ctm_lon(inRegion);
ctm_lat_r   = ctm_lat(inRegion);
ctm_mean_r  = ctmRamp.Z(inRegion, iT);
ctm_var_r   = ctmRamp.Zv(inRegion, iT);
ctm_std_r   = sqrt(max(0, ctm_var_r));

%% ---- Crop BME data to region ----------------------------------------
bme_lon = BMEs.sk(:,1);
bme_lat = BMEs.sk(:,2);
inRegionBME = bme_lon >= region(1) & bme_lon <= region(2) & ...
              bme_lat >= region(3) & bme_lat <= region(4);

if sum(inRegionBME) == 0
    % BME result may already be cropped to region — just use all
    inRegionBME = true(size(bme_lon));
end

bme_lon_r  = bme_lon(inRegionBME);
bme_lat_r  = bme_lat(inRegionBME);
bme_mean_r = BMEs.YkBMEm(inRegionBME);
bme_std_r  = sqrt(max(0, BMEs.XkBMEv(inRegionBME)));

%% ---- Crop raw CTM (optional) ----------------------------------------
hasRaw = ~isempty(storyParam.ctmRaw);
if hasRaw
    rawCtm   = storyParam.ctmRaw;
    raw_lon  = rawCtm.sMS(:,1);
    raw_lat  = rawCtm.sMS(:,2);
    inRaw    = raw_lon >= region(1) & raw_lon <= region(2) & ...
               raw_lat >= region(3) & raw_lat <= region(4);
    raw_lon_r  = raw_lon(inRaw);
    raw_lat_r  = raw_lat(inRaw);
    if size(rawCtm.Z,2) >= iT
        raw_mean_r = rawCtm.Z(inRaw, iT);
    else
        raw_mean_r = rawCtm.Z(inRaw, 1);
    end
    if isfield(rawCtm,'Zv')
        raw_std_r = sqrt(max(0, rawCtm.Zv(inRaw, min(iT,size(rawCtm.Zv,2)))));
    else
        raw_std_r = nan(size(raw_mean_r));
    end
end

%% ---- Crop observations to region ------------------------------------
hasObs = ~isempty(BMEs.sMSobs) && ~isempty(BMEs.Yobs);
if hasObs
    obs_lon = BMEs.sMSobs(:,1);
    obs_lat = BMEs.sMSobs(:,2);
    inObs   = obs_lon >= region(1) & obs_lon <= region(2) & ...
              obs_lat >= region(3) & obs_lat <= region(4);
    obs_lon_r  = obs_lon(inObs);
    obs_lat_r  = obs_lat(inObs);
    obs_val_r  = BMEs.Yobs(inObs);
end

%% ---- Compute shared color limits ------------------------------------
% Mean color limits: across CTM + BME (and raw if available)
allMeans = [ctm_mean_r(~isnan(ctm_mean_r)); bme_mean_r(~isnan(bme_mean_r))];
if hasRaw, allMeans = [allMeans; raw_mean_r(~isnan(raw_mean_r))]; end
if hasObs, allMeans = [allMeans; obs_val_r(~isnan(obs_val_r))]; end
climMean = prctile(allMeans, storyParam.climMeanPct);

% Uncertainty color limits: across CTM + BME std devs
allUnc = [ctm_std_r(~isnan(ctm_std_r)); bme_std_r(~isnan(bme_std_r))];
if hasRaw && ~all(isnan(raw_std_r))
    allUnc = [allUnc; raw_std_r(~isnan(raw_std_r))];
end
climUnc = prctile(allUnc, storyParam.climUncPct);

% Difference color limits (symmetric)
diff_mean = bme_mean_r - interp_to_grid(ctm_lon_r, ctm_lat_r, ctm_mean_r, ...
                                         bme_lon_r, bme_lat_r);
diff_std  = ctm_std_r  - interp_to_grid(ctm_lon_r, ctm_lat_r, ctm_std_r, ...
                                         bme_lon_r, bme_lat_r);
climDiff    = max(abs(prctile(diff_mean(~isnan(diff_mean)), [3 97]))) * [-1 1];
climDiffUnc = max(abs(prctile(diff_std (~isnan(diff_std )), [3 97]))) * [-1 1];
if diff(climDiff)    == 0, climDiff    = [-1 1]; end
if diff(climDiffUnc) == 0, climDiffUnc = [-0.5 0.5]; end

%% ---- Layout ---------------------------------------------------------
if hasRaw
    nCols = 3;
    panelTitles = { ...
        sprintf('Raw CTM (%s)', rawCtm.modelName), ...
        sprintf('RAMP-corrected CTM (%s)', ctmRamp.modelName), ...
        'BME Fusion (posterior mean)'; ...
        'Raw CTM uncertainty (std)', ...
        'RAMP CTM uncertainty (std)', ...
        'BME Fusion uncertainty (std)'};
    dataMean = {raw_mean_r, ctm_mean_r, bme_mean_r};
    dataLon  = {raw_lon_r,  ctm_lon_r,  bme_lon_r};
    dataLat  = {raw_lat_r,  ctm_lat_r,  bme_lat_r};
    dataUnc  = {raw_std_r,  ctm_std_r,  bme_std_r};
    isDiff   = [false false false; false false false];
    climsRow1 = {climMean, climMean, climMean};
    climsRow2 = {climUnc,  climUnc,  climUnc};
else
    nCols = 3;
    panelTitles = { ...
        sprintf('RAMP-corrected CTM (%s)', ctmRamp.modelName), ...
        'BME Fusion (posterior mean)', ...
        'Difference: BME \minus CTM'; ...
        'RAMP CTM uncertainty (std)', ...
        'BME Fusion uncertainty (std)', ...
        'Uncertainty reduction: CTM \minus BME'};
    dataMean = {ctm_mean_r, bme_mean_r, diff_mean};
    dataLon  = {ctm_lon_r,  bme_lon_r,  bme_lon_r};
    dataLat  = {ctm_lat_r,  bme_lat_r,  bme_lat_r};
    dataUnc  = {ctm_std_r,  bme_std_r,  diff_std};
    isDiff   = [false false true; false false true];
    climsRow1 = {climMean, climMean, climDiff};
    climsRow2 = {climUnc,  climUnc,  climDiffUnc};
end

%% ---- Get land mask contour ------------------------------------------
maskcontour = [];
if exist(fullfile('1data','borderdata.mat'), 'file')
    bdata = load(fullfile('1data','borderdata.mat'), 'places', 'lon', 'lat');
    for k = 1:length(bdata.places)
        if ~isempty(bdata.lon{k})
            maskcontour = [maskcontour; [bdata.lon{k}(:), bdata.lat{k}(:)]; [NaN NaN]]; %#ok<AGROW>
        end
    end
end

%% ---- Create figure --------------------------------------------------
if ~isfield(storyParam,'figTitle') || isempty(storyParam.figTitle)
    if isfield(go,'scenario')
        goStr = sprintf('GO%d', go.scenario);
    else
        goStr = 'GO?';
    end
    if isfield(BMEs,'areaCode')
        storyParam.figTitle = sprintf('BME Fusion Story — Year %d, Month %02d  |  %s  |  Area %d', ...
            yearNum, monthNum, goStr, BMEs.areaCode);
    else
        storyParam.figTitle = sprintf('BME Fusion Story — Year %d, Month %02d  |  %s', ...
            yearNum, monthNum, goStr);
    end
end

figW = 500 * nCols;
figH = 850;
fig = figure('Position', [50 50 figW figH], 'Color', 'w');

% Determine unit string
if ~isempty(obs) && isfield(obs, 'Zunit')
    unitStr = obs.Zunit;
else
    unitStr = 'ppb';
end

% Pick diverging colormap for difference panels
cmapDiv = bluewhitered_cmap(64);  % fall back to custom or default

%% ---- Draw all 6 panels ---------------------------------------------
for row = 1:2
    if row == 1
        vals_all  = dataMean;
        lons_all  = dataLon;
        lats_all  = dataLat;
        clims_all = climsRow1;
        isDiff_row = isDiff(1,:);
        cmapBase   = storyParam.cmapMean;
        cbLabel    = sprintf('O_3 (%s)', unitStr);
    else
        vals_all  = dataUnc;
        lons_all  = dataLon;
        lats_all  = dataLat;
        clims_all = climsRow2;
        isDiff_row = isDiff(2,:);
        cmapBase   = storyParam.cmapUnc;
        cbLabel    = sprintf('\\sigma O_3 (%s)', unitStr);
    end

    for col = 1:nCols
        panelIdx = (row-1)*nCols + col;
        ax = subplot(2, nCols, panelIdx);

        z_plot = vals_all{col};
        x_plot = lons_all{col};
        y_plot = lats_all{col};
        cl     = clims_all{col};
        isDiffPanel = isDiff_row(col);

        % Skip if no valid data
        validMask = ~isnan(z_plot);
        if sum(validMask) < 4
            title(ax, panelTitles{row, col}, 'FontSize', 9);
            text(ax, 0.5, 0.5, 'No data', 'Units','normalized', ...
                'HorizontalAlignment','center');
            continue;
        end

        % Griddata interpolation to regular mesh
        Zg = interp_to_mesh(x_plot(validMask), y_plot(validMask), z_plot(validMask), ...
                            region, storyParam.nxpix, storyParam.nypix, ...
                            storyParam.interpMethod);

        % pcolor in current axes
        dx = diff(region(1:2)) / storyParam.nxpix;
        dy = diff(region(3:4)) / storyParam.nypix;
        xg_vec = region(1)+dx/2 : dx : region(2)-dx/2;
        yg_vec = region(3)+dy/2 : dy : region(4)-dy/2;
        [xg, yg] = meshgrid(xg_vec, yg_vec);

        ph = pcolor(ax, xg, yg, Zg);
        set(ph, 'EdgeColor', 'none');
        shading(ax, 'interp');
        hold(ax, 'on');

        % Country borders
        if ~isempty(maskcontour)
            plot(ax, maskcontour(:,1), maskcontour(:,2), 'k', 'LineWidth', 0.4);
        end

        % Overlay hard observations on BME mean panel (col==2 or col==nCols-1)
        if row == 1 && col == 2 && hasObs
            scatter(ax, obs_lon_r, obs_lat_r, storyParam.obsMkrSize, obs_val_r, ...
                'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.8);
        end

        % Color limits and colormap
        if isDiffPanel
            cmap_use = cmapDiv;
        else
            cmap_use = cmapBase;
        end
        colormap(ax, cmap_use);
        if cl(1) < cl(2)
            clim(ax, cl);
        end

        % Colorbar
        cb = colorbar(ax);
        ylabel(cb, cbLabel, 'FontSize', 8);
        cb.FontSize = 8;

        % Axis formatting
        axis(ax, 'equal');
        xlim(ax, region(1:2));
        ylim(ax, region(3:4));
        xlabel(ax, 'Longitude (°)', 'FontSize', 8);
        ylabel(ax, 'Latitude (°)',  'FontSize', 8);
        ax.FontSize = 8;
        grid(ax, 'on');
        box(ax, 'on');

        % Statistics annotation
        valid_vals = z_plot(validMask);
        if isDiffPanel
            statsStr = sprintf('\\mu_{diff}=%.1f\n\\sigma_{diff}=%.1f', ...
                mean(valid_vals,'omitnan'), std(valid_vals,'omitnan'));
        else
            statsStr = sprintf('\\mu=%.1f  \\sigma=%.1f\n[%.0f–%.0f] %s', ...
                mean(valid_vals,'omitnan'), std(valid_vals,'omitnan'), ...
                min(valid_vals), max(valid_vals), unitStr);
        end
        text(ax, 0.02, 0.04, statsStr, 'Units','normalized', ...
            'FontSize', 7, 'BackgroundColor', [1 1 1 0.75], ...
            'Margin', 2, 'Interpreter','tex');

        title(ax, panelTitles{row, col}, 'FontSize', 9, 'FontWeight','bold');

        hold(ax, 'off');
    end
end

%% ---- Supertitle -----------------------------------------------------
% Use annotation for suptitle (avoids toolbox dependency)
annotation(fig, 'textbox', [0 0.97 1 0.03], ...
    'String', storyParam.figTitle, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 12, 'FontWeight', 'bold', ...
    'EdgeColor', 'none', 'BackgroundColor', 'none');

%% ---- Save figure ---------------------------------------------------
if ~exist(storyParam.figDir, 'dir'), mkdir(storyParam.figDir); end

if isfield(BMEs,'areaCode')
    areaStr = sprintf('area%d', BMEs.areaCode);
else
    areaStr = 'area_unk';
end
fname = sprintf('BMEstory_%s_go%s_%s_y%d_m%02d.png', ...
    ctmRamp.modelName, ...
    conditional_str(isfield(go,'scenario'), num2str(go.scenario), 'X'), ...
    areaStr, yearNum, monthNum);

figPath = fullfile(storyParam.figDir, fname);
print(fig, figPath, '-dpng', '-r150');
fprintf('Figure saved: %s\n', figPath);

end

%% ========== Local helper functions =================================

function Zg = interp_to_mesh(x, y, z, region, nxpix, nypix, method)
% Interpolate scattered (x,y,z) onto a regular grid over region.
    dx = diff(region(1:2)) / nxpix;
    dy = diff(region(3:4)) / nypix;
    xg_vec = region(1)+dx/2 : dx : region(2)-dx/2;
    yg_vec = region(3)+dy/2 : dy : region(4)-dy/2;
    [xg, yg] = meshgrid(xg_vec, yg_vec);
    Zg = griddata(x, y, z, xg, yg, method);
end

function z_bme = interp_to_grid(x_src, y_src, z_src, x_dst, y_dst)
% Interpolate from CTM grid to BME estimation grid (scattered to scattered).
    valid = ~isnan(z_src);
    if sum(valid) < 4
        z_bme = nan(size(x_dst));
        return;
    end
    z_bme = griddata(x_src(valid), y_src(valid), z_src(valid), x_dst, y_dst, 'natural');
end

function cmap = bluewhitered_cmap(n)
% Simple blue-white-red diverging colormap (n levels).
    if nargin < 1, n = 64; end
    half = floor(n/2);
    blue_to_white = [linspace(0,1,half)', linspace(0,1,half)', ones(half,1)];
    white_to_red  = [ones(n-half,1), linspace(1,0,n-half)', linspace(1,0,n-half)'];
    cmap = [blue_to_white; white_to_red];
end

function s = conditional_str(cond, s_true, s_false)
    if cond, s = s_true; else, s = s_false; end
end
