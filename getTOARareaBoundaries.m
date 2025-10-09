function [axMS_est, idxSoft] = getTOARareaBoundaries(areaEst, ps, axMS)
% getTOARareaBoundaries - Get estimation boundaries and soft data index for TOAR regions
%
% Given a user-specified estimation area code, this function returns BME
% estimation boundaries and creates an index for soft data within the region.
%
% SYNTAX:
%   [axMS_est, idxSoft] = getTOARareaBoundaries(areaEst, ps, axMS)
%
% INPUTS:
%   areaEst (scalar)  Select area for estimation:
%                     0  - Global (default full extent)
%                     1  - North America
%                     2  - Europe
%                     3  - East Asia
%                     4  - South Asia
%                     5  - Continental US
%                     6  - Western Europe
%                     7  - Eastern US
%                     8  - California
%                     9  - Northeast US corridor
%                     10 - User defined (uses input axMS)
%   ps (ns x d)       Soft data space/time locations [lon, lat, time]
%                     Can be empty [] if no soft data
%   axMS (1 x 4)      Default domain boundaries [minLon maxLon minLat maxLat]
%                     default: [-180 180 -60 75] (global, no Antarctica)
%
% OUTPUTS:
%   axMS_est (1 x 4)  Adjusted boundaries for estimation area
%   idxSoft (ns x 1)  Logical index for soft data within estimation area
%                     Returns NaN if ps is empty
%
% EXAMPLE:
%   % Estimate over Europe with soft data
%   [bounds, idx] = getTOARareaBoundaries(2, KS.softdata.p);
%   
%   % Estimate over North America without soft data
%   [bounds, ~] = getTOARareaBoundaries(1, []);

if nargin < 1, areaEst = 0; end
if nargin < 2, ps = []; end
if nargin < 3, axMS = [-180 180 -60 75]; end  % Global default

% Initialize with default boundaries
axMS_est = axMS;

% Define estimation boundaries based on area code
switch areaEst
    case 0  % Global
        % Use default axMS
        
    case 1  % North America
        axMS_est = [-170 -50 15 75];
        
    case 2  % Europe
        axMS_est = [-15 40 35 72];
        
    case 3  % East Asia
        axMS_est = [100 150 20 55];
        
    case 4  % South Asia
        axMS_est = [60 100 5 40];
        
    case 5  % Continental US
        axMS_est = [-126 -66 24 50];
        
    case 6  % Western Europe
        axMS_est = [-10 20 36 60];
        
    case 7  % Eastern US
        axMS_est = [-100 -66 24 48];
        
    case 8  % California
        axMS_est = [-125 -114 32 42];
        
    case 9  % Northeast US corridor (Boston to DC)
        axMS_est = [-78 -70 38 43];
        
    case 10  % User defined
        % Keep input axMS as is
        
    otherwise
        error('areaEst must be 0-10. See help getTOARareaBoundaries for options.');
end

% Create logical index for soft data within estimation region
if ~isempty(ps)
    % Check if points fall within boundaries
    idxSoft = (ps(:, 1) >= axMS_est(1)) & (ps(:, 1) <= axMS_est(2)) & ...
              (ps(:, 2) >= axMS_est(3)) & (ps(:, 2) <= axMS_est(4));
    
    fprintf('Area %d: %d soft data points within bounds\n', areaEst, sum(idxSoft));
else
    idxSoft = NaN;
end

% Report boundaries
fprintf('Estimation boundaries: [%.1f %.1f %.1f %.1f]\n', axMS_est);

end