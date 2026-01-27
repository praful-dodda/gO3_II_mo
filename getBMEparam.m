function BMEparam = getBMEparam(BMEmethod8digits, stmetric, dataFormat)
% getBMEparam - Get BME estimation parameters from method code
%
% SYNTAX:
%   BMEparam = getBMEparam(BMEmethod8digits, stmetric, dataFormat)
%
% INPUTS:
%   BMEmethod8digits - 8-digit BME method code
%   stmetric         - Space-time metric from covariance
%   dataFormat       - Data format: 'stv', 'stg', or 'stug' (optional, default 'stg')
%
% OUTPUT:
%   BMEparam - Structure with BME parameters:
%              .nhmax, .nsmax, .order, .dmax, .options, .dataFormat

if nargin < 2
    stmetric = 100;
end

if nargin < 3
    dataFormat = 'stg';  % Default to space-time grid
end

% if the input is numeric, convert to string
if isnumeric(BMEmethod8digits)
    BMEmethodStr = num2str(BMEmethod8digits);
elseif ischar(BMEmethod8digits)
    BMEmethodStr = BMEmethod8digits;
else
    error('BMEmethod8digits must be a numeric or string input');
end

% Parse method code
[~, ~, ~, BMEnsmax, BMEnhmax, BMEprobaType, CTMmodels] = parseBMEcode(BMEmethodStr);

% BMEnsmax = str2double(BMEmethodStr(6));
% BMEnhmax = str2double(BMEmethodStr(7));
% BMEprobaType = str2double(BMEmethodStr(8));

% Set nhmax
switch BMEnhmax
    case 1, BMEparam.nhmax = 50;
    case 2, BMEparam.nhmax = 100;
    case 3, BMEparam.nhmax = 200;
    otherwise, error('BMEnhmax (digit 7) must be 1, 2, or 3');
end

% Set nsmax
switch BMEnsmax
    case 0, BMEparam.nsmax = 0;   % No soft data
    case 1, BMEparam.nsmax = 3;
    case 2, BMEparam.nsmax = 4;
    case 3, BMEparam.nsmax = 10;
    case 4, BMEparam.nsmax = 50;
    case 5, BMEparam.nsmax = 100;
    case 6, BMEparam.nsmax = 200;
    otherwise, error('BMEnsmax (digit 6) must be 0-6');
end

% Set order
switch BMEprobaType
    case 1 
        BMEparam.order = NaN;  % Zero mean
    case 2 
        BMEparam.order = NaN;    % Zero mean
    case 3
        BMEparam.order = NaN;    % Zero mean with multiple softdatasets
        dataFormat = 'stug';
    otherwise, error('BMEprobaType (digit 8) must be 1 or 2');
end

% Set search parameters
% dmax(1) = spatial search radius (degrees)
% dmax(2) = temporal search radius (years)
% dmax(3) = space-time metric
%
% Optimized for regional analysis: 20° spatial (~2200 km), 0.5 yr temporal (~6 months)
BMEparam.dmax = [20, 0.5, min(stmetric, 50)];  % Regional search radius

% BME integration options
maxpts = 500000;     % Number of function evaluations
rEps = 0.05;         % Relative numerical error
nMom = 2;            % Calculate mean and variance

BMEparam.options = BMEoptions;
BMEparam.options(1) = 0;        % Display level
BMEparam.options(3) = maxpts;
BMEparam.options(4) = rEps;
BMEparam.options(8) = nMom;

BMEparam.BMEmethod8digits = BMEmethod8digits;
BMEparam.dataFormat = dataFormat;

if ~isempty(CTMmodels)
    BMEparam.CTMmodels = CTMmodels;
end

end