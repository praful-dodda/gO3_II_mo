function describeBMEcode(BMEcode)
% describeBMEcode - Print human-readable description of BME method code
%
% Displays a formatted description of all parameters encoded in a BME code.
% Useful for understanding what a particular code represents.
%
% SYNTAX:
%   describeBMEcode(BMEcode)
%
% INPUT:
%   BMEcode - String or numeric BME method code
%
% EXAMPLE:
%   describeBMEcode('11000142-23')
%
%   Output:
%   ========================================
%   BME Method Code: 11000142-23
%   ========================================
%   Base Code: 11000142
%   CTM Code:  23
%
%   Observation Data:
%     Type: Hard data only (1)
%
%   Soft Data Configuration:
%     CTM Type: CTM data included (1)
%     Models: MERRA2-GMI, M3fusion, IASI-GOME2
%     RAMP Correction: [0, 0, 0]
%
%   Neighbor Configuration:
%     Soft neighbors (nsmax): 50 (code: 4)
%     Hard neighbors (nhmax): 100 (code: 2)
%
%   BME Algorithm:
%     Type: krigingME (2)
%   ========================================

% Parse the code
[obsType, CTMtype, RAMP, nsmax_code, nhmax_code, BMEtype, CTMmodels, basecode, ctmcode] = parseBMEcode(BMEcode);

% Get actual neighbor counts
nsmax_actual = getCTMneighborCount(nsmax_code);
nhmax_actual = getHardNeighborCount(nhmax_code);

% Print formatted description
fprintf('\n========================================\n');
fprintf('BME Method Code: %s\n', BMEcode);
fprintf('========================================\n');
fprintf('Base Code: %s\n', basecode);
fprintf('CTM Code:  %s\n', ctmcode);
fprintf('\n');

% Observation data
fprintf('Observation Data:\n');
switch obsType
    case 0
        fprintf('  Type: None (0)\n');
    case 1
        fprintf('  Type: Hard data only (1)\n');
    case 2
        fprintf('  Type: Hard + soft data (2)\n');
    otherwise
        fprintf('  Type: Unknown (%d)\n', obsType);
end
fprintf('\n');

% Soft data configuration
fprintf('Soft Data Configuration:\n');
switch CTMtype
    case 0
        fprintf('  CTM Type: No CTM data (0)\n');
    case 1
        fprintf('  CTM Type: CTM data included (1)\n');
    otherwise
        fprintf('  CTM Type: %d\n', CTMtype);
end

if ~isempty(CTMmodels)
    fprintf('  Models: %s\n', strjoin(CTMmodels, ', '));
else
    fprintf('  Models: None\n');
end

if any(RAMP ~= 0)
    fprintf('  RAMP Correction: [%d, %d, %d]\n', RAMP(1), RAMP(2), RAMP(3));
else
    fprintf('  RAMP Correction: None [0, 0, 0]\n');
end
fprintf('\n');

% Neighbor configuration
fprintf('Neighbor Configuration:\n');
fprintf('  Soft neighbors (nsmax): %d (code: %d)\n', nsmax_actual, nsmax_code);
fprintf('  Hard neighbors (nhmax): %d (code: %d)\n', nhmax_actual, nhmax_code);
fprintf('\n');

% BME algorithm
fprintf('BME Algorithm:\n');
switch BMEtype
    case 1
        fprintf('  Type: BMEprobaMoments (1)\n');
        fprintf('  Description: Full BME with probability distributions\n');
    case 2
        fprintf('  Type: krigingME (2)\n');
        fprintf('  Description: Kriging with measurement error (faster)\n');
    otherwise
        fprintf('  Type: Unknown (%d)\n', BMEtype);
end

fprintf('========================================\n\n');

end
