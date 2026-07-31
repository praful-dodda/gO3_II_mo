function plotPipelineDiagnostic(overrides)
% plotPipelineDiagnostic.m - Stage-by-stage diagnostic visualization of the
% TOAR-II BME ozone data-fusion pipeline for ONE small region and ONE month.
%
% Produces, for a configurable region + month:
%   (A) a combined EARLY-STAGES figure   (obs, global offset, covariance)
%   (B) a combined FUSION-STORY figure   (raw -> f-RAMP -> BME, + diff + uncertainty)
%   (C) every panel ALSO saved as its own PNG (same naming convention)
%
% Panels:
%   1 Observations         - TOAR-II station MDA8 (points)
%   2 Global offset         - separable space/time mean-trend field
%   3 Covariance            - experimental + fitted (spatial & temporal)
%   4 Before f-RAMP         - raw CTM mean (from NetCDF)
%   5 After f-RAMP          - RAMP-corrected mean (lambda1), + obs overlay
%   6 BME estimate          - posterior mean (YkBMEm), + obs overlay
%   7 BME - f-RAMP          - difference of (6) and (5)   [replaces empty raw-uncertainty]
%   8 f-RAMP uncertainty    - RAMP std (sqrt lambda2)
%   9 BME uncertainty       - estimation std (sqrt XkBMEv)
%
% Reuses: getTOARobservationalData, getTOARglobalOffset, getTOARautoCov,
%   getTOARSoftData -> analyzeTOAR -> estTOARsBMEoptim (runs + saves the BME .mat),
%   loadRAMPdata (corrected CTM), loadRawCTMfromNC (raw CTM), stmeaninterp, NoraColormap.
%
% USAGE (from repo root, BMELIB on path):
%   plotPipelineDiagnostic                                   % MERRA2-GMI (default)
%   plotPipelineDiagnostic(struct('featureModel','M3fusion', ...
%        'BMEmethod','13000313-02','outSub','M3fusion'))     % another model -> sub-folder
%
% NOTE: M3fusion (and satellite products) have a RAMP product but NO raw gridded
% NetCDF, so the "before f-RAMP" panel will show 'no data' for those.

close all;

%% ====================================================================
%                    CONFIGURATION (defaults; override via struct arg)
% ====================================================================
if nargin < 1 || isempty(overrides); overrides = struct(); end

cfg.areaCode   = 8;                       % 8 = California (getTOARareaBoundaries)
cfg.region     = [-125 -114 32 42];       % [minLon maxLon minLat maxLat] plot extent
cfg.estYear    = 2016;
cfg.estMonth   = 7;                       % July (peak photochemical ozone)

cfg.BMEmethod    = '13000313-01';         % MERRA2-GMI (mask 01); M3fusion = '13000313-02'
cfg.featureModel = 'MERRA2-GMI';
cfg.rampDir      = 'D:\Users\praful\Documents\Data\ramp_data';
cfg.rawNCpath    = '';                    % '' -> derived from featureModel below

cfg.goScenario      = 3;
cfg.temporalModel   = 'exponential';
cfg.dataFormat      = 'stug';
cfg.mapResolution   = 0.5;
cfg.temporalPadding = 1;
cfg.keepOnlyLand    = true;
cfg.forceEstimation = 0;                  % 0 = reuse cached BME .mat if present
cfg.outSub          = '';                 % optional sub-folder under diagnostic_pipeline

% Apply caller overrides
for fn = fieldnames(overrides)'; cfg.(fn{1}) = overrides.(fn{1}); end

% Derived raw NetCDF path (if not explicitly set)
if isempty(cfg.rawNCpath)
    cfg.rawNCpath = fullfile('1data','CTM','model_output_data','netcdf_combined', ...
                             sprintf('%s_MDA8_combined.nc', cfg.featureModel));
end

cfg.outDir = fullfile('5BMEspatialPlots','diagnostic_pipeline', cfg.outSub);

% --- Derived --------------------------------------------------------
cfg.tk = cfg.estYear + (cfg.estMonth-1)/12;
if ~exist(cfg.outDir,'dir'); mkdir(cfg.outDir); end
monthNames = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
ttlMonth = sprintf('%s %d', monthNames{cfg.estMonth}, cfg.estYear);
cfg.base = sprintf('%s_go%d_area%d_y%d_m%02d', cfg.featureModel, cfg.goScenario, ...
                   cfg.areaCode, cfg.estYear, cfg.estMonth);   % shared naming stem

fprintf('\n========================================================\n');
fprintf('  PIPELINE DIAGNOSTIC: %s  (area %d, method %s)\n', ttlMonth, cfg.areaCode, cfg.BMEmethod);
fprintf('  Region [lon %g..%g, lat %g..%g], tk=%.2f\n', cfg.region, cfg.tk);
fprintf('========================================================\n\n');

%% ====================================================================
%   Inputs: obs, global offset, covariance (cheap / cached)
% ====================================================================
analyzeParam = makeAnalyzeParam(cfg);

fprintf('=== Loading obs / global offset / covariance ===\n');
obs = getTOARobservationalData(analyzeParam.stationTypes, analyzeParam.timeRange, analyzeParam.logTransf);
go  = getTOARglobalOffset(obs, cfg.goScenario, 0, 0, 0);
cov = getTOARautoCov(obs, go, cfg.temporalModel, 0);

%% ====================================================================
%   Ensure the BME result exists (run the pipeline if needed)
% ====================================================================
bmeFile = sprintf('BME%s_go%d_lt%d_area%d_res%.2f_%s_land%d_time%.2f.mat', ...
    cfg.BMEmethod, cfg.goScenario, analyzeParam.logTransf, cfg.areaCode, ...
    cfg.mapResolution, cfg.dataFormat, double(cfg.keepOnlyLand), cfg.tk);
bmePath = fullfile('5BMEspatialPlots', bmeFile);

if cfg.forceEstimation || ~exist(bmePath,'file')
    fprintf('\n=== Running BME pipeline (no cached result at %s) ===\n', bmePath);
    softData = getTOARSoftData(cfg.BMEmethod, analyzeParam, ...
        'spatialBuffer', 2, 'temporalPadding', 1, 'thinningFactor', 0, 'forceReload', 0);
    analyzeParam.softData = softData;
    analyzeTOAR(analyzeParam);
else
    fprintf('\n=== Using cached BME result: %s ===\n', bmePath);
end
assert(exist(bmePath,'file')==2, 'BME result not found after pipeline: %s', bmePath);

%% ====================================================================
%   Assemble per-stage data (region-cropped)
% ====================================================================
[B, cmapOz] = loadPlotAssets();
cmapUnc  = hot(64);
cmapDiff = bluewhitered_local(128);
R = cfg.region;
inR = @(lon,lat) lon>=R(1) & lon<=R(2) & lat>=R(3) & lat<=R(4);

% --- Observations at this month -------------------------------------
[~, itObs] = min(abs(obs.tME - cfg.tk));
ov = obs.Z(:, itObs);
oMask = ~isnan(ov) & inR(obs.sMS(:,1), obs.sMS(:,2));
obsLon = obs.sMS(oMask,1); obsLat = obs.sMS(oMask,2); obsVal = ov(oMask);

% --- Global-offset field over a region mesh -------------------------
[GX,GY] = meshgrid(R(1):0.1:R(2), R(3):0.1:R(4));
gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, [GX(:) GY(:)], cfg.tk);

% --- Raw CTM (before f-RAMP) ----------------------------------------
raw = loadRawCTMfromNC(cfg.rawNCpath, cfg.estYear, cfg.estMonth);
if ~isempty(raw)
    rm = inR(raw.sMS(:,1), raw.sMS(:,2));
    rawLon = raw.sMS(rm,1); rawLat = raw.sMS(rm,2); rawMean = double(raw.Z(rm));
else
    rawLon=[]; rawLat=[]; rawMean=[];
end

% --- f-RAMP corrected CTM (mean lambda1, std sqrt lambda2) ----------
ctm = loadRAMPdata(cfg.featureModel, [cfg.estYear cfg.estYear], cfg.rampDir);
[~, itC] = min(abs(ctm.tME - cfg.tk));
cm = inR(ctm.sMS(:,1), ctm.sMS(:,2));
ctmLon = ctm.sMS(cm,1); ctmLat = ctm.sMS(cm,2);
ctmMean = double(ctm.Z(cm, itC));
ctmStd  = sqrt(max(0, double(ctm.Zv(cm, itC))));

% --- BME result -----------------------------------------------------
S = load(bmePath, 'BMEs'); BMEs = S.BMEs;
bm = inR(BMEs.sk(:,1), BMEs.sk(:,2));
bmeLon = BMEs.sk(bm,1); bmeLat = BMEs.sk(bm,2);
bmeMean = double(BMEs.YkBMEm(bm));
bmeStd  = sqrt(max(0, double(BMEs.XkBMEv(bm))));

% --- BME - f-RAMP corrected mean (on BME grid) ----------------------
Fmod = scatteredInterpolant(ctmLon, ctmLat, ctmMean, 'natural','none');
diffBME = bmeMean - Fmod(bmeLon, bmeLat);

%% ---- Shared color limits ------------------------------------------
pool = [obsVal(:); rawMean(:); ctmMean(:); bmeMean(:)]; pool = pool(isfinite(pool));
ozClim = robustClim(pool, [2 98]);
uncPool = [ctmStd(:); bmeStd(:)]; uncPool = uncPool(isfinite(uncPool));
uncClim = robustClim(uncPool, [2 98]);
dmax = prctile(abs(diffBME(isfinite(diffBME))), 98); if ~(dmax>0); dmax = 1; end
diffClim = [-dmax dmax];

fprintf('  ozone clim [%.1f %.1f], unc clim [%.1f %.1f], diff +/-%.1f ppb\n', ozClim, uncClim, dmax);

%% ====================================================================
%   Panel registry: id -> draw handle f(ax)
% ====================================================================
panels = {
 'panel_1_observations',   @(ax) drawPoints(ax, obsLon,obsLat,obsVal, ozClim, cmapOz, R,B, ...
        sprintf('1. TOAR-II observations (%s)',ttlMonth), 'MDA8 O_3 (ppb)');
 'panel_2_globaloffset',   @(ax) drawMap(ax, GX(:),GY(:),gok, [], cmapOz, R,B, ...
        sprintf('2. Global offset (scenario %d)',cfg.goScenario), 'O_3 offset (ppb)', []);
 'panel_3a_cov_spatial',   @(ax) drawCovSpatial(ax, cov);
 'panel_3b_cov_temporal',  @(ax) drawCovTemporal(ax, cov);
 'panel_4_raw_mean',       @(ax) drawMap(ax, rawLon,rawLat,rawMean, ozClim, cmapOz, R,B, ...
        sprintf('4. Before f-RAMP: raw %s',cfg.featureModel), 'MDA8 O_3 (ppb)', []);
 'panel_5_framp_mean',     @(ax) drawMap(ax, ctmLon,ctmLat,ctmMean, ozClim, cmapOz, R,B, ...
        '5. After f-RAMP: corrected mean (\lambda_1)', 'MDA8 O_3 (ppb)', [obsLon obsLat obsVal]);
 'panel_6_bme_mean',       @(ax) drawMap(ax, bmeLon,bmeLat,bmeMean, ozClim, cmapOz, R,B, ...
        '6. BME posterior mean', 'MDA8 O_3 (ppb)', [obsLon obsLat obsVal]);
 'panel_7_bme_minus_framp',@(ax) drawMap(ax, bmeLon,bmeLat,diffBME, diffClim, cmapDiff, R,B, ...
        '7. BME \minus f-RAMP corrected', '\DeltaO_3 (ppb)', []);
 'panel_8_framp_std',      @(ax) drawMap(ax, ctmLon,ctmLat,ctmStd, uncClim, cmapUnc, R,B, ...
        '8. f-RAMP uncertainty (\surd\lambda_2)', 'O_3 std (ppb)', []);
 'panel_9_bme_std',        @(ax) drawMap(ax, bmeLon,bmeLat,bmeStd, uncClim, cmapUnc, R,B, ...
        '9. BME estimation std', 'O_3 std (ppb)', []);
};

%% ====================================================================
%   (C) Save each panel individually
% ====================================================================
fprintf('\n=== Saving individual panels ===\n');
saved = {};
for i = 1:size(panels,1)
    f = figure('Color','w','Position',[100 100 640 560],'Visible','off');
    panels{i,2}(axes(f)); %#ok<LAXES>
    pth = fullfile(cfg.outDir, sprintf('%s_%s.png', panels{i,1}, cfg.base));
    exportgraphics(f, pth, 'Resolution', 200); close(f);
    saved{end+1} = pth; %#ok<SAGROW>
    fprintf('  %s\n', pth);
end

%% ====================================================================
%   (A) Combined early-stages figure (obs, GO, covariance)
% ====================================================================
idx = @(name) find(strcmp(panels(:,1), name));
figE = figure('Color','w','Position',[60 60 1300 760]);
tlE = tiledlayout(figE,2,2,'TileSpacing','compact','Padding','compact');
title(tlE, sprintf('Pipeline early stages  |  %s  |  %s', ttlMonth, cfg.featureModel),'FontWeight','bold');
for nm = {'panel_1_observations','panel_2_globaloffset','panel_3a_cov_spatial','panel_3b_cov_temporal'}
    panels{idx(nm{1}),2}(nexttile(tlE));
end
earlyPng = fullfile(cfg.outDir, sprintf('pipeline_earlystages_%s.png', cfg.base));
exportgraphics(figE, earlyPng, 'Resolution', 200);

%% ====================================================================
%   (B) Combined fusion-story figure (raw->RAMP->BME, diff, uncertainty)
% ====================================================================
figF = figure('Color','w','Position',[60 60 1560 900]);
tlF = tiledlayout(figF,2,3,'TileSpacing','compact','Padding','compact');
title(tlF, sprintf('BME data fusion: raw \\rightarrow f-RAMP \\rightarrow BME  |  %s  |  %s', ...
    cfg.featureModel, ttlMonth),'FontWeight','bold');
for nm = {'panel_4_raw_mean','panel_5_framp_mean','panel_6_bme_mean', ...
          'panel_7_bme_minus_framp','panel_8_framp_std','panel_9_bme_std'}
    panels{idx(nm{1}),2}(nexttile(tlF));
end
storyPng = fullfile(cfg.outDir, sprintf('pipeline_fusionstory_%s.png', cfg.base));
exportgraphics(figF, storyPng, 'Resolution', 200);

%% ====================================================================
%   Report
% ====================================================================
fprintf('\n========================================================\n');
fprintf('  DONE. Combined figures:\n    %s\n    %s\n', earlyPng, storyPng);
fprintf('  + %d individual panels in %s\n', numel(saved), cfg.outDir);
fprintf('========================================================\n');

end  % main function

%% ====================================================================
%   LOCAL HELPERS
% ====================================================================

function analyzeParam = makeAnalyzeParam(cfg)
    analyzeParam = struct();
    analyzeParam.stationTypes = 'all';
    analyzeParam.logTransf    = 0;
    analyzeParam.timeRange    = [cfg.estYear - cfg.temporalPadding, cfg.estYear + cfg.temporalPadding];
    analyzeParam.tkVec        = cfg.tk;
    analyzeParam.BMEmethod    = cfg.BMEmethod;
    analyzeParam.dataFormat   = cfg.dataFormat;
    analyzeParam.goScenario   = cfg.goScenario;
    analyzeParam.forceGO      = 0;
    analyzeParam.goPlot       = 0;
    analyzeParam.temporalModel = cfg.temporalModel;
    analyzeParam.forceCov     = 0;
    analyzeParam.areaCode      = cfg.areaCode;
    analyzeParam.mapResolution = cfg.mapResolution;
    analyzeParam.keepOnlyLand  = cfg.keepOnlyLand;
    analyzeParam.includeAntarctica = false;
    analyzeParam.coastBuffer   = 0.5;
    analyzeParam.popCoverFile  = fullfile('Population-Data','PopulationData2019.csv');
    analyzeParam.forceEstimation = cfg.forceEstimation;
    analyzeParam.runExplore = 0; analyzeParam.runGO = 1; analyzeParam.runCov = 1; analyzeParam.runBME = 1;
    analyzeParam.plotResults  = 0; analyzeParam.plotVariance = 0;
    analyzeParam.nxpix = 150;  analyzeParam.nypix = 100;
    analyzeParam.bufferDist = 0.5;  analyzeParam.bufferType = 'soft';
    analyzeParam.interpMethod = 'natural';
    analyzeParam.dxRes = 0.1;  analyzeParam.dyRes = 0.1;
    analyzeParam.gridOffset = 0.1;
end

function [B, cmapOz] = loadPlotAssets()
    B = struct('ok',false,'lon',{{}},'lat',{{}});
    if exist(fullfile('1data','borderdata.mat'),'file')
        try
            bd = load(fullfile('1data','borderdata.mat'), 'places','lon','lat');
            B.ok = true; B.lon = bd.lon; B.lat = bd.lat;
        catch
            warning('Could not load 1data/borderdata.mat');
        end
    end
    if exist('NoraColormap','file'); cmapOz = NoraColormap; else; cmapOz = parula(64); end
end

function drawBorders(ax, B)
    if ~B.ok; return; end
    for k = 1:numel(B.lon)
        if ~isempty(B.lon{k}); plot(ax, B.lon{k}, B.lat{k}, 'k-', 'LineWidth', 0.5); end
    end
end

function drawMap(ax, lon, lat, val, clim_, cmap, R, B, ttl, cbarLab, obsXYZ)
% Interpolate a scattered field to a region mesh and render with pcolor.
    hold(ax,'on');
    lon=lon(:); lat=lat(:); val=val(:);
    ok = isfinite(lon)&isfinite(lat)&isfinite(val); lon=lon(ok); lat=lat(ok); val=val(ok);
    if numel(val) >= 3
        [GX,GY] = meshgrid(linspace(R(1),R(2),200), linspace(R(3),R(4),200));
        try
            F = scatteredInterpolant(lon,lat,val,'natural','none'); GV = F(GX,GY);
        catch
            GV = griddata(lon,lat,val,GX,GY,'natural');
        end
        pcolor(ax,GX,GY,GV); shading(ax,'interp');
    elseif ~isempty(val)
        scatter(ax, lon, lat, 40, val, 'filled');
    else
        text(ax, mean(R(1:2)), mean(R(3:4)), 'no data', 'HorizontalAlignment','center');
    end
    if nargin>=11 && ~isempty(obsXYZ)
        scatter(ax, obsXYZ(:,1), obsXYZ(:,2), 36, obsXYZ(:,3), 'filled', ...
            'MarkerEdgeColor','k','LineWidth',0.5);
    end
    drawBorders(ax, B);
    colormap(ax, cmap);
    if ~isempty(clim_) && clim_(2)>clim_(1); clim(ax, clim_); end
    cb = colorbar(ax); cb.Label.String = cbarLab;
    axis(ax, R); box(ax,'on'); set(ax,'Layer','top');
    xlabel(ax,'Longitude'); ylabel(ax,'Latitude'); title(ax, ttl);
    hold(ax,'off');
end

function drawPoints(ax, lon, lat, val, clim_, cmap, R, B, ttl, cbarLab)
    hold(ax,'on'); drawBorders(ax, B);
    scatter(ax, lon, lat, 55, val, 'filled', 'MarkerEdgeColor','k','LineWidth',0.4);
    colormap(ax, cmap);
    if ~isempty(clim_) && clim_(2)>clim_(1); clim(ax, clim_); end
    cb = colorbar(ax); cb.Label.String = cbarLab;
    axis(ax, R); box(ax,'on'); set(ax,'Layer','top');
    xlabel(ax,'Longitude'); ylabel(ax,'Latitude');
    title(ax, sprintf('%s  (n=%d)', ttl, numel(val)));
    hold(ax,'off');
end

function drawCovSpatial(ax, cov)
    hold(ax,'on');
    if isfield(cov,'rLag')&&isfield(cov,'Cr')
        plot(ax, cov.rLag, cov.Cr, 'bo','MarkerFaceColor','b','DisplayName','Experimental');
        rmax = max(cov.rLag(:));
    else; rmax = 50; end
    rf = linspace(0, max(rmax,eps), 400); Sr = zeros(size(rf));
    for i = 1:numel(cov.covparam); p = cov.covparam{i}; Sr = Sr + p(1).*exp(-3*rf./p(2)); end
    plot(ax, rf, Sr, 'r-','LineWidth',1.5,'DisplayName','Fitted model');
    xlabel(ax,'Spatial lag (deg)'); ylabel(ax,'Covariance');
    title(ax,'3. Spatial covariance'); grid(ax,'on'); legend(ax,'Location','best'); box(ax,'on');
    hold(ax,'off');
end

function drawCovTemporal(ax, cov)
    hold(ax,'on');
    if isfield(cov,'tLag')&&isfield(cov,'Ct')
        plot(ax, cov.tLag, cov.Ct, 'bo','MarkerFaceColor','b','DisplayName','Experimental');
        tmax = max(cov.tLag(:));
    else; tmax = 1; end
    tf = linspace(0, max(tmax,eps), 400); Tt = zeros(size(tf));
    for i = 1:numel(cov.covparam)
        p = cov.covparam{i}; tname='';
        if isfield(cov,'covmodel') && numel(cov.covmodel)>=i
            parts = strsplit(cov.covmodel{i},'/'); if numel(parts)>=2; tname=parts{2}; end
        end
        if contains(lower(tname),'holecos'); Tt = Tt + p(1).*cos(pi*tf./p(3));
        else; Tt = Tt + p(1).*exp(-3*tf./p(3)); end
    end
    plot(ax, tf, Tt, 'r-','LineWidth',1.5,'DisplayName','Fitted model');
    xlabel(ax,'Temporal lag (years)'); ylabel(ax,'Covariance');
    title(ax,'3b. Temporal covariance'); grid(ax,'on'); legend(ax,'Location','best'); box(ax,'on');
    hold(ax,'off');
end

function cl = robustClim(v, pcts)
    v = v(isfinite(v));
    if isempty(v); cl = [0 1]; return; end
    cl = prctile(v, pcts);
    if ~(cl(2)>cl(1)); cl = [min(v) max(v)]; end
    if ~(cl(2)>cl(1)); cl = cl(1) + [0 1]; end
end

function cmap = bluewhitered_local(n)
    if nargin<1; n=128; end
    h = floor(n/2);
    up = linspace(0,1,h)';
    blue = [up, up, ones(h,1)];
    dn = linspace(1,0,n-h)';
    red  = [ones(n-h,1), dn, dn];
    cmap = [blue; red];
end
