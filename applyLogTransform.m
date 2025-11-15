function [Y_log, is_valid] = applyLogTransform(Z)
% applyLogTransform - Apply log transformation with safety checks
%
% Applies natural logarithm transformation to concentration data,
% handling non-positive values appropriately
%
% SYNTAX:
%   [Y_log, is_valid] = applyLogTransform(Z)
%
% INPUT:
%   Z - Original concentrations (any dimensions)
%       Can contain positive values, zeros, negative values, or NaN
%
% OUTPUT:
%   Y_log    - Log-transformed values: log(Z)
%              Non-positive values (Z <= 0) are converted to NaN
%              Existing NaN values are preserved as NaN
%   is_valid - Logical mask indicating valid transformed values
%              true where Z > 0, false where Z <= 0 or isnan(Z)
%
% EXAMPLE:
%   Z = [10, 20, 0, -5, NaN, 50];
%   [Y_log, is_valid] = applyLogTransform(Z);
%   % Y_log = [2.30, 3.00, NaN, NaN, NaN, 3.91]
%   % is_valid = [true, true, false, false, false, true]
%
% NOTE:
%   - Uses natural logarithm (base e)
%   - Non-positive values are set to NaN to avoid -Inf or complex results
%   - Preserves original array dimensions

% Input validation
if nargin < 1
    error('applyLogTransform:MissingInput', 'Input Z is required');
end

% Initialize output
Y_log = NaN(size(Z));

% Identify valid values (positive and finite)
is_valid = (Z > 0) & isfinite(Z);

% Apply log transformation only to valid values
Y_log(is_valid) = log(Z(is_valid));

% Report statistics if any invalid values
nTotal = numel(Z);
nInvalid = sum(~is_valid(:));
if nInvalid > 0
    nNegative = sum((Z(:) <= 0) & isfinite(Z(:)));
    nNaN = sum(isnan(Z(:)));

    if nNegative > 0
        warning('applyLogTransform:NonPositiveValues', ...
            'Found %d non-positive values (%.2f%%) - converted to NaN', ...
            nNegative, 100*nNegative/nTotal);
    end
end

end
