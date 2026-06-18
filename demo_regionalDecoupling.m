function demo_regionalDecoupling(outDir)
% demo_regionalDecoupling - Proof-by-construction that when the POOLED (global)
% R2 change is ~0, the SUB-REGION R2 can still change a lot, with NO forced
% offsetting decreases. Shows the controlling parameter lambda (between-region
% variance fraction) and the attenuation law
%     dR2_global ~ (1-lambda) * (R_global/rho) * dR2_region.
% Uses the project's own calculateValidationStats.m so the numbers are real.

if nargin < 1 || isempty(outDir)
    outDir = fullfile('paper-3-figures','regional_report');
end
if ~exist(outDir,'dir'); mkdir(outDir); end
rng(7);

means = [20 35 50];     % regional mean ozone (well separated)  -> large lambda
sigW  = 4;              % within-region std (small vs separation)
n     = 5000;          % points per region
rho1  = [0.70 0.70 0.70];   % scenario 1 within-region correlations
rho2  = [0.80 0.82 0.81];   % scenario 2: EVERY region improves

[r2_1, r2g_1] = buildScenario(means, sigW, n, rho1);
[r2_2, r2g_2] = buildScenario(means, sigW, n, rho2);

betweenVar = var(repelem(means,1,n), 1);   % population var of expanded region means
lambda = betweenVar / (betweenVar + sigW^2);

fprintf('\n=== Worked example: 3 separated regions, within-region-only improvement ===\n');
fprintf('Region means = [%g %g %g] ppb, within std = %g ppb, n/region = %d\n', means, sigW, n);
fprintf('Between/within variance fraction  lambda = %.4f\n\n', lambda);
fprintf('%-12s %10s %10s %10s\n', 'Region', 'R2 scen1', 'R2 scen2', 'dR2');
rn = {'A (low)','B (mid)','C (high)'};
for r = 1:3
    fprintf('%-12s %10.3f %10.3f %+10.3f\n', rn{r}, r2_1(r), r2_2(r), r2_2(r)-r2_1(r));
end
fprintf('%-12s %10.3f %10.3f %+10.3f   <-- ALL regions up, global barely moves\n', ...
    'GLOBAL', r2g_1, r2g_2, r2g_2-r2g_1);

% attenuation-law check
dR2region = mean(r2_2 - r2_1);
predicted = (1-lambda) * (sqrt(r2g_1)/mean(rho1)) * dR2region;
fprintf('\nAttenuation law:  dR2_global predicted ~ (1-lambda)*(R_g/rho)*dR2_region\n');
fprintf('   regional dR2 (mean) = %+.3f ;  predicted global = %+.4f ;  actual global = %+.4f\n', ...
    dR2region, predicted, r2g_2-r2g_1);

%% ---- Limit curve: sweep separation -> lambda, hold regional gain fixed ----
ks  = linspace(0.0, 3.5, 36);
gm  = mean(means);
dG  = zeros(size(ks)); lam = zeros(size(ks)); dR = zeros(size(ks));
for i = 1:numel(ks)
    m = gm + ks(i)*(means - gm);            % scale the between-region spread
    [a1,g1] = buildScenario(m, sigW, n, rho1);
    [a2,g2] = buildScenario(m, sigW, n, rho2);
    dG(i) = g2 - g1;
    dR(i) = mean(a2 - a1);
    bv = var(repelem(m,1,n), 1);
    lam(i) = bv/(bv + sigW^2);
end

fig = figure('Position',[100 100 920 480],'Visible','off');
plot(lam, dR, 'o-', 'LineWidth',1.6, 'MarkerSize',4); hold on; grid on;
plot(lam, dG, 's-', 'LineWidth',1.6, 'MarkerSize',4);
yline(0,'k:');
xlabel('\lambda  =  between-region variance fraction');
ylabel('\DeltaR^2  (scenario 2 \rightarrow scenario 1)');
legend({'mean regional \DeltaR^2 (stays large & positive)', ...
        'GLOBAL \DeltaR^2 (\rightarrow 0 as \lambda \rightarrow 1)'}, ...
        'Location','northeast');
title('Regional R^2 can rise everywhere while global \DeltaR^2 \rightarrow 0 (no offsets needed)');
exportgraphics(fig, fullfile(outDir,'fig6_decoupling_limit.png'), 'Resolution', 150);
close(fig);
fprintf('\nWrote %s\n', fullfile(outDir,'fig6_decoupling_limit.png'));
end

% ------------------------------------------------------------------------
function [r2reg, r2global] = buildScenario(means, sigW, n, rho)
% Build synthetic obs/est for G regions with prescribed within-region
% correlation rho(r) and region mean means(r); return regional and pooled R2.
G = numel(means);
O = []; E = [];
r2reg = zeros(1,G);
for r = 1:G
    z = randn(n,1);
    w = randn(n,1);
    o = means(r) + sigW*z;
    e = means(r) + sigW*(rho(r)*z + sqrt(1-rho(r)^2)*w);  % corr(o,e)=rho, unbiased
    st = calculateValidationStats(o, e);
    r2reg(r) = st.R2;
    O = [O; o]; E = [E; e]; %#ok<AGROW>
end
stg = calculateValidationStats(O, E);
r2global = stg.R2;
end
