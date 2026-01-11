function [models, modelIndices] = decodeCTMmodels(bitmask_hex)
% decodeCTMmodels - Decode CTM model bitmask to list of model names
%
% Decodes a hexadecimal bitmask into the list of CTM models it represents.
% This is the inverse operation of the bitmask encoding in generateBMEcode.
%
% SYNTAX:
%   [models, modelIndices] = decodeCTMmodels(bitmask_hex)
%
% INPUT:
%   bitmask_hex  - String, hexadecimal representation of bitmask (e.g., '01', '23', '3F')
%                  OR numeric bitmask value (e.g., 1, 35, 63)
%
% OUTPUT:
%   models       - Cell array of model names included in the bitmask
%   modelIndices - Numeric array of model bit positions (0-5)
%
% MODEL ENCODING:
%   Bit Position   Value (hex)   Model Name
%   0              01            MERRA2-GMI
%   1              02            M3fusion
%   2              04            OMI-MLS
%   3              08            IASI-GOME2
%   4              10            UKML
%   5              20            NJML
%
% EXAMPLES:
%   models = decodeCTMmodels('01')
%   % → {'MERRA2-GMI'}
%
%   models = decodeCTMmodels('03')
%   % → {'MERRA2-GMI', 'M3fusion'}
%
%   models = decodeCTMmodels('23')
%   % → {'MERRA2-GMI', 'M3fusion', 'IASI-GOME2'}
%
%   models = decodeCTMmodels('3F')
%   % → {'MERRA2-GMI', 'M3fusion', 'OMI-MLS', 'IASI-GOME2', 'UKML', 'NJML'}
%
%   [models, indices] = decodeCTMmodels(35)  % 35 = 0x23
%   % → models = {'MERRA2-GMI', 'M3fusion', 'IASI-GOME2'}
%   % → indices = [0, 1, 3]

% Convert hex string to numeric if needed
if ischar(bitmask_hex) || isstring(bitmask_hex)
    bitmask = hex2dec(bitmask_hex);
else
    bitmask = bitmask_hex;
end

% Model names and their bit positions (must match generateBMEcode)
modelNames = {'MERRA2-GMI', 'M3fusion', 'OMI-MLS', 'IASI-GOME2', 'UKML', 'NJML'};
modelBits = [1, 2, 4, 8, 16, 32];  % 2^0, 2^1, 2^2, 2^3, 2^4, 2^5

% Decode bitmask
models = {};
modelIndices = [];

for i = 1:length(modelNames)
    if bitand(bitmask, modelBits(i)) ~= 0
        models{end+1} = modelNames{i};
        modelIndices(end+1) = i-1;  % 0-indexed bit position
    end
end

% Convert to column cell array if needed for consistency
if ~isempty(models) && size(models, 1) == 1
    models = models';
end
end
