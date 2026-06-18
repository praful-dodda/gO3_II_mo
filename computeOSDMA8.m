function [osdma8, winIdx] = computeOSDMA8(monthlyVals, opts)
% computeOSDMA8 - Compute OSDMA8 from monthly MDA8 values
%
% OSDMA8 = the maximum, over all contiguous 6-month windows of monthly MDA8,
% of the within-window mean. Windows start in January and slide through the
% window ending in March of the following year (Jan-Jun ... Oct-Mar), giving
% 10 windows. Computing OSDMA8 for year Y therefore needs the 15 month-slots
% Jan(Y) ... Mar(Y+1).
%
% SYNTAX:
%   osdma8 = computeOSDMA8(monthlyVals)
%   [osdma8, winIdx] = computeOSDMA8(monthlyVals, opts)
%
% INPUTS:
%   monthlyVals - [nStations x 15] matrix of monthly MDA8 values aligned to
%                 month-slots: column 1 = Jan(Y), ..., 12 = Dec(Y),
%                 13 = Jan(Y+1), 14 = Feb(Y+1), 15 = Mar(Y+1). NaN = missing.
%                 A [1 x 15] row vector (single station) is also accepted.
%   opts        - (Optional) struct controlling missing-month handling:
%                   .completeness : 'strict' (default) | 'partial' | 'any'
%                       'strict'  - window valid only if all 6 months present
%                       'partial' - window valid if >= opts.minMonths present
%                                   (mean over available months)
%                       'any'     - nanmean over whatever months exist (>=1)
%                   .minMonths    : threshold for 'partial' (default 4)
%
% OUTPUTS:
%   osdma8 - [nStations x 1] OSDMA8 value per station (NaN if no valid window)
%   winIdx - [nStations x 1] index (1-10) of the window that produced the max
%            (NaN where osdma8 is NaN)
%
% Run computeOSDMA8('--selftest') to execute built-in unit checks.
%
% SEE ALSO: getTOARobservationalData_Yearly, runOSDMA8validation

%% Self-test entry point
if nargin >= 1 && ischar(monthlyVals) && strcmp(monthlyVals, '--selftest')
    osdma8 = local_selftest();
    return;
end

if nargin < 2 || isempty(opts), opts = struct(); end
if ~isfield(opts, 'completeness') || isempty(opts.completeness)
    opts.completeness = 'strict';
end
if ~isfield(opts, 'minMonths') || isempty(opts.minMonths)
    opts.minMonths = 4;
end

% Accept a single-station row vector
if isvector(monthlyVals)
    monthlyVals = monthlyVals(:).';
end

if size(monthlyVals, 2) ~= 15
    error('computeOSDMA8:badInput', ...
        'monthlyVals must have 15 columns (Jan(Y)..Mar(Y+1)); got %d.', ...
        size(monthlyVals, 2));
end

nStations = size(monthlyVals, 1);
nWindows  = 10;                      % windows start at month-slot 1..10
winMeans  = nan(nStations, nWindows);

for s = 1:nWindows
    block   = monthlyVals(:, s:s+5);          % [nStations x 6]
    present = sum(~isnan(block), 2);          % valid months per station

    switch lower(opts.completeness)
        case 'strict'
            valid = (present == 6);
        case 'partial'
            valid = (present >= opts.minMonths);
        case 'any'
            valid = (present >= 1);
        otherwise
            error('computeOSDMA8:badOpt', ...
                'Unknown completeness mode: %s', opts.completeness);
    end

    wm = mean(block, 2, 'omitnan');           % nanmean across the 6 months
    wm(~valid) = NaN;
    winMeans(:, s) = wm;
end

% OSDMA8 = max window mean; capture which window won.
osdma8 = nan(nStations, 1);
winIdx = nan(nStations, 1);
anyValid = any(~isnan(winMeans), 2);
[mx, ix] = max(winMeans, [], 2);              % max ignores NaN unless all NaN
osdma8(anyValid) = mx(anyValid);
winIdx(anyValid) = ix(anyValid);

end

% ------------------------------------------------------------------------
function ok = local_selftest()
% Built-in checks for computeOSDMA8.
ok = true;

% Case 1: full 15-slot series, planted maximum in the May-Oct window.
v = ones(1, 15) * 10;        % baseline 10 everywhere
v(5:10) = 40;               % months 5..10 high -> window starting at slot 5
expected = 40;              % that window's mean
got = computeOSDMA8(v, struct('completeness', 'strict'));
assert_close(got, expected, 'strict full-series max window');

% Case 2: a missing month inside the would-be max window.
% Under 'strict' that window is invalid; under 'any' it still computes.
v2 = v; v2(7) = NaN;
got_strict = computeOSDMA8(v2, struct('completeness','strict'));
% Strict: every window containing slot 7 (starts s=2..7) is invalid. The valid
% windows are s=1 (=20), s=8 (slots 8-13 = [40 40 40 10 10 10] = 25), s=9 (=20),
% s=10 (=15); so the max is 25.
assert_close(got_strict, 25, 'strict drops every window with the missing month');
got_any = computeOSDMA8(v2, struct('completeness','any'));
% 'any': window 5 = mean of [40 40 NaN 40 40 40] = 40
assert_close(got_any, 40, 'any tolerates missing month');

% Case 3: partial threshold.
v3 = nan(1,15); v3(1:4) = 50;   % only 4 of first window present
got_p = computeOSDMA8(v3, struct('completeness','partial','minMonths',4));
assert_close(got_p, 50, 'partial accepts >= minMonths');
got_p_strict = computeOSDMA8(v3, struct('completeness','strict'));
assert(isnan(got_p_strict), 'strict rejects incomplete window');

% Case 4: all NaN -> NaN.
got_nan = computeOSDMA8(nan(1,15));
assert(isnan(got_nan), 'all-NaN returns NaN');

% Case 5: vectorized over stations matches per-row calls.
M = [v; v2; v3];
gv = computeOSDMA8(M, struct('completeness','any'));
for i = 1:3
    gi = computeOSDMA8(M(i,:), struct('completeness','any'));
    assert(isequaln(gv(i), gi), 'vectorized matches per-row');
end

fprintf('computeOSDMA8 self-test: ALL PASSED.\n');

    function assert_close(a, b, msg)
        if abs(a - b) > 1e-9
            ok = false;
            error('computeOSDMA8:selftest', 'FAIL (%s): got %g, expected %g', msg, a, b);
        end
    end
end
