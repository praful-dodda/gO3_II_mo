function [obsType, CTMtype, RAMP, nsmax, nhmax, BMEtype, CTMmodels, basecode, ctmcode] = parseBMEcode(BMEcode)
% parseBMEcode - Parse extended BME method code
%
% Parses an extended 10-character BME code into its constituent parts.
% Handles both legacy 8-digit codes and new extended format with CTM bitmask.
%
% SYNTAX:
%   [obsType, CTMtype, RAMP, nsmax, nhmax, BMEtype, CTMmodels] = parseBMEcode(BMEcode)
%   [obsType, CTMtype, RAMP, nsmax, nhmax, BMEtype, CTMmodels, basecode, ctmcode] = parseBMEcode(BMEcode)
%
% INPUT:
%   BMEcode - String, BME method code
%             Legacy format (8 digits): '10000132'
%             Extended format (11 chars): '10000132-01'
%
% OUTPUT:
%   obsType    - Observation type (0=none, 1=hard only, 2=hard+soft)
%   CTMtype    - CTM type (0=none, 1=CTM data)
%   RAMP       - 3-element vector of RAMP correction parameters
%   nsmax      - Soft data neighbor code (0-6)
%   nhmax      - Hard data neighbor code (1-3)
%   BMEtype    - BME algorithm type (1=BMEprobaMoments, 2=krigingME)
%   CTMmodels  - Cell array of CTM model names (empty for legacy codes)
%   basecode   - Base 8-digit code (optional output)
%   ctmcode    - CTM bitmask hex code (optional output, '00' for legacy)
%
% NEIGHBOR DECODING:
%   nsmax: 0=0, 1=3, 2=4, 3=10, 4=50, 5=100, 6=200
%   nhmax: 1=50, 2=100, 3=200
%
% EXAMPLES:
%   % Legacy code
%   [obsType, CTMtype, RAMP, nsmax, nhmax, BMEtype] = parseBMEcode('10000132')
%   % → obsType=1, CTMtype=0, RAMP=[0 0 0], nsmax=1, nhmax=3, BMEtype=2
%   % → CTMmodels = {}
%
%   % Extended code
%   [~, ~, ~, ~, ~, ~, models] = parseBMEcode('11000142-23')
%   % → models = {'MERRA2-GMI', 'M3fusion', 'IASI-GOME2'}
%
%   % Get all outputs
%   [obsType, CTMtype, RAMP, nsmax, nhmax, BMEtype, models, base, ctm] = parseBMEcode('11000162-3F')
%   % → base = '11000162'
%   % → ctm = '3F'
%   % → models = {'MERRA2-GMI', 'M3fusion', 'OMI-MLS', 'IASI-GOME2', 'UKML', 'NJML'}

% Input validation
if nargin < 1 || isempty(BMEcode)
    error('BMEcode is required');
end

% Convert to string if numeric
if isnumeric(BMEcode)
    BMEcode = num2str(BMEcode);
end

% Remove any whitespace
BMEcode = strtrim(BMEcode);

% Check for extended format (contains '-')
if contains(BMEcode, '-')
    % Extended format: split at '-'
    parts = strsplit(BMEcode, '-');
    basecode = parts{1};
    ctmcode = parts{2};

    % Validate base code is 8 digits
    if length(basecode) ~= 8
        error('Base code must be 8 digits, got %d: %s', length(basecode), basecode);
    end

    % Validate CTM code is valid hex
    if ~all(ismember(upper(ctmcode), '0123456789ABCDEF'))
        error('CTM code must be hexadecimal, got: %s', ctmcode);
    end

    % Decode CTM models
    CTMmodels = decodeCTMmodels(ctmcode);
else
    % Legacy format: 8 digits only
    basecode = BMEcode;
    ctmcode = '00';
    CTMmodels = {};

    % Validate is 8 digits
    if length(basecode) ~= 8
        error('Legacy code must be 8 digits, got %d: %s', length(basecode), basecode);
    end
end

% Parse base 8-digit code
% Format: [obsType][CTMtype][RAMP1][RAMP2][RAMP3][nsmax][nhmax][BMEtype]
obsType = str2double(basecode(1));
CTMtype = str2double(basecode(2));
RAMP = [str2double(basecode(3)), str2double(basecode(4)), str2double(basecode(5))];
nsmax = str2double(basecode(6));
nhmax = str2double(basecode(7));
BMEtype = str2double(basecode(8));

% Validate parsed values
if any(isnan([obsType, CTMtype, RAMP, nsmax, nhmax, BMEtype]))
    error('Invalid BME code - contains non-numeric characters: %s', basecode);
end

% Range validation
if obsType < 0 || obsType > 2
    warning('obsType out of expected range [0-2]: %d', obsType);
end

if CTMtype < 0 || CTMtype > 9
    warning('CTMtype out of expected range [0-9]: %d', CTMtype);
end

if any(RAMP < 0) || any(RAMP > 9)
    warning('RAMP values out of expected range [0-9]');
end

if nsmax < 0 || nsmax > 6
    warning('nsmax out of expected range [0-6]: %d', nsmax);
end

if nhmax < 1 || nhmax > 3
    warning('nhmax out of expected range [1-3]: %d', nhmax);
end

if BMEtype < 1 || BMEtype > 3
    warning('BMEtype out of expected range [1-3]: %d', BMEtype);
end

% Consistency check: if CTMmodels specified but CTMtype=0
if ~isempty(CTMmodels) && CTMtype == 0
    warning('CTM models specified but CTMtype=0. Consider setting CTMtype=1');
end

% Consistency check: if CTMtype=1 but no models specified
if CTMtype == 1 && isempty(CTMmodels)
    warning('CTMtype=1 but no CTM models specified in extended code');
end

end
