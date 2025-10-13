function [mstd, sMSd, tMEd]=stCompositeMeanDensified(Z, sMS, tME, kernParam, densParam,axMS,nmax)

% stCompositeMeanDensified - estimates space/time mean trend on a densified grid
%
% Assuming a composite space/time mean trend model, this function calculates the s/t composite mean trends of s/t random field Z, 
% using measurements at fixed measuring sites sMS and fixed measuring events tME.
% This composite mean is obtained by averaging the measurements at each measuring sites and measuring events.
% The s/t composite mean trend is calculated as mentioned in: Lee et al., 2012
%
% INPUTS:
%  
%  Z     nMS by nME matrix of measurements for Z at the nMS monitoring
%                   sites and nME measuring events. Z may have NaN values.
%  sMS   nMS by 2   matrix of spatial x-y coordinates for the nMS monitoring
%                   sites
%  tME   1 by nME   vector with the time of the measuring events
%  kernParam 1 by 5 kernel parameters to smooth the spatial and temporal average
%                   p(1)=dNeib  distance (radius) of spatial neighborhood
%                   p(2)=arKS     spatial range of exponential smoothing function
%                   p(3)=tNeib  time (radius) of temporal neighborhood
%                   p(4)=atKS     temporal range of exponential smoothing function
%                   p(5)=tloop  is an optional input used for temporal smoothing.
%                        When tloop>0, the measuring events are looped in a
%                    cycle of duration tloop.
%  densParam 1 by 7 parameters to densify the spatial and temporal s/t grid
%                   inclvoronoi 1 to include the voronoi vertices to sMS 
%                   inclgrid   1 to include a regular grid to sMS, 0 otherwise  
%                   nxpix       Number of x-pixels for the regular grid added to sMS
%                   nypix       Number of y-pixels for the regular grid added to sMS
%                   densifytME  1 to densify tME, 0 otherwise 
%                   tMEtimeStep time step to densify tME  
%  axMS  1 by 4     [longmin lonmeax latmin latmax] of the grid for sMS
%
% OUTPUT :
%
%  mstd  nMSd by nMEd matrix of s/t composite mean trends
%  sMSd  nMSd by 2  spatial x-y coordinates for the densified sMS locations
%  tMEd  1 by nMEd  vector with the densified time of the measuring events

if nargin < 7
    nmax = 100;
end

% Unpack kernel parameters
dNeib = kernParam(1);
arKS = kernParam(2);
tNeib = kernParam(3);
atKS = kernParam(4);

% % Calculate a safe value for the space/time metric
% if size(sMS, 1) > 1
%     spatial_distances = coord2dist(sMS, sMS);
%     avg_spatial_distance = mean(spatial_distances(:));
% else
%     avg_spatial_distance = 1;
% end

% if length(tME) > 1
%     temporal_differences = abs(diff(tME));
%     avg_temporal_difference = mean(temporal_differences(:));
% else
%     avg_temporal_difference = 1;
% end

% stmetricKS = avg_spatial_distance + 0.5*avg_temporal_difference;
% handle situation when arKS or atKS is zero
if arKS == 0 || atKS == 0
    % work on this
else
    stmetricKS = arKS / atKS;
end

% Unpack densification parameters
inclvoronoi = densParam(1);
inclgrid = densParam(2);
nxpix = densParam(3);
nypix = densParam(4);
densifytME = densParam(5);
tMEtimeStep = densParam(6);

% Densify spatial grid
sMSd = sMS; % Start with existing spatial sites
if inclvoronoi == 1
    [vx, vy] = voronoi(sMS(:,1), sMS(:,2));
    sv = unique([vx(:) vy(:)], 'rows');
    idx = (axMS(1) <= sv(:,1)) & (sv(:,1) <= axMS(2)) & ...
            (axMS(3) <= sv(:,2)) & (sv(:,2) <= axMS(4));
    sMSd = unique([sMSd; sv(idx, :)], 'rows');
end
if inclgrid == 1
    [xg, yg] = meshgrid(linspace(axMS(1), axMS(2), nxpix), linspace(axMS(3), axMS(4), nypix));
    sMSd = unique([sMSd; [xg(:) yg(:)]], 'rows');
end

% Densify temporal grid
if densifytME == 1
    tMEd = sort(unique([tME, tME(1):tMEtimeStep:tME(end)]));
else
    tMEd = tME;
end

% Initialize output matrix for composite space-time trend
nMSd = size(sMSd, 1);
nMEd = length(tMEd);
mstd = nan(nMSd, nMEd);

% Prepare data for the neighbours_stg function
data.Zisnotnan = ~isnan(Z);
data.sMS = sMS;
data.tME = tME;
data.nanratio = sum(~data.Zisnotnan(:)) / numel(data.Zisnotnan);
data.index_stg_to_stv = cumsum(data.Zisnotnan(:));
[p_stg, z_stg] = valstg2stv(Z, data.sMS, data.tME);
data.p = p_stg(~isnan(z_stg), :);
data.z = z_stg(~isnan(z_stg));

% Calculate space-time composite mean trend on the densified grid
for iMSd = 1:nMSd
    for iMEd = 1:nMEd
        % Define target point in space-time for the current grid location
        stPoint = [sMSd(iMSd, :), tMEd(iMEd)];

        % Use neighbours_stg to find nearby points based on space-time composite distance
        dmax = [dNeib, tNeib, stmetricKS];  % Composite distance parameters
        % dmax = [dNeib, tNeib, Inf];  % Composite distance parameters
        [~, zsub, dsub, ~, ~] = neighbours_stg(stPoint, data, nmax, dmax);

        % Calculate weights based on spatial and temporal distances
        spatialDist = dsub(:, 1);
        temporalDist = dsub(:, 2);
        weights = exp(-spatialDist / arKS - temporalDist / atKS);

        % Calculate the weighted mean for the current space-time point
        if ~isempty(zsub)
            mstd(iMSd, iMEd) = sum(zsub .* weights) / sum(weights);
        end
    end
end

end