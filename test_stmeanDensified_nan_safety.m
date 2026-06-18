% test_stmeanDensified_nan_safety.m
%
% Sanity check for the NaN-safe Global Offset kernel.
%
% Compares the original kernel  stmeanDensified.m  against the NaN-safe
% variant  stmeanDensified_withNaN.m  on synthetic data that mirrors GO
% scenario 3, to verify:
%   CASE 1  No all-NaN site/month  -> outputs are BIT-FOR-BIT identical
%                                     (proves prior clean runs are unaffected).
%   CASE 2  A fully-missing year (all-NaN month block, e.g. 1989)
%                                  -> original poisons the whole temporal mean
%                                     (mtsd all NaN); NaN-safe stays finite.
%   CASE 3  One all-NaN station    -> original poisons spatial mean near it;
%                                     NaN-safe stays finite.
%
% Run:  matlab -batch test_stmeanDensified_nan_safety

clear; clc;
rng(0);   % deterministic

%% ---- Synthetic inputs mirroring GO scenario 3 -----------------------------
kernParam = [90 2 20 5 0];          % [dNeib ar tNeib at tloop]  (scenario 3)
densParam = [1 1 20 15 1 1/12];     % [voronoi grid nxpix nypix densifytME dt]
axMS      = [-180 180 -60 75];      % global domain

nMS  = 200;                          % stations
lon  = axMS(1) + (axMS(2)-axMS(1))*rand(nMS,1);
lat  = axMS(3) + (axMS(4)-axMS(3))*rand(nMS,1);
sMS  = [lon lat];
idMS = (1:nMS)';

% monthly time grid: 1989, 1990, 1991  (36 months) -- 1989 = the "missing" year
tME  = 1989:(1/12):(1991 + 11/12);
nME  = numel(tME);

% smooth synthetic ozone-like field: latitude gradient + seasonality + noise
latTrend = (40 + 0.2*(lat));                 % nMS x 1
season   = 8*sin(2*pi*(tME - 1989));         % 1  x nME
Zbase    = latTrend + season + 2*randn(nMS,nME);

fprintf('\n========================================================\n');
fprintf('  stmeanDensified NaN-safety sanity check\n');
fprintf('========================================================\n');
fprintf('  stations=%d  months=%d  kernParam=[%g %g %g %g %g]\n', ...
    nMS, nME, kernParam);

passAll = true;

%% ---- CASE 1: no all-NaN row/col -> must be bit-identical -------------------
Z1 = Zbase;
% sprinkle scattered missing values, but guarantee no fully-empty row or column
miss = rand(nME,1) < 0.15;            % within each station, ~15% months missing
for i = 1:nMS
    m = miss & circshift(miss,i);     % vary pattern per station
    if all(m); m(1) = false; end      % never blank an entire row
    Z1(i, m) = NaN;
end
% ensure every month still has >=2 valid stations (no all-NaN column)
for j = 1:nME
    v = find(~isnan(Z1(:,j)));
    if numel(v) < 2
        Z1(1:2, j) = Zbase(1:2, j);
    end
end

[o.ms,o.mssd,o.mt,o.mtsd] = stmeanDensified        (Z1,sMS,idMS,tME,kernParam,densParam,axMS);
[n.ms,n.mssd,n.mt,n.mtsd] = stmeanDensified_withNaN(Z1,sMS,idMS,tME,kernParam,densParam,axMS);

dMssd = maxAbsDiff(o.mssd, n.mssd);
dMtsd = maxAbsDiff(o.mtsd, n.mtsd);
identical = isequaln(o.mssd,n.mssd) && isequaln(o.mtsd,n.mtsd) && dMssd==0 && dMtsd==0;
passAll = passAll && identical;
fprintf('\nCASE 1 (clean / scattered-missing): ');
if identical
    fprintf('PASS - identical (max|diff| mssd=%g, mtsd=%g)\n', dMssd, dMtsd);
else
    fprintf('FAIL - differs (max|diff| mssd=%g, mtsd=%g)\n', dMssd, dMtsd);
end

%% ---- CASE 2: fully-missing year (all-NaN 1989 month block) -----------------
Z2 = Zbase;
Z2(:, tME < 1990) = NaN;             % blank all of 1989 (first 12 months)

[~,~,~,o2_mtsd] = stmeanDensified        (Z2,sMS,idMS,tME,kernParam,densParam,axMS);
[~,~,~,n2_mtsd] = stmeanDensified_withNaN(Z2,sMS,idMS,tME,kernParam,densParam,axMS);

oNaN = nnz(isnan(o2_mtsd));  nTot = numel(o2_mtsd);
nNaN = nnz(isnan(n2_mtsd));
case2 = (oNaN >= 0.9*nTot) && (nNaN == 0);
passAll = passAll && case2;
fprintf('CASE 2 (missing 1989 block):        ');
if case2
    fprintf('PASS - orig mtsd NaN=%d/%d (poisoned), new NaN=%d/%d (finite)\n', ...
        oNaN, nTot, nNaN, nTot);
else
    fprintf('FAIL - orig NaN=%d/%d, new NaN=%d/%d\n', oNaN, nTot, nNaN, nTot);
end

%% ---- CASE 3: one all-NaN station -----------------------------------------
Z3 = Zbase;
Z3(1, :) = NaN;                      % station 1 reports nothing in the window

[~,o3_mssd] = stmeanDensified        (Z3,sMS,idMS,tME,kernParam,densParam,axMS);
[~,n3_mssd] = stmeanDensified_withNaN(Z3,sMS,idMS,tME,kernParam,densParam,axMS);

oSnan = nnz(isnan(o3_mssd));  nSnan = nnz(isnan(n3_mssd));  nSd = numel(o3_mssd);
case3 = (nSnan < oSnan) && (nSnan == 0);
passAll = passAll && case3;
fprintf('CASE 3 (one all-NaN station):       ');
if case3
    fprintf('PASS - orig mssd NaN=%d/%d (poisoned), new NaN=%d/%d (finite)\n', ...
        oSnan, nSd, nSnan, nSd);
else
    fprintf('FAIL - orig NaN=%d/%d, new NaN=%d/%d\n', oSnan, nSd, nSnan, nSd);
end

%% ---- Verdict --------------------------------------------------------------
fprintf('\n--------------------------------------------------------\n');
if passAll
    fprintf('SANITY CHECK: PASS\n');
    fprintf('  - Clean data: NaN-safe kernel is bit-identical to original.\n');
    fprintf('  - Degenerate windows: NaN-safe kernel stays finite where the\n');
    fprintf('    original goes NaN. The change is corrective, not disruptive.\n');
else
    fprintf('SANITY CHECK: FAIL (see cases above)\n');
end
fprintf('========================================================\n\n');

%% ---- helper ---------------------------------------------------------------
function d = maxAbsDiff(a, b)
    % max absolute difference ignoring positions where BOTH are NaN
    both = isnan(a) & isnan(b);
    a(both) = 0; b(both) = 0;
    d = max(abs(a(:) - b(:)));
    if isempty(d); d = 0; end
end
