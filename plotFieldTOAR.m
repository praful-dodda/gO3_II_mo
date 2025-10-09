function plotFieldTOAR(sk, values, displayArea, maskcontour, cmap)
% plotFieldTOAR - Plot scattered field data on map with mask
%
% Helper function for plotting TOAR spatial fields

if nargin < 4, maskcontour = []; end
if nargin < 5, cmap = jet(64); end

% Remove NaN values
validIdx = ~isnan(values);
sk = sk(validIdx, :);
values = values(validIdx);

% Create interpolated grid
[xg, yg] = meshgrid(...
    linspace(displayArea(1), displayArea(2), 200), ...
    linspace(displayArea(3), displayArea(4), 100));

% Interpolate to grid
F = scatteredInterpolant(sk(:,1), sk(:,2), values, 'natural', 'none');
zg = F(xg, yg);

% Apply land mask if available
if ~isempty(maskcontour)
    % Remove NaN rows for inpolygon
    maskLon = maskcontour(:,1);
    maskLat = maskcontour(:,2);
    validMask = ~isnan(maskLon) & ~isnan(maskLat);
    
    % Check if points are over land
    onLand = inpolygon(xg(:), yg(:), maskLon(validMask), maskLat(validMask));
    zg(~reshape(onLand, size(zg))) = NaN;
end

% Plot
pcolor(xg, yg, zg);
shading interp;
axis(displayArea);
axis equal tight;

end