function compareBMEcodes(varargin)
% compareBMEcodes - Compare multiple BME method codes side-by-side
%
% Displays a side-by-side comparison of multiple BME codes to easily
% identify differences in configuration.
%
% SYNTAX:
%   compareBMEcodes(code1, code2, ...)
%
% INPUT:
%   varargin - Variable number of BME codes (strings or numeric)
%
% EXAMPLE:
%   compareBMEcodes('10000132', '11000142-01', '11000162-23')
%
%   Output:
%   ========================================
%   BME Code Comparison
%   ========================================
%   Code 1: 10000132
%   Code 2: 11000142-01
%   Code 3: 11000162-23
%   ----------------------------------------
%   Parameter          Code 1    Code 2    Code 3
%   ----------------------------------------
%   Obs Type           1         1         1
%   CTM Type           0         1         1
%   RAMP               [0 0 0]   [0 0 0]   [0 0 0]
%   nsmax (code)       1         4         6
%   nsmax (actual)     3         50        200
%   nhmax (code)       3         2         2
%   nhmax (actual)     200       100       100
%   BME Type           2         2         2
%   CTM Models         -         MERRA2    MERRA2+M3+IASI
%   ========================================

if nargin < 2
    error('At least 2 BME codes are required for comparison');
end

ncodes = nargin;

% Parse all codes
obsTypes = zeros(1, ncodes);
CTMtypes = zeros(1, ncodes);
RAMPs = zeros(ncodes, 3);
nsmax_codes = zeros(1, ncodes);
nhmax_codes = zeros(1, ncodes);
BMEtypes = zeros(1, ncodes);
CTMmodels_list = cell(1, ncodes);
basecodes = cell(1, ncodes);
ctmcodes = cell(1, ncodes);

for i = 1:ncodes
    [obsTypes(i), CTMtypes(i), RAMPs(i,:), nsmax_codes(i), nhmax_codes(i), ...
     BMEtypes(i), CTMmodels_list{i}, basecodes{i}, ctmcodes{i}] = parseBMEcode(varargin{i});
end

% Get actual neighbor counts
nsmax_actual = arrayfun(@getCTMneighborCount, nsmax_codes);
nhmax_actual = arrayfun(@getHardNeighborCount, nhmax_codes);

% Print comparison
fprintf('\n========================================\n');
fprintf('BME Code Comparison\n');
fprintf('========================================\n');
for i = 1:ncodes
    fprintf('Code %d: %s\n', i, varargin{i});
end
fprintf('----------------------------------------\n');

% Header
fprintf('%-18s', 'Parameter');
for i = 1:ncodes
    fprintf('  %-12s', sprintf('Code %d', i));
end
fprintf('\n');
fprintf('----------------------------------------\n');

% Obs Type
fprintf('%-18s', 'Obs Type');
for i = 1:ncodes
    fprintf('  %-12d', obsTypes(i));
end
fprintf('\n');

% CTM Type
fprintf('%-18s', 'CTM Type');
for i = 1:ncodes
    fprintf('  %-12d', CTMtypes(i));
end
fprintf('\n');

% RAMP
fprintf('%-18s', 'RAMP');
for i = 1:ncodes
    rampstr = sprintf('[%d %d %d]', RAMPs(i,1), RAMPs(i,2), RAMPs(i,3));
    fprintf('  %-12s', rampstr);
end
fprintf('\n');

% nsmax code
fprintf('%-18s', 'nsmax (code)');
for i = 1:ncodes
    fprintf('  %-12d', nsmax_codes(i));
end
fprintf('\n');

% nsmax actual
fprintf('%-18s', 'nsmax (actual)');
for i = 1:ncodes
    fprintf('  %-12d', nsmax_actual(i));
end
fprintf('\n');

% nhmax code
fprintf('%-18s', 'nhmax (code)');
for i = 1:ncodes
    fprintf('  %-12d', nhmax_codes(i));
end
fprintf('\n');

% nhmax actual
fprintf('%-18s', 'nhmax (actual)');
for i = 1:ncodes
    fprintf('  %-12d', nhmax_actual(i));
end
fprintf('\n');

% BME Type
fprintf('%-18s', 'BME Type');
for i = 1:ncodes
    fprintf('  %-12d', BMEtypes(i));
end
fprintf('\n');

% CTM Models (this might be long, so handle carefully)
fprintf('%-18s', 'CTM Models');
for i = 1:ncodes
    if isempty(CTMmodels_list{i})
        fprintf('  %-12s', '-');
    else
        % Abbreviate if too long
        modelstr = strjoin(CTMmodels_list{i}, '+');
        modelstr = strrep(modelstr, 'MERRA2-GMI', 'MERRA2');
        modelstr = strrep(modelstr, 'M3fusion', 'M3');
        modelstr = strrep(modelstr, 'OMI-MLS', 'OMI');
        modelstr = strrep(modelstr, 'IASI-GOME2', 'IASI');
        if length(modelstr) > 12
            modelstr = [modelstr(1:9) '...'];
        end
        fprintf('  %-12s', modelstr);
    end
end
fprintf('\n');

fprintf('========================================\n\n');

end
