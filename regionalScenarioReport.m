function regionalScenarioReport(outDir)
% regionalScenarioReport - Regional CBV skill differences between fusion
% scenarios for three periods (1990-2004, 2005-2016, 2017-2020).
%
% For each period x box-size x scenario-step it computes, per geographic
% region, the R2 and RMSE of the method and its baseline and the deltas,
% in BOTH statMode = 'averaged' (per-year stat then mean over years) and
% 'pooled' (one stat over all pooled raw points). Writes a tidy long-format
% CSV and a set of PNG figures for a stand-alone report.
%
%   regionalScenarioReport            % -> paper-3-figures/regional_report
%   regionalScenarioReport(outDir)
%
% Reuses the CBV filename convention and region definitions used by
% summarizeCBVforPaper.m / assignRegions.m.

if nargin < 1 || isempty(outDir)
    outDir = fullfile('paper-3-figures', 'regional_report');
end
if ~exist(outDir, 'dir'); mkdir(outDir); end
cbvDir = fullfile('7validation', 'CBV');

%% ---- Method ladder per period -----------------------------------------
OBS = struct('code','10000133','go',0,'label','Obs');
M3  = struct('code','13000313-02','go',3,'label','Obs+M3fusion');
S1  = struct('code','13000313-06','go',3,'label','Obs+M3fusion+OMI-MLS');
S2  = struct('code','13000313-0E','go',3,'label','Obs+M3fusion+OMI-MLS+IASI');

periods = struct( ...
    'name', {'1990-2004','2005-2016','2017-2020'}, ...
    'years',{1990:2004, 2005:2016, 2017:2020}, ...
    'methods', {{OBS,M3}, {OBS,M3,S1}, {OBS,M3,S1,S2}});

boxes  = [5.0 20.0];
regOrder = {'Global','North America','Europe','East Asia','South Asia', ...
            'South America','Africa','Australia','Other'};

%% ---- Availability matrix ----------------------------------------------
fprintf('\n==== CBV file availability (years found / years requested) ====\n');
allMethods = {OBS,M3,S1,S2};
for b = boxes
    fprintf('\n  box %.1f deg\n', b);
    for ip = 1:numel(periods)
        P = periods(ip);
        fprintf('   %-10s : ', P.name);
        for k = 1:numel(allMethods)
            M = allMethods{k};
            ny = countYears(M.code, M.go, b, P.years, cbvDir);
            fprintf('%s=%d/%d  ', M.label, ny, numel(P.years));
        end
        fprintf('\n');
    end
end

%% ---- Pre-load all needed (method,box,period) into a cache -------------
cache = containers.Map('KeyType','char','ValueType','any');
for b = boxes
    for ip = 1:numel(periods)
        P = periods(ip);
        for k = 1:numel(P.methods)
            M = P.methods{k};
            key = dataKey(M, b, P.years);
            if ~isKey(cache, key)
                cache(key) = loadMethodRegional(M.code, M.go, b, P.years, cbvDir, regOrder);
            end
        end
    end
end

%% ---- Compute regional stats for every scenario step -------------------
rows = {};
hdr = {'box','period','comparison','method_code','base_code','region', ...
       'statMode','N_method','R2_M','R2_B','dR2','dR2_pct', ...
       'RMSE_M','RMSE_B','dRMSE','dRMSE_pct'};

for b = boxes
    for ip = 1:numel(periods)
        P = periods(ip);
        steps = buildSteps(P.methods, OBS, M3, S1, S2);
        for is = 1:numel(steps)
            stp = steps{is};
            Dm = cache(dataKey(stp.m, b, P.years));
            Db = cache(dataKey(stp.b, b, P.years));
            if isempty(Dm.any) || isempty(Db.any); continue; end
            for sm = {'averaged','pooled'}
                mode = sm{1};
                for ir = 1:numel(regOrder)
                    rg = regOrder{ir};
                    [r2m, rmm, nM] = regStat(Dm, rg, mode);
                    [r2b, rmb, ~ ] = regStat(Db, rg, mode);
                    if isnan(r2m) && isnan(r2b); continue; end
                    dR2  = r2m - r2b;
                    dRM  = rmb - rmm;                 % positive = RMSE reduced
                    dR2p = 100*dR2/abs(r2b);
                    dRMp = 100*dRM/abs(rmb);
                    rows(end+1,:) = {b, P.name, stp.label, ...
                        [stp.m.code '_go' num2str(stp.m.go)], ...
                        [stp.b.code '_go' num2str(stp.b.go)], rg, mode, ...
                        nM, r2m, r2b, dR2, dR2p, rmm, rmb, dRM, dRMp}; %#ok<AGROW>
                end
            end
        end
    end
end

%% ---- Write CSV ---------------------------------------------------------
T = cell2table(rows, 'VariableNames', hdr);
csvPath = fullfile(outDir, 'regional_scenario_deltas.csv');
writetable(T, csvPath);
fprintf('\nWrote %s  (%d rows)\n', csvPath, height(T));

%% ---- Figures -----------------------------------------------------------
makeFigures(T, outDir, regOrder);
fprintf('Figures written to %s\n', outDir);
end

% ========================================================================
function key = dataKey(M, box, years)
key = sprintf('%s_go%d_box%g_%d-%d', M.code, M.go, box, years(1), years(end));
end

function steps = buildSteps(meth, OBS, M3, S1, S2)
hasS1 = anyHas(meth, S1); hasS2 = anyHas(meth, S2);
steps = {};
steps{end+1} = struct('m',M3,'b',OBS,'label','Model vs Obs');              %#ok<*AGROW>
if hasS1
    steps{end+1} = struct('m',S1,'b',M3, 'label','Satellite(OMI) vs Model');
    steps{end+1} = struct('m',S1,'b',OBS,'label','Satellite(OMI) vs Obs');
end
if hasS2
    steps{end+1} = struct('m',S2,'b',M3, 'label','2Satellites vs Model');
    steps{end+1} = struct('m',S2,'b',S1, 'label','2nd Satellite (IASI) increment');
    steps{end+1} = struct('m',S2,'b',OBS,'label','2Satellites vs Obs');
end
end

function tf = anyHas(meth, M)
tf = false;
for i = 1:numel(meth)
    if strcmp(meth{i}.code, M.code) && meth{i}.go == M.go; tf = true; return; end
end
end

function n = countYears(code, go, box, years, cbvDir)
n = 0;
for y = years
    for f = 1:2
        fp = fullfile(cbvDir, sprintf('CBV_BME%s_go%d_box%.1f_fold%d_%d.mat', ...
            code, go, box, f, y));
        if exist(fp,'file'); n = n + 1; break; end
    end
end
end

% ========================================================================
function D = loadMethodRegional(code, go, box, years, cbvDir, regOrder)
% Load all year+fold annualResults; bin every point to a region; keep both a
% pooled store and a per-year store so we can compute pooled & averaged stats.
D.any = [];
D.pooled = struct();      % region -> [obs est]
D.byYear = struct();      % region -> cell{year} of [obs est]
for ir = 1:numel(regOrder)
    fn = matlab.lang.makeValidName(regOrder{ir});
    D.pooled.(fn) = zeros(0,2);
    D.byYear.(fn) = {};
end
for y = years
    yo = []; ye = []; ys = [];
    for f = 1:2
        fp = fullfile(cbvDir, sprintf('CBV_BME%s_go%d_box%.1f_fold%d_%d.mat', ...
            code, go, box, f, y));
        if ~exist(fp,'file'); continue; end
        S = load(fp);
        if ~isfield(S,'annualResults'); continue; end
        r = S.annualResults;
        if ~all(isfield(r, {'Y_obs','Y_est','sk'})); continue; end
        yo = [yo; r.Y_obs(:)]; ye = [ye; r.Y_est(:)]; ys = [ys; r.sk]; %#ok<AGROW>
    end
    if isempty(yo); continue; end
    D.any = true;
    reg = assignRegions(ys(:,1), ys(:,2));      % sk(:,1)=lon, sk(:,2)=lat
    for ir = 1:numel(regOrder)
        rg = regOrder{ir};
        fn = matlab.lang.makeValidName(rg);
        if strcmp(rg,'Global')
            mask = true(size(yo));
        else
            mask = strcmp(reg, rg);
        end
        o = yo(mask); e = ye(mask);
        ok = ~isnan(o) & ~isnan(e) & isfinite(o) & isfinite(e);
        o = o(ok); e = e(ok);
        D.pooled.(fn) = [D.pooled.(fn); [o e]];
        D.byYear.(fn){end+1} = [o e];
    end
end
end

% ========================================================================
function [r2, rmse, n] = regStat(D, region, mode)
fn = matlab.lang.makeValidName(region);
if ~isfield(D.pooled, fn); r2=NaN; rmse=NaN; n=0; return; end
P = D.pooled.(fn);
n = size(P,1);
if strcmp(mode,'pooled')
    if n < 2; r2=NaN; rmse=NaN; return; end
    st = calculateValidationStats(P(:,1), P(:,2));
    r2 = getf(st,'R2'); rmse = getf(st,'RMSE');
else  % averaged across years
    yc = D.byYear.(fn);
    r2v = []; rmv = [];
    for i = 1:numel(yc)
        A = yc{i};
        if size(A,1) < 2; continue; end
        st = calculateValidationStats(A(:,1), A(:,2));
        r2v(end+1) = getf(st,'R2');  %#ok<AGROW>
        rmv(end+1) = getf(st,'RMSE');%#ok<AGROW>
    end
    if isempty(r2v); r2=NaN; rmse=NaN; else
        r2 = mean(r2v,'omitnan'); rmse = mean(rmv,'omitnan');
    end
end
end

function v = getf(st, f)
if isstruct(st) && isfield(st,f); v = st.(f); else; v = NaN; end
end

% ========================================================================
function makeFigures(T, outDir, regOrder)
regsNoGlobal = regOrder(~strcmp(regOrder,'Global'));
modePrimary = 'averaged';

fig1 = figure('Position',[100 100 1000 520],'Visible','off');
plotGroupedDelta(T, 'Model vs Obs', 5.0, modePrimary, regsNoGlobal, ...
    {'1990-2004','2005-2016','2017-2020'}, ...
    '\DeltaR^2: Model fusion vs Obs-only (5\circ box, averaged)');
saveFig(fig1, fullfile(outDir,'fig1_model_vs_obs_dR2_box5.png'));

fig2 = figure('Position',[100 100 1000 520],'Visible','off');
plotGroupedDelta(T, 'Model vs Obs', 20.0, modePrimary, regsNoGlobal, ...
    {'1990-2004','2005-2016','2017-2020'}, ...
    '\DeltaR^2: Model fusion vs Obs-only (20\circ box, averaged)');
saveFig(fig2, fullfile(outDir,'fig2_model_vs_obs_dR2_box20.png'));

fig3 = figure('Position',[100 100 1000 520],'Visible','off');
plotSatDelta(T, 20.0, modePrimary, regsNoGlobal);
saveFig(fig3, fullfile(outDir,'fig3_satellite_vs_model_dR2_box20.png'));

fig4 = figure('Position',[100 100 1000 520],'Visible','off');
plotLadder(T, '2017-2020', 20.0, modePrimary, regsNoGlobal);
saveFig(fig4, fullfile(outDir,'fig4_ladder_2017-2020_box20.png'));

fig5 = figure('Position',[100 100 980 560],'Visible','off');
plotHeatmap(T, 20.0, modePrimary, regsNoGlobal);
saveFig(fig5, fullfile(outDir,'fig5_heatmap_dR2_box20.png'));
end

function plotGroupedDelta(T, comparison, box, mode, regs, periods, ttl)
M = NaN(numel(regs), numel(periods));
for ip = 1:numel(periods)
    for ir = 1:numel(regs)
        v = pick(T, box, periods{ip}, comparison, regs{ir}, mode, 'dR2');
        if ~isempty(v); M(ir,ip) = v; end
    end
end
bar(M); grid on;
set(gca,'XTick',1:numel(regs),'XTickLabel',regs,'XTickLabelRotation',30);
legend(periods,'Location','northeast'); ylabel('\DeltaR^2'); title(ttl);
end

function plotSatDelta(T, box, mode, regs)
periods = {'2005-2016','2017-2020'};
comps   = {'Satellite(OMI) vs Model','2Satellites vs Model'};
M = NaN(numel(regs), 2);
for ip = 1:2
    for ir = 1:numel(regs)
        v = pick(T, box, periods{ip}, comps{ip}, regs{ir}, mode, 'dR2');
        if ~isempty(v); M(ir,ip) = v; end
    end
end
bar(M); grid on;
set(gca,'XTick',1:numel(regs),'XTickLabel',regs,'XTickLabelRotation',30);
legend({'2005-2016: +OMI vs Model','2017-2020: +OMI+IASI vs Model'}, ...
    'Location','northwest');
ylabel('\DeltaR^2'); title('\DeltaR^2: Satellite contribution over model (20\circ box, averaged)');
end

function plotLadder(T, period, box, mode, regs)
steps = {'Obs','Model','+OMI','+OMI+IASI'};
M = NaN(numel(regs), 4);
for ir = 1:numel(regs)
    rg = regs{ir};
    M(ir,1) = pickAbs(T, box, period, 'Model vs Obs', rg, mode, 'R2_B');
    M(ir,2) = pickAbs(T, box, period, 'Model vs Obs', rg, mode, 'R2_M');
    M(ir,3) = pickAbs(T, box, period, 'Satellite(OMI) vs Model', rg, mode, 'R2_M');
    M(ir,4) = pickAbs(T, box, period, '2Satellites vs Model', rg, mode, 'R2_M');
end
bar(M); grid on;
set(gca,'XTick',1:numel(regs),'XTickLabel',regs,'XTickLabelRotation',30);
legend(steps,'Location','southwest'); ylabel('R^2'); ylim([0 1]);
title(sprintf('R^2 by region across scenarios, %s (20\\circ box, averaged)', period));
end

function plotHeatmap(T, box, mode, regs)
cols = { ...
  '1990-2004 | Model-Obs',    '1990-2004','Model vs Obs'; ...
  '2005-2016 | Model-Obs',    '2005-2016','Model vs Obs'; ...
  '2005-2016 | +OMI-Model',   '2005-2016','Satellite(OMI) vs Model'; ...
  '2017-2020 | Model-Obs',    '2017-2020','Model vs Obs'; ...
  '2017-2020 | +OMI-Model',   '2017-2020','Satellite(OMI) vs Model'; ...
  '2017-2020 | +IASI incr.',  '2017-2020','2nd Satellite (IASI) increment'};
M = NaN(numel(regs), size(cols,1));
for ic = 1:size(cols,1)
    for ir = 1:numel(regs)
        v = pick(T, box, cols{ic,2}, cols{ic,3}, regs{ir}, mode, 'dR2');
        if ~isempty(v); M(ir,ic) = v; end
    end
end
imagesc(M,'AlphaData',~isnan(M)); axis tight;
set(gca,'YTick',1:numel(regs),'YTickLabel',regs, ...
        'XTick',1:size(cols,1),'XTickLabel',cols(:,1),'XTickLabelRotation',25);
clim([-0.05 0.05]); colormap(redblue()); cb=colorbar; cb.Label.String='\DeltaR^2';
title('\DeltaR^2 by region and scenario step (20\circ box, averaged)');
for ir=1:numel(regs)
    for ic=1:size(cols,1)
        if ~isnan(M(ir,ic))
            text(ic,ir,sprintf('%+.3f',M(ir,ic)),'HorizontalAlignment','center', ...
                'FontSize',8,'Color',txtColor(M(ir,ic)));
        end
    end
end
end

function c = txtColor(v)
if abs(v) > 0.03; c=[1 1 1]; else; c=[0 0 0]; end
end

function v = pick(T, box, period, comparison, region, mode, metric)
idx = T.box==box & strcmp(T.period,period) & strcmp(T.comparison,comparison) & ...
      strcmp(T.region,region) & strcmp(T.statMode,mode);
if any(idx); v = T.(metric)(find(idx,1)); else; v = []; end
end

function v = pickAbs(T, box, period, comparison, region, mode, metric)
v = pick(T, box, period, comparison, region, mode, metric);
if isempty(v); v = NaN; end
end

function saveFig(f, p)
try
    exportgraphics(f, p, 'Resolution', 150);
catch
    print(f, p, '-dpng', '-r150');
end
close(f);
end

function cmap = redblue()
n = 256; cmap = zeros(n,3); h=floor(n/2);
cmap(1:h,1) = linspace(0.1,1,h); cmap(1:h,2)=linspace(0.2,1,h); cmap(1:h,3)=linspace(0.6,1,h);
cmap(h+1:end,1)=linspace(1,0.7,n-h); cmap(h+1:end,2)=linspace(1,0.0,n-h); cmap(h+1:end,3)=linspace(1,0.1,n-h);
end
