function stats = compareSoftVsBugMaps(oldFile, newFile, outDir)
% compareSoftVsBugMaps - Quantify the multi-soft vs mis-indexing bug on one BME map.
%
% Diffs an OLD (buggy compact-vs) saved BME estimate against a NEW (fixed full-cube vs)
% re-estimate of the SAME month/config, for both the BME mean (XkBMEm) and variance
% (XkBMEv). Reports magnitude statistics and saves side-by-side + difference maps so we
% can see whether the variance field carries longitude-coherent (vertical) structure.
%
% SYNTAX:
%   stats = compareSoftVsBugMaps(oldFile, newFile)
%   stats = compareSoftVsBugMaps(oldFile, newFile, outDir)
%
% INPUTS:
%   oldFile - path to the OLD 5BMEspatialPlots/BME..._time....mat (made with buggy code)
%   newFile - path to the NEW re-estimate of the same month (fixed code, forceEstimation)
%   outDir  - where to write figures/CSV (default: 'paper-3-figures/softvs_bug_check')
%
% OUTPUT (struct 'stats') with mean/var fields: max/median abs diff, % cells changed,
% correlation, and the value ranges. Also writes:
%   <outDir>/softvs_diff_mean.png, softvs_diff_var.png, softvs_bug_stats.csv
%
% Both files must share the same estimation grid (sk) and time (tk).

if nargin < 3 || isempty(outDir)
    outDir = fullfile('paper-3-figures', 'softvs_bug_check');
end
if ~exist(outDir, 'dir'); mkdir(outDir); end

O = load(oldFile);  Ob = O.BMEs;
N = load(newFile);  Nb = N.BMEs;

% --- align on grid ---
if ~isequal(size(Ob.sk), size(Nb.sk)) || max(abs(Ob.sk(:) - Nb.sk(:))) > 1e-6
    error('compareSoftVsBugMaps:grid', 'Old/new estimation grids differ.');
end
sk = Ob.sk;
lon = sk(:,1); lat = sk(:,2);

mOld = Ob.XkBMEm(:);  mNew = Nb.XkBMEm(:);
vOld = Ob.XkBMEv(:);  vNew = Nb.XkBMEv(:);

stats.tk        = local_getfield(Ob, 'tk', NaN);
stats.nGrid     = numel(mOld);
stats.mean      = local_diffStats(mOld, mNew);
stats.variance  = local_diffStats(vOld, vNew);

% --- console report ---
fprintf('\n=== Soft-vs bug impact: %s ===\n', oldFile);
fprintf('Grid points: %d   time: %s\n', stats.nGrid, num2str(stats.tk));
local_print('BME MEAN  (ppb)   ', stats.mean);
local_print('BME VAR   (ppb^2) ', stats.variance);

% --- figures ---
local_mapTriptych(lon, lat, mOld, mNew, 'BME mean (ppb)', ...
    fullfile(outDir, 'softvs_diff_mean.png'));
local_mapTriptych(lon, lat, vOld, vNew, 'BME variance (ppb^2)', ...
    fullfile(outDir, 'softvs_diff_var.png'));

% --- csv ---
T = table( ["mean";"variance"], ...
    [stats.mean.maxAbs; stats.variance.maxAbs], ...
    [stats.mean.medAbs; stats.variance.medAbs], ...
    [stats.mean.pctChanged; stats.variance.pctChanged], ...
    [stats.mean.corr; stats.variance.corr], ...
    'VariableNames', {'Field','MaxAbsDiff','MedAbsDiff','PctCellsChanged','Corr'});
writetable(T, fullfile(outDir, 'softvs_bug_stats.csv'));
fprintf('\nWrote figures + softvs_bug_stats.csv to %s\n', outDir);

end

% ========================================================================
function s = local_diffStats(a, b)
ok = ~isnan(a) & ~isnan(b);
d = b(ok) - a(ok);
s.n          = nnz(ok);
s.maxAbs     = max(abs(d));
s.medAbs     = median(abs(d));
s.meanAbs    = mean(abs(d));
s.pctChanged = 100 * nnz(abs(d) > 1e-6) / max(1, s.n);
if s.n > 2 && std(a(ok)) > 0 && std(b(ok)) > 0
    s.corr = corr(a(ok), b(ok));
else
    s.corr = NaN;
end
s.oldRange = [min(a(ok)) max(a(ok))];
s.newRange = [min(b(ok)) max(b(ok))];
end

% ========================================================================
function local_print(label, s)
fprintf('%s maxabs=%.4g  medabs=%.4g  %%changed=%.1f  corr=%.5f  old[%.3g %.3g] new[%.3g %.3g]\n', ...
    label, s.maxAbs, s.medAbs, s.pctChanged, s.corr, ...
    s.oldRange(1), s.oldRange(2), s.newRange(1), s.newRange(2));
end

% ========================================================================
function v = local_getfield(S, f, dflt)
if isfield(S, f), v = S.(f); else, v = dflt; end
if isempty(v), v = dflt; end
v = v(1);
end

% ========================================================================
function local_mapTriptych(lon, lat, a, b, ttl, outPng)
% Scatter old / new / (new-old) on the estimation grid.
d = b - a;
fig = figure('Position', [80 80 1500 420], 'Visible', 'off');
clim = [min([a;b]) max([a;b])];
crange = [min([a;b]) max([a;b])];
ax1 = subplot(1,3,1); scatter(lon, lat, 6, a, 'filled'); title(['OLD (buggy) ' ttl]);
set(ax1, 'CLim', crange); colorbar; axis tight;
ax2 = subplot(1,3,2); scatter(lon, lat, 6, b, 'filled'); title(['NEW (fixed) ' ttl]);
set(ax2, 'CLim', crange); colorbar; axis tight;
ax3 = subplot(1,3,3); scatter(lon, lat, 6, d, 'filled'); title('NEW - OLD');
dm = max(abs(d(~isnan(d)))); if isempty(dm) || dm == 0, dm = 1; end
set(ax3, 'CLim', [-dm dm]); colorbar; axis tight;
try
    colormap(ax3, local_bwr());
catch
end
exportgraphics(fig, outPng, 'Resolution', 130);
close(fig);
end

% ========================================================================
function cmap = local_bwr()
n = 128; t = linspace(0,1,n)';
cmap = [ [t; ones(n,1)], [t; flipud(t)], [ones(n,1); flipud(t)] ];
end
