function diagnoseBMEinputs(debugFile)
% diagnoseBMEinputs - Diagnose BME input issues causing singular matrices
%
% SYNTAX:
%   diagnoseBMEinputs('debug_krigingME_time2016.00.mat')
%
% Analyzes saved BME inputs to identify source of singular matrix warnings

if nargin < 1
    % Find most recent debug file
    debugFiles = dir('5BMEspatialPlots/debug/debug_*.mat');
    if isempty(debugFiles)
        error('No debug files found. Run estTOARsBME first with debug code enabled.');
    end
    [~, idx] = max([debugFiles.datenum]);
    debugFile = fullfile(debugFiles(idx).folder, debugFiles(idx).name);
end

fprintf('\n=== BME INPUT DIAGNOSTICS ===\n');
fprintf('Loading: %s\n\n', debugFile);

load(debugFile, 'debug_inputs');
inp = debug_inputs;

%% 1. Check Estimation Points
fprintf('--- ESTIMATION POINTS ---\n');
fprintf('Number of estimation points: %d\n', size(inp.pk, 1));
fprintf('Spatial extent: [%.2f, %.2f] x [%.2f, %.2f]\n', ...
    min(inp.pk(:,1)), max(inp.pk(:,1)), min(inp.pk(:,2)), max(inp.pk(:,2)));
fprintf('Time extent: [%.2f, %.2f]\n', min(inp.pk(:,3)), max(inp.pk(:,3)));

% Check for duplicates
[~, ia, ic] = unique(inp.pk, 'rows');
if length(ia) < size(inp.pk, 1)
    fprintf('WARNING: %d duplicate estimation points!\n', size(inp.pk,1) - length(ia));
end

%% 2. Check Hard Data
if isfield(inp, 'harddata')
    ch = inp.harddata.p;
    zh = inp.harddata.z;
else
    ch = inp.ch;
    zh = inp.zh;
end

fprintf('\n--- HARD DATA ---\n');
fprintf('Number of hard data: %d\n', size(ch, 1));
fprintf('Valid hard data: %d\n', sum(~isnan(zh)));
fprintf('Hard data range: [%.2f, %.2f]\n', min(zh), max(zh));
fprintf('Hard data mean: %.2f\n', mean(zh, 'omitnan'));
fprintf('Hard data std: %.2f\n', std(zh, 'omitnan'));

% Check for duplicates
[uniqueCh, ia, ic] = unique(ch, 'rows');
if length(ia) < size(ch, 1)
    fprintf('WARNING: %d duplicate hard data coordinates!\n', size(ch,1) - length(ia));
    
    % Show duplicates
    dupIdx = setdiff(1:size(ch,1), ia);
    fprintf('  First few duplicates:\n');
    for i = 1:min(5, length(dupIdx))
        idx = dupIdx(i);
        matchIdx = find(ic == ic(idx));
        fprintf('    Point [%.2f, %.2f, %.2f] appears %d times with values: ', ...
            ch(idx,1), ch(idx,2), ch(idx,3), length(matchIdx));
        fprintf('%.2f ', zh(matchIdx));
        fprintf('\n');
    end
end

% Check for near-duplicates (within 0.01 degrees)
fprintf('Checking for near-duplicate coordinates...\n');
dist = pdist2(ch(:,1:2), ch(:,1:2));
dist(logical(eye(size(dist)))) = inf;  % Exclude diagonal
nearDup = sum(dist < 0.01, 2);
if any(nearDup > 0)
    fprintf('WARNING: %d points have neighbors within 0.01 degrees!\n', sum(nearDup > 0));
end

%% 3. Check Covariance Parameters
fprintf('\n--- COVARIANCE PARAMETERS ---\n');
fprintf('Number of models: %d\n', length(inp.covparam));
for i = 1:length(inp.covparam)
    fprintf('  Model %d (%s):\n', i, inp.covmodel{i});
    fprintf('    Parameters: ');
    fprintf('%.2f ', inp.covparam{i});
    fprintf('\n');
    
    % Extract spatial and temporal ranges
    if length(inp.covparam{i}) >= 3
        sill = inp.covparam{i}(1);
        ar = inp.covparam{i}(2);
        at = inp.covparam{i}(3);
        fprintf('    Sill: %.2f, Spatial range: %.2f deg, Temporal range: %.2f yr\n', ...
            sill, ar, at);
        
        if ar > 100
            fprintf('    WARNING: Spatial range very large (%.1f deg)!\n', ar);
        end
        if at > 5
            fprintf('    WARNING: Temporal range very large (%.1f yr)!\n', at);
        end
    end
end

%% 4. Check BME Parameters
fprintf('\n--- BME PARAMETERS ---\n');
fprintf('nhmax: %d\n', inp.nhmax);
fprintf('nsmax: %d\n', inp.nsmax);
fprintf('dmax: [%.1f, %.1f, %.1f]\n', inp.dmax(1), inp.dmax(2), inp.dmax(3));
fprintf('order: %s\n', mat2str(inp.order));

if inp.dmax(1) > 50
    fprintf('WARNING: Spatial search radius very large (%.1f deg)!\n', inp.dmax(1));
end
if inp.dmax(3) > 500
    fprintf('WARNING: Space-time metric very large (%.1f)!\n', inp.dmax(3));
end

%% 5. Test Covariance Matrix
fprintf('\n--- COVARIANCE MATRIX TEST ---\n');
fprintf('Testing covariance matrix condition number...\n');

% Sample 100 hard data points
nTest = min(100, size(ch, 1));
testIdx = randperm(size(ch, 1), nTest);
ch_test = ch(testIdx, :);

% Calculate covariance matrix
K = zeros(nTest, nTest);
for i = 1:nTest
    for j = i:nTest
        % Space-time distance
        dx = ch_test(i,1) - ch_test(j,1);
        dy = ch_test(i,2) - ch_test(j,2);
        dt = ch_test(i,3) - ch_test(j,3);
        
        % Convert to space-time metric
        dr = sqrt(dx^2 + dy^2);
        dst = sqrt(dr^2 + (inp.dmax(3) * dt)^2);
        
        % Sum covariance models
        cov_val = 0;
        for iModel = 1:length(inp.covmodel)
            model = inp.covmodel{iModel};
            params = inp.covparam{iModel};
            
            switch model
                case 'exponentialC'
                    % C(h) = sill * exp(-3*h/range)
                    sill = params(1);
                    range = params(2);
                    cov_val = cov_val + sill * exp(-3*dst/range);
                case 'gaussianC'
                    sill = params(1);
                    range = params(2);
                    cov_val = cov_val + sill * exp(-3*(dst/range)^2);
                otherwise
                    % Add other models as needed
                    cov_val = cov_val + params(1) * exp(-dst/params(2));
            end
        end
        
        K(i,j) = cov_val;
        K(j,i) = cov_val;
    end
end

% Check condition number
rcond_val = rcond(K);
cond_val = cond(K);

fprintf('Condition number: %.2e\n', cond_val);
fprintf('Reciprocal condition: %.2e\n', rcond_val);

if rcond_val < 1e-10
    fprintf('CRITICAL: Matrix is nearly singular! (rcond = %.2e)\n', rcond_val);
    fprintf('Likely causes:\n');
    fprintf('  1. Duplicate or near-duplicate coordinates\n');
    fprintf('  2. Covariance range parameters too large\n');
    fprintf('  3. Too many neighbors (nhmax too high)\n');
elseif rcond_val < 1e-6
    fprintf('WARNING: Matrix is poorly conditioned (rcond = %.2e)\n', rcond_val);
else
    fprintf('OK: Matrix condition acceptable\n');
end

% Check eigenvalues
eigvals = eig(K);
fprintf('Eigenvalue range: [%.2e, %.2e]\n', min(eigvals), max(eigvals));
fprintf('Number of near-zero eigenvalues (< 1e-10): %d\n', sum(abs(eigvals) < 1e-10));

%% 6. Recommendations
fprintf('\n--- RECOMMENDATIONS ---\n');

hasIssue = false;

if any(nearDup > 0)
    fprintf('1. Remove duplicate/near-duplicate coordinates\n');
    hasIssue = true;
end

if any(cellfun(@(x) x(2) > 50, inp.covparam))
    fprintf('2. Reduce spatial range in covariance (cap at 50 degrees)\n');
    hasIssue = true;
end

if inp.dmax(1) > 30
    fprintf('3. Reduce spatial search radius (try dmax(1) = 20)\n');
    hasIssue = true;
end

if inp.nhmax > 100
    fprintf('4. Reduce nhmax (try nhmax = 50)\n');
    hasIssue = true;
end

if rcond_val < 1e-10
    fprintf('5. Add nugget effect to covariance (small variance at h=0)\n');
    hasIssue = true;
end

if ~hasIssue
    fprintf('No obvious issues detected. Problem may be in krigingME implementation.\n');
end

fprintf('\n=== END DIAGNOSTICS ===\n\n');

end