function ok = test_postprocess_integration()
% test_postprocess_integration - End-to-end check of the post-processing pipeline
%
% Builds synthetic monthly BME files, CBV summaries, and a population CSV in a
% temp folder, runs runPostprocess against them, and asserts that the expected
% outputs are produced. Exercises assembleBMEcube -> bestMethodByYear ->
% composeBestMethodCube -> computeGridWeights -> all analyses -> README.
%
% Run:  test_postprocess_integration

ok = true;
tmp = tempname; mkdir(tmp);
cleaner = onCleanup(@() rmdir(tmp, 's'));
src = fullfile(tmp, 'src'); mkdir(src);
outDir = fullfile(tmp, 'out');

% method/config must match assembleBMEcube's filename base
methods = {'MA', 'MB'};
go = 3; lt = 0; area = 0; res = 1.0; fmt = 'stug'; land = 1;
yrs = 2000:2002;

% 6-cell grid (a couple inside the CONUS box so area masks are non-empty)
sk = [-100 40; -90 35; -80 42; 10 50; 100 30; 20 -20];
nG = size(sk, 1);

for mi = 1:numel(methods)
    base = sprintf('BME%s_go%d_lt%d_area%d_res%.2f_%s_land%d', ...
        methods{mi}, go, lt, area, res, fmt, land);
    for y = yrs
        for m = 1:12
            tk = y + (m-1)/12;
            BMEs = struct();
            BMEs.sk = sk;
            BMEs.tk = tk;
            seas = 8*sin(2*pi*(m-1)/12);                 % summer peak
            val = 35 + seas + 1.0*(y-2000) + 0.2*(1:nG)' + (mi-1)*2;
            BMEs.YkBMEm = val;
            BMEs.XkBMEv = ones(nG, 1);
            fn = fullfile(src, sprintf('%s_time%.2f.mat', base, tk));
            save(fn, 'BMEs');
        end
    end
end

% CBV summaries: MA best in 2000-2001, MB best in 2002
mkrow = @(yr, r2, rmse) table(5, 1, yr, 100, r2, rmse, rmse*0.8, 1.0, ...
    'VariableNames', {'BoxSize','Fold','Year','N','R2','RMSE','MAE','NMB'});
MA = [mkrow(2000,0.80,3.0); mkrow(2001,0.82,2.8); mkrow(2002,0.70,3.5)];
MB = [mkrow(2000,0.75,3.2); mkrow(2001,0.78,3.0); mkrow(2002,0.85,2.5)];
writetable(MA, fullfile(tmp, 'CBV_summary_BMEMA_go3_lt0_x.csv'));
writetable(MB, fullfile(tmp, 'CBV_summary_BMEMB_go3_lt0_x.csv'));

% population CSV near the grid cells
P = table(sk(:,1)+0.1, sk(:,2)+0.1, (100:100:100*nG)', ...
    ["NAm";"NAm";"NAm";"Eur";"Asia";"Afr"], ...
    ["AMR";"AMR";"AMR";"EUR";"WPR";"AFR"], ...
    ["USA";"USA";"USA";"DEU";"CHN";"ZAF"], ...
    ["USA";"USA";"USA";"DEU";"CHN";"ZAF"], ...
    'VariableNames', {'Longitude','Latitude','POP','GBDRegion','WHORegion','CountryName','ISO3'});
popCsv = fullfile(tmp, 'pop.csv');
writetable(P, popCsv);

% run the driver
cfg = struct();
cfg.methodConfig = struct('goScenario', go, 'logTransf', lt, 'areaCode', area, ...
    'mapResolution', res, 'dataFormat', fmt, 'keepOnlyLand', land);
cfg.yearRange = [2000 2002];
cfg.fallbackMethod = 'MA';
cfg.srcDir = src;
cfg.cbvDir = tmp;
cfg.popCsv = popCsv;
cfg.outDir = outDir;
cfg.writePNG = false;       % keep headless and fast
cfg.writeNetCDF = true;

runPostprocess(cfg);

% assert the key outputs exist
must = { ...
    fullfile(outDir,'csv','best_method_by_year.csv'), ...
    fullfile(outDir,'csv','regional_series.csv'), ...
    fullfile(outDir,'csv','regional_trends.csv'), ...
    fullfile(outDir,'csv','annual_means_global_regional.csv'), ...
    fullfile(outDir,'csv','seasonal_means_trends.csv'), ...
    fullfile(outDir,'csv','popweighted_annual.csv'), ...
    fullfile(outDir,'csv','exposure_by_threshold.csv'), ...
    fullfile(outDir,'csv','exposure_trends.csv'), ...
    fullfile(outDir,'csv','trend_ols_regional.csv'), ...
    fullfile(outDir,'csv','trend_twoperiod_regional.csv'), ...
    fullfile(outDir,'ref_published_trends.csv'), ...
    fullfile(outDir,'csv','peak_month_trend.csv'), ...
    fullfile(outDir,'csv','country_trends.csv'), ...
    fullfile(outDir,'cubes','grid_weights.mat'), ...
    fullfile(outDir,'README.txt')};
for i = 1:numel(must)
    assert(exist(must{i}, 'file') > 0, 'missing output: %s', must{i});
end
% at least one NetCDF trend map
ncs = dir(fullfile(outDir, 'maps', '*.nc'));
assert(~isempty(ncs), 'no NetCDF maps written');

% best method: 2000/2001 -> MA, 2002 -> MB
bt = readtable(fullfile(outDir,'csv','best_method_by_year.csv'), ...
    'TextType', 'string');
assert(bt.BestMethod(bt.Year==2000) == "MA", '2000 best MA');
assert(bt.BestMethod(bt.Year==2002) == "MB", '2002 best MB');

fprintf('test_postprocess_integration: ALL PASSED (%d outputs verified).\n', numel(must));
end
