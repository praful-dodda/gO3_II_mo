function M = cubeAnnualMetrics(cube, opts)
% cubeAnnualMetrics - Per-cell, per-year metrics from a monthly ozone cube
%
% Reshapes the monthly cube into [nGrid x 12 x nYears] (aligned by calendar
% month, NaN where a month is missing) and derives the per-cell/per-year
% quantities that the trend / seasonal / peak-month analyses all consume.
%
% SYNTAX:
%   M = cubeAnnualMetrics(cube)
%   M = cubeAnnualMetrics(cube, opts)
%
% INPUT:
%   cube - struct from assembleBMEcube (needs .ozone, .year, .month, .nGrid)
%   opts - (optional):
%       .osdma8Completeness ('strict'|'partial'|'any', default 'strict')
%       .osdma8MinMonths    (default 4, used when 'partial')
%
% OUTPUT (struct 'M'):
%   .years        1 x nY
%   .annualMean   nGrid x nY   mean of the 12 monthly MDA8 (omitnan)
%   .osdma8       nGrid x nY   max 6-month running-window mean (computeOSDMA8;
%                              uses Jan(Y)..Mar(Y+1); last/non-consecutive year
%                              falls back to within-year windows)
%   .DJF/.MAM/.JJA/.SON  nGrid x nY  seasonal means (calendar months)
%   .seasonAmp    nGrid x nY   max-min of the 4 seasonal means (cycle amplitude)
%   .peakMonth    nGrid x nY   calendar month (1-12) of the annual maximum
%   .peakValue    nGrid x nY   value at the peak month
%   .monthlyClim  nGrid x 12   long-term mean by calendar month
%   .nValidMonths nGrid x nY   count of non-NaN months per cell-year
%
% Run cubeAnnualMetrics('--selftest') to execute built-in unit checks.
%
% SEE ALSO: assembleBMEcube, computeOSDMA8, trendSenMK

%% Self-test entry point
if nargin >= 1 && (ischar(cube) || isstring(cube)) && strcmp(cube, '--selftest')
    M = local_selftest();
    return;
end

if nargin < 2 || isempty(opts), opts = struct(); end
if ~isfield(opts, 'osdma8Completeness'), opts.osdma8Completeness = 'strict'; end
if ~isfield(opts, 'osdma8MinMonths'), opts.osdma8MinMonths = 4; end

years = unique(cube.year);
nY = numel(years);
nG = cube.nGrid;

%% Reshape to [nGrid x 12 x nYears]
M3 = nan(nG, 12, nY);
for yi = 1:nY
    for m = 1:12
        col = find(cube.year == years(yi) & cube.month == m, 1);
        if ~isempty(col)
            M3(:, m, yi) = cube.ozone(:, col);
        end
    end
end

%% Annual mean + valid-month count
annualMean   = reshape(mean(M3, 2, 'omitnan'), [nG nY]);
nValidMonths = reshape(sum(~isnan(M3), 2), [nG nY]);

%% Seasonal means (calendar months) + amplitude
DJF = reshape(mean(M3(:, [12 1 2], :), 2, 'omitnan'), [nG nY]);
MAM = reshape(mean(M3(:, [3 4 5],  :), 2, 'omitnan'), [nG nY]);
JJA = reshape(mean(M3(:, [6 7 8],  :), 2, 'omitnan'), [nG nY]);
SON = reshape(mean(M3(:, [9 10 11],:), 2, 'omitnan'), [nG nY]);
seasonAmp = max(cat(3, DJF, MAM, JJA, SON), [], 3) - ...
            min(cat(3, DJF, MAM, JJA, SON), [], 3);

%% OSDMA8 per year (needs Jan(Y)..Mar(Y+1))
osOpts = struct('completeness', opts.osdma8Completeness, ...
    'minMonths', opts.osdma8MinMonths);
osdma8 = nan(nG, nY);
for yi = 1:nY
    slots = nan(nG, 15);
    slots(:, 1:12) = M3(:, :, yi);
    if yi < nY && years(yi+1) == years(yi) + 1
        slots(:, 13:15) = M3(:, 1:3, yi+1);
    end
    osdma8(:, yi) = computeOSDMA8(slots, osOpts);
end

%% Peak month / value (max ignores NaN unless the whole year is NaN)
[peakValue, peakMonth] = max(M3, [], 2);
peakValue = reshape(peakValue, [nG nY]);
peakMonth = reshape(peakMonth, [nG nY]);
peakMonth(isnan(peakValue)) = NaN;

%% Monthly climatology
monthlyClim = reshape(mean(M3, 3, 'omitnan'), [nG 12]);

%% Assemble
M = struct();
M.years        = years(:).';
M.annualMean   = annualMean;
M.osdma8       = osdma8;
M.DJF = DJF; M.MAM = MAM; M.JJA = JJA; M.SON = SON;
M.seasonAmp    = seasonAmp;
M.peakMonth    = peakMonth;
M.peakValue    = peakValue;
M.monthlyClim  = monthlyClim;
M.nValidMonths = nValidMonths;

end

% ========================================================================
function ok = local_selftest()
ok = true;

% One cell, 2 years, fully populated, planted seasonal cycle.
nG = 1;
yrs = [2000 2001];
mon = [];
yr  = [];
tk  = [];
for y = yrs
    for m = 1:12
        yr(end+1) = y; mon(end+1) = m; tk(end+1) = y + (m-1)/12; %#ok<AGROW>
    end
end
% value = month number (so peak month = 12, annual mean = 6.5)
oz = repmat(1:12, 1, 2);

cube = struct('ozone', oz, 'year', yr, 'month', mon, 'time', tk, ...
    'nGrid', nG, 'grid', [0 0]);
M = cubeAnnualMetrics(cube);

assert(isequal(M.years, yrs), 'years');
assert(abs(M.annualMean(1,1) - 6.5) < 1e-9, 'annual mean = 6.5');
assert(M.peakMonth(1,1) == 12 && M.peakValue(1,1) == 12, 'peak month dec');
% JJA = mean(6,7,8) = 7 ; DJF = mean(12,1,2) = 5
assert(abs(M.JJA(1,1) - 7) < 1e-9, 'JJA mean');
assert(abs(M.DJF(1,1) - 5) < 1e-9, 'DJF mean');
% OSDMA8 year 1: best 6-month window mean. With ascending 1..12 then jan-mar of
% next year (1,2,3), the max 6-mo mean is Jul-Dec = mean(7..12)=9.5.
assert(abs(M.osdma8(1,1) - 9.5) < 1e-9, 'osdma8 yr1 = 9.5');
% climatology month 6 = 6 (same both years)
assert(abs(M.monthlyClim(1,6) - 6) < 1e-9, 'clim month 6');

% Multi-cell shape check
nG2 = 5;
oz2 = rand(nG2, 24);
cube2 = struct('ozone', oz2, 'year', yr, 'month', mon, 'time', tk, ...
    'nGrid', nG2, 'grid', zeros(nG2,2));
M2 = cubeAnnualMetrics(cube2);
assert(isequal(size(M2.annualMean), [nG2 2]), 'annualMean shape');
assert(isequal(size(M2.peakMonth), [nG2 2]), 'peakMonth shape');

% NaN handling: blank a cell-year entirely -> NaN metrics, NaN peak month
oz3 = oz2; oz3(2, 1:12) = NaN;
cube3 = cube2; cube3.ozone = oz3;
M3 = cubeAnnualMetrics(cube3);
assert(isnan(M3.annualMean(2,1)) && isnan(M3.peakMonth(2,1)), 'all-NaN year');

fprintf('cubeAnnualMetrics self-test: ALL PASSED.\n');
end
