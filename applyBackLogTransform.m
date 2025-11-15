function [Z, Z_var] = applyBackLogTransform(Y_log, Y_var, method)
% applyBackLogTransform - Apply back log transformation (exponential)
%
% Converts log-transformed values back to original concentration scale
% using exponential function, with optional variance transformation
%
% SYNTAX:
%   [Z, Z_var] = applyBackLogTransform(Y_log, Y_var, method)
%
% INPUT:
%   Y_log  - Log-transformed values (any dimensions)
%            Y_log = log(Z), where Z is original concentration
%   Y_var  - Variance in log space (optional, same size as Y_log)
%            If empty or not provided, only mean is back-transformed
%            default: []
%   method - Transformation method for mean (optional)
%            'simple'          : Z = exp(Y_log)  [default]
%            'bias_corrected'  : Z = exp(Y_log + Y_var/2)  [lognormal mean]
%            default: 'simple'
%
% OUTPUT:
%   Z     - Back-transformed concentrations: exp(Y_log)
%           Preserves NaN values from Y_log
%   Z_var - Variance in original space (if Y_var provided)
%           Using delta method: Var(Z) ≈ exp(2*Y_log) * Var(Y_log)
%           Empty if Y_var not provided
%
% METHODS:
%   'simple': Direct exponential transformation
%             Best for predictions at specific locations
%             Z = exp(Y_log)
%
%   'bias_corrected': Accounts for Jensen's inequality
%                     Best for computing expected values
%                     For lognormal: E[Z] = exp(μ + σ²/2)
%                     Z = exp(Y_log + Y_var/2)
%
% VARIANCE TRANSFORMATION:
%   Uses first-order Taylor expansion (delta method):
%   If Y = log(Z), then dZ/dY = exp(Y) = Z
%   Var(Z) ≈ [dZ/dY]² * Var(Y) = exp(2*Y) * Var(Y)
%
% EXAMPLE:
%   % Simple back-transformation
%   Y_log = [2.3, 3.0, NaN, 3.9];
%   Z = applyBackLogTransform(Y_log);
%   % Z = [10.0, 20.1, NaN, 49.4]
%
%   % With variance transformation
%   Y_log = 3.0;
%   Y_var = 0.1;
%   [Z, Z_var] = applyBackLogTransform(Y_log, Y_var);
%   % Z = 20.09, Z_var = 80.7
%
%   % Bias-corrected mean
%   [Z_bc, ~] = applyBackLogTransform(Y_log, Y_var, 'bias_corrected');
%   % Z_bc = 21.03 (higher due to bias correction)
%
% NOTE:
%   - Preserves NaN values in input
%   - Variance transformation assumes small to moderate variance
%   - For large variances, higher-order corrections may be needed

% Input validation
if nargin < 1
    error('applyBackLogTransform:MissingInput', 'Input Y_log is required');
end
if nargin < 2 || isempty(Y_var)
    Y_var = [];
end
if nargin < 3 || isempty(method)
    method = 'simple';
end

% Validate method
valid_methods = {'simple', 'bias_corrected'};
if ~ismember(lower(method), valid_methods)
    error('applyBackLogTransform:InvalidMethod', ...
        'Method must be ''simple'' or ''bias_corrected''');
end

% Initialize output
Z = NaN(size(Y_log));
Z_var = [];

% Back-transform mean
switch lower(method)
    case 'simple'
        % Direct exponential: Z = exp(Y_log)
        Z = exp(Y_log);

    case 'bias_corrected'
        % Bias-corrected for lognormal: Z = exp(Y_log + Y_var/2)
        if isempty(Y_var)
            warning('applyBackLogTransform:NoVariance', ...
                'bias_corrected method requires Y_var. Using simple method instead.');
            Z = exp(Y_log);
        else
            % Check dimensions match
            if ~isequal(size(Y_log), size(Y_var))
                error('applyBackLogTransform:DimensionMismatch', ...
                    'Y_log and Y_var must have the same dimensions');
            end
            Z = exp(Y_log + Y_var/2);
        end
end

% Transform variance if provided
if ~isempty(Y_var)
    % Delta method: Var(Z) ≈ exp(2*Y_log) * Var(Y_log)
    % This assumes Y_log is the mean in log space
    Z_var = exp(2*Y_log) .* Y_var;

    % Set negative variances to zero (shouldn't happen, but safety check)
    Z_var(Z_var < 0) = 0;

    % Preserve NaN where either Y_log or Y_var is NaN
    Z_var(isnan(Y_log) | isnan(Y_var)) = NaN;
end

% Ensure NaN preservation in Z
Z(isnan(Y_log)) = NaN;

end
