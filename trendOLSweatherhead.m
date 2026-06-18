function out = trendOLSweatherhead(t, y)
% trendOLSweatherhead - OLS linear trend with AR(1)-adjusted significance
%
% Ordinary-least-squares trend plus the autocorrelation correction of
% Weatherhead et al. (1998, JGR 103:17149) - the standard time-series trend
% detection used in ozone trend studies (incl. the Serre/West / DeLang-Becker
% global ozone work). The white-noise OLS standard error is inflated by the
% lag-1 autocorrelation of the residuals, giving an adjusted p-value and the
% number of years needed to detect the trend (n*).
%
% SYNTAX:
%   out = trendOLSweatherhead(t, y)
%
% INPUTS:
%   t - vector of times (years). Same length as y.
%   y - vector of values (may contain NaN; NaN pairs dropped).
%
% OUTPUT (struct):
%   out.slope         OLS slope (y-units per t-unit)
%   out.slopePerDecade  slope*10
%   out.intercept     OLS intercept
%   out.seWhite       white-noise OLS slope standard error
%   out.se            AR(1)-adjusted slope standard error
%   out.phi           lag-1 autocorrelation of OLS residuals
%   out.z             slope / se
%   out.pValue        two-sided p-value (normal approx) using the adjusted se
%   out.n             number of valid points
%   out.sigmaN        residual standard deviation
%   out.nStar         years to detect the observed trend (90% power, 5% sig)
%
% Run trendOLSweatherhead('--selftest') to execute built-in unit checks.
%
% SEE ALSO: trendSenMK, trendAnalysisDeLang

%% Self-test entry point
if nargin >= 1 && (ischar(t) || isstring(t)) && strcmp(t, '--selftest')
    out = local_selftest();
    return;
end

t = t(:); y = y(:);
if numel(t) ~= numel(y)
    error('trendOLSweatherhead:size', 't and y must have the same length.');
end
ok = ~isnan(t) & ~isnan(y);
t = t(ok); y = y(ok);
n = numel(y);

out = struct('slope', NaN, 'slopePerDecade', NaN, 'intercept', NaN, ...
    'seWhite', NaN, 'se', NaN, 'phi', NaN, 'z', NaN, 'pValue', NaN, ...
    'n', n, 'sigmaN', NaN, 'nStar', NaN);
if n < 4
    return;
end

% --- OLS fit ---
tbar = mean(t); ybar = mean(y);
Sxx = sum((t - tbar).^2);
if Sxx == 0, return; end
slope = sum((t - tbar) .* (y - ybar)) / Sxx;
intercept = ybar - slope * tbar;
resid = y - (intercept + slope * t);

% residual SD (use n-2 dof for the regression)
sigmaN = sqrt(sum(resid.^2) / max(n - 2, 1));
seWhite = sigmaN / sqrt(Sxx);

% --- lag-1 autocorrelation of residuals ---
denom = sum(resid.^2);
if denom > 0
    phi = sum(resid(2:end) .* resid(1:end-1)) / denom;
else
    phi = 0;
end
phiPos = min(max(phi, 0), 0.99);          % Weatherhead correction assumes phi>=0
infl = sqrt((1 + phiPos) / (1 - phiPos));

se = seWhite * infl;
z = slope / se;
pValue = erfc(abs(z) / sqrt(2));          % two-sided normal approximation

% --- years to detect the observed trend (Weatherhead 1998, eq. 2) ---
if abs(slope) > 0 && sigmaN > 0
    nStar = ((3.3 * sigmaN / abs(slope)) * infl) ^ (2/3);
else
    nStar = NaN;
end

out.slope = slope; out.slopePerDecade = slope * 10; out.intercept = intercept;
out.seWhite = seWhite; out.se = se; out.phi = phi; out.z = z; out.pValue = pValue;
out.n = n; out.sigmaN = sigmaN; out.nStar = nStar;

end

% ========================================================================
function ok = local_selftest()
ok = true;

% Case 1: perfect line y = 5 + 3t -> slope 3, residuals 0, p tiny.
t = (0:20)';
r = trendOLSweatherhead(t, 5 + 3*t);
assert_close(r.slope, 3, 'perfect slope');
assert_close(r.intercept, 5, 'perfect intercept');
assert(r.sigmaN < 1e-9, 'zero residuals');
assert(r.pValue < 1e-6, 'perfect trend significant');

% Case 2: flat + small white noise -> ~0 slope, not significant, phi small.
rng(1); y2 = 50 + 0.5*randn(size(t));
r2 = trendOLSweatherhead(t, y2);
assert(abs(r2.slope) < 0.2, 'flat slope ~0');
assert(r2.pValue > 0.1, 'flat not significant');

% Case 3: AR(1) inflation - positively autocorrelated residuals widen se.
rng(2); n = 60; tt = (1:n)';
e = zeros(n,1); for k = 2:n, e(k) = 0.8*e(k-1) + randn; end
y3 = 10 + 0.05*tt + e;                 % weak trend on strongly autocorrelated noise
r3 = trendOLSweatherhead(tt, y3);
assert(r3.phi > 0.4, 'detects positive autocorrelation');
assert(r3.se > r3.seWhite, 'adjusted se exceeds white-noise se');
assert(r3.nStar > 0 && isfinite(r3.nStar), 'finite years-to-detect');

% Case 4: slopePerDecade and NaN handling.
t4 = (0:10)'; y4 = 2*t4; y4([3 7]) = NaN;
r4 = trendOLSweatherhead(t4, y4);
assert_close(r4.slope, 2, 'slope with NaNs');
assert_close(r4.slopePerDecade, 20, 'slope per decade');
assert(r4.n == 9, 'n excludes NaN');

% Case 5: < 4 points -> NaN.
r5 = trendOLSweatherhead([1 2 3]', [1 2 3]');
assert(isnan(r5.slope), 'too few points');

fprintf('trendOLSweatherhead self-test: ALL PASSED.\n');

    function assert_close(a, b, msg)
        if isnan(a) || abs(a-b) > 1e-6
            ok = false;
            error('trendOLSweatherhead:selftest', 'FAIL (%s): got %g, expected %g', msg, a, b);
        end
    end
end
