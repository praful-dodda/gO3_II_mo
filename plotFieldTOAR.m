function plotFieldTOAR(sk,zk,ax,maskcontour, nxpix, nypix, bufferDist, bufferType, interpMethod)
% plotFieldTOAR       - Makes a color map of the field of values
%
% SYNTAX:
%   plotFieldTOAR(sk,zk,ax,maskcontour, nxpix, nypix, bufferDist, bufferType, interpMethod)
%
% INPUT
%   sk            nk x 2      matrix of estimation points
%   zk            nk x 1      column vector of field values at the points sk
%   ax            1 x 4       [xmin xmax ymin ymax] of the area over which to plot the field
%   maskcontour   n x 2       matrix of points defining the outer contour of the mask
%   nxpix         scalar      number of pixels in the x-direction (default=150)
%   nypix         scalar      number of pixels in the y-direction (default=100)
%   bufferDist    scalar      buffer distance in same units as sk (default=0.5 degrees)
%   bufferType    string      'soft' for gradual fade, 'hard' for sharp cut (default='soft')
%   interpMethod  string      griddata interpolation method: 'natural' (default, smoother),
%                             'linear', 'cubic', 'nearest', or 'v4'. Using 'natural' reduces
%                             grid-aligned stripe artifacts in variance maps.

if nargin<3, ax=[]; end
if nargin<4, maskcontour=[]; end
if nargin<5, nxpix=150; end
if nargin<6, nypix=100; end
if nargin<7, bufferDist=1; end      % Default 0.5 degree buffer
if nargin<8, bufferType='soft'; end
if nargin<9, interpMethod='natural'; end  % Changed from 'linear' to reduce stripe artifacts

masklinetype='k';    

if isempty(ax)
  ax=[min(sk(:,1)) max(sk(:,1)) min(sk(:,2)) max(sk(:,2))];
end

dx=diff(ax(1:2))/nxpix/2;
dy=diff(ax(3:4))/nypix/2;
ax=[ax(1)+dx ax(2)-dx ax(3)+dy ax(4)-dy];

dx1=diff(ax(1:2))/nxpix;
dy1=diff(ax(3:4))/nypix;
xg=ax(1):dx1:ax(2)+dx1-eps;
yg=ax(3):dy1:ax(4)+dy1-eps;
[xg, yg]=meshgrid(xg,yg);
Zg=griddata(sk(:,1),sk(:,2),zk,xg,yg,interpMethod);
Zg=reshape(Zg,size(xg));

% Apply mask with buffer
if ~isempty(maskcontour)
  % Remove duplicate consecutive points
  idx=[find(sum(abs(diff(maskcontour,1,1)),2)~=0);size(maskcontour,1)];
  maskcontour=maskcontour(idx,:);

  % Check if points are inside the mask
  in_mask = inpolygon(xg, yg, maskcontour(:,1), maskcontour(:,2));

  if strcmp(bufferType, 'soft')
    % SOFT BUFFER: Create smooth transition zone
    % Calculate distance from boundary for points outside mask
    outside_mask = ~in_mask;
    
    if any(outside_mask(:))
      % Compute distance to nearest mask boundary point
      dist_to_boundary = nan(size(xg));
      outside_idx = find(outside_mask);
      
      for i = 1:length(outside_idx)
        pt = [xg(outside_idx(i)), yg(outside_idx(i))];
        dist_to_boundary(outside_idx(i)) = min(sqrt(sum((maskcontour - pt).^2, 2)));
      end
      
      % Create smooth fade-out using sigmoid function
      % Points at boundary = 1, points at bufferDist = 0
      fade = 1 ./ (1 + exp(5 * (dist_to_boundary - bufferDist/2) / bufferDist));
      fade(in_mask) = 1;  % Keep inside values at full strength
      
      % Apply fade to data
      Zg = Zg .* fade;
      Zg(dist_to_boundary > bufferDist) = NaN;  % Hard cutoff beyond buffer
    end
    
  else
    % HARD BUFFER: Expand mask outward by bufferDist
    outside_mask = ~in_mask;
    
    if any(outside_mask(:))
      dist_to_boundary = nan(size(xg));
      outside_idx = find(outside_mask);
      
      for i = 1:length(outside_idx)
        pt = [xg(outside_idx(i)), yg(outside_idx(i))];
        dist_to_boundary(outside_idx(i)) = min(sqrt(sum((maskcontour - pt).^2, 2)));
      end
      
      % Hard cutoff at buffer distance
      Zg(dist_to_boundary > bufferDist) = NaN;
    else
      Zg(~in_mask) = NaN;
    end
  end
end

figure;
pcolor(xg,yg,Zg);
shading interp;
hold on

% Plot the mask contour boundary
if ~isempty(maskcontour)
  plot(maskcontour(:,1),maskcontour(:,2),masklinetype);
end