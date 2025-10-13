function plotField(sk,zk,ax,maskcontour, nxpix, nypix)
% plotField       - Makes a color map of the field of values
%
% SYNTAX:
%   plotField(sk,zk,ax,maskcontour)
%
% INPUT
%   sk            nk x 2      matrix of estimation points
%   zk            nk x 1      column vector of field values at the points sk
%   ax            1 x 4       [xmin xmax ymin ymax] of the area over which to plot the field
%                             default value is ax=[], which will use an area over all the field
%   maskcontour   n x 2       matrix of points defining the outer contour of the mask
%                             default value is maskcontour=[], which will not use any mask
%   nxpix         scalar      number of pixels in the x-direction used to create the color map
%                             default value is nxpix=150
%   nypix         scalar      number of pixels in the y-direction used to create the color map
%                             default value is nypix=100

if nargin<3, ax=[]; end;            
if nargin<4, maskcontour=[]; end;
if nargin<5, nxpix=150; end;
if nargin<6, nypix=100; end;

maskfillcolor='w';   % character defining the color to use to fill outside of the mask
                     % 'w' is for white, see help plot for other colors  
masklinetype='k';    % character defining the color to use for the linetype of 
                     % the mask contour. 'k' is for black
                     

if isempty(ax)
  ax=[min(sk(:,1)) max(sk(:,1)) min(sk(:,2)) max(sk(:,2))];
end;

dx=diff(ax(1:2))/nxpix/2;
dy=diff(ax(3:4))/nypix/2;
ax=[ax(1)+dx ax(2)-dx ax(3)+dy ax(4)-dy];  % offset of ax to avoid boundary problems

dx1=diff(ax(1:2))/nxpix;
dy1=diff(ax(3:4))/nypix;
xg=[ax(1):dx1:ax(2)+dx1-eps];
yg=[ax(3):dy1:ax(4)+dy1-eps];
[xg yg]=meshgrid(xg,yg);                   % Gridpoint of pixel used to display the field
Zg=griddata(sk(:,1),sk(:,2),zk,xg,yg,'linear');     % Value of the field at the pixel gridppoints
Zg=reshape(Zg,size(xg));
maxZg=max(max(Zg));

figure;
pcolor(xg,yg,Zg);        % Create the color map
shading interp;
hold on

%  Create a mask and fill out the outside of the mask with a uniform color
if ~isempty(maskcontour)
  axmask = [ min([maskcontour(:,1);ax(1)]) max([maskcontour(:,1);ax(2)])...
      min([maskcontour(:,2);ax(3)]) max([maskcontour(:,2);ax(4)]) ];
  [dummy,i]=min( abs( maskcontour(:,1) - axmask(1)));
  i=i(1);
  mask=[maskcontour(i:end,:);maskcontour(1:i-1,:)];
  idx=[find(sum(abs(diff(maskcontour,1,1)),2)~=0);size(maskcontour,1)];
  maskcontour=maskcontour(idx,:);
  mask=[maskcontour;maskcontour(1,:)];
  if maskcontour(2,2)>maskcontour(1,2), maskcontour=maskcontour(end:-1:1,:); end;
  fmask=[[axmask(1),maskcontour(1,2)];maskcontour;[axmask(1),maskcontour(1,2)];...
      [axmask(1) axmask(4)];[axmask(2) axmask(4)];[axmask(2) axmask(3)];...
      [axmask(1) axmask(3)];[axmask(1),maskcontour(1,2)]];
  h=fill(fmask(:,1),fmask(:,2),maskfillcolor);
  set(h,'EdgeColor',maskfillcolor);
  plot(maskcontour(:,1),maskcontour(:,2),masklinetype);
end
