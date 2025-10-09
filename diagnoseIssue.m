function diagnoseIssue(obs, go, cov, KS)
    fprintf('\n=== COMPREHENSIVE DIAGNOSTIC ===\n');
    
    % Data
    fprintf('1. OBS DATA:\n');
    fprintf('   Range: [%.2f, %.2f] ppb\n', min(obs.Y(:)), max(obs.Y(:)));
    
    % Global offset
    fprintf('2. GLOBAL OFFSET:\n');
    testGO = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, obs.sMS(1,:), obs.tME(1));
    fprintf('   Sample GO: %.2f ppb\n', testGO);
    
    % Covariance
    fprintf('3. COVARIANCE:\n');
    fprintf('   Variance: %.2f, STmetric: %.2f\n', cov.var, cov.stmetric);
    
    % Residuals
    fprintf('4. RESIDUALS:\n');
    fprintf('   Range: [%.2f, %.2f]\n', min(KS.harddata.z), max(KS.harddata.z));
    
    % Check for issues
    if abs(testGO) > 1000, warning('GO values too large!'); end
    if cov.stmetric > 1000, warning('STmetric too large!'); end
    if max(abs(KS.harddata.z)) > 100, warning('Residuals too large!'); end
end