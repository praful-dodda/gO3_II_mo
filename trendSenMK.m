function out = trendSenMK(t, y)
% trendSenMK - Robust linear trend: Theil-Sen slope + Mann-Kendall test
%
% Non-parametric trend estimation used throughout the post-processing
% (annual/seasonal/peak/exposure analyses). The Sen slope is the median of
% all pairwise slopes; the Mann-Kendall test gives a tie-corrected two-sided
% p-value via the normal approximation. NaN-safe: NaN pairs are dropped.
%
% SYNTAX:
%   out = trendSenMK(t, y)
%
% INPUTS:
%   t - vector of times (e.g. years). Same length as y.
%   y - vector of values (may contain NaN).
%
% OUTPUT (struct):
%   out.slope      - Sen slope in y-units per t-unit (NaN if < 3 valid points)
%   out.intercept  - median(y) - slope*median(t)  (for drawing the line)
%   out.pValue     - Mann-Kendall two-sided p-value (NaN if < 3 points)
%   out.S          - Mann-Kendall S statistic
%   out.z          - MK normal-approximation z score
%   out.n          - number of valid (non-NaN) points used
%   out.slopeLo    - 95% CI lower bound on the slope (Sen CI; NaN if n<4)
%   out.slopeHi    - 95% CI upper bound on the slope
%
% Run trendSenMK('--selftest') to execute built-in unit checks.
%
% SEE ALSO: trendMaps, annualSeasonalSeries, peakMonthAnalysis

%% Self-test entry point
if nargin >= 1 && ischar(t) && strcmp(t, '--selftest')
    out = local_selftest();
    return;
end

t = t(:);
y = y(:);
if numel(t) ~= numel(y)
    error('trendSenMK:size', 't and y must have the same length.');
end

ok = ~isnan(t) & ~isnan(y);
t = t(ok);
y = y(ok);
n = numel(y);

out = struct('slope', NaN, 'intercept', NaN, 'pValue', NaN, ...
    'S', NaN, 'z', NaN, 'n', n, 'slopeLo', NaN, 'slopeHi', NaN);

if n < 3
    return;
end

% --- Pairwise slopes (Theil-Sen) ---
[ii, jj] = find(triu(true(n), 1));     % all i<j pairs
dt = t(jj) - t(ii);
dy = y(jj) - y(ii);
good = dt ~= 0;
slopes = dy(good) ./ dt(good);
out.slope = median(slopes);
out.intercept = median(y) - out.slope * median(t);

% --- Mann-Kendall S and tie-corrected variance ---
S = sum(sign(dy));                      % sum of sign(y_j - y_i), i<j
out.S = S;

% tie correction: groups of equal y values
uy = unique(y);
tieTerm = 0;
if numel(uy) < n
    for k = 1:numel(uy)
        tp = sum(y == uy(k));
        if tp > 1
            tieTerm = tieTerm + tp*(tp-1)*(2*tp+5);
        end
    end
end
varS = (n*(n-1)*(2*n+5) - tieTerm) / 18;

if varS <= 0
    out.z = 0;
    out.pValue = 1;
else
    if S > 0
        z = (S - 1) / sqrt(varS);
    elseif S < 0
        z = (S + 1) / sqrt(varS);
    else
        z = 0;
    end
    out.z = z;
    % two-sided p = 2*(1 - Phi(|z|)) = erfc(|z|/sqrt(2))
    out.pValue = erfc(abs(z) / sqrt(2));
end

% --- Sen 95% confidence interval on the slope ---
if n >= 4 && varS > 0
    sortedSlopes = sort(slopes);
    nPrime = numel(sortedSlopes);
    cAlpha = 1.959963984540054 * sqrt(varS);   % z_{0.975}
    mLo = (nPrime - cAlpha) / 2;
    mHi = (nPrime + cAlpha) / 2;
    loIdx = floor(mLo);
    hiIdx = ceil(mHi) + 1;
    if loIdx >= 1 && hiIdx <= nPrime
        out.slopeLo = sortedSlopes(loIdx);
        out.slopeHi = sortedSlopes(hiIdx);
    end
end

end

% ------------------------------------------------------------------------
function ok = local_selftest()
ok = true;

% Case 1: perfect positive line y = 2 + 3t -> slope 3, p small.
t = (0:10)';
y = 2 + 3*t;
r = trendSenMK(t, y);
assert_close(r.slope, 3, 'perfect slope');
assert_close(r.intercept, 2, 'perfect intercept');
assert(r.pValue < 0.01, 'perfect trend significant');

% Case 2: flat series -> slope 0, not significant.
r2 = trendSenMK(t, ones(size(t)));
assert_close(r2.slope, 0, 'flat slope');
assert(r2.pValue > 0.5, 'flat not significant');

% Case 3: robust to an outlier (Sen median ignores one bad point).
y3 = 3*t; y3(6) = 1000;
r3 = trendSenMK(t, y3);
assert(abs(r3.slope - 3) < 0.5, 'sen robust to outlier');

% Case 4: NaN handling - drop NaNs, still recover slope.
y4 = 2 + 3*t; y4([2 5 9]) = NaN;
r4 = trendSenMK(t, y4);
assert_close(r4.slope, 3, 'slope with NaNs');
assert(r4.n == 8, 'n excludes NaNs');

% Case 5: < 3 points -> NaN slope.
r5 = trendSenMK([1 2]', [3 4]');
assert(isnan(r5.slope), 'too few points -> NaN');

% Case 6: negative trend -> negative z and slope.
r6 = trendSenMK(t, -2*t);
assert(r6.slope < 0 && r6.z < 0, 'negative trend sign');

fprintf('trendSenMK self-test: ALL PASSED.\n');

    function assert_close(a, b, msg)
        if isnan(a) || abs(a - b) > 1e-9
            ok = false;
            error('trendSenMK:selftest', 'FAIL (%s): got %g, expected %g', msg, a, b);
        end
    end
end
