function [ms,mssd,mt,mtsd,sMSd,tMEd]=stmeanDensified_withNaN(Z,sMS,idMS,tME,kernParam,densParam,axMS);
% stmeanDensified_withNaN   - NaN-safe variant of stmeanDensified
%
% Identical to stmeanDensified EXCEPT the spatial and temporal exponential
% smoothers exclude NaN station/month means from their neighborhoods, so a
% single all-NaN site or all-NaN measuring event (e.g. an entirely missing
% year such as 1989) no longer poisons the whole smoothed mean field. For
% inputs with no all-NaN sites/events the output is bit-for-bit identical to
% stmeanDensified (the ~isnan() filter selects the same indices).
%
% Assuming a separable additive space/time mean trend model, this
% function calculates the spatial mean component ms and temporal mean
% component mt of space/time random field Z, using measurements at
% fixed measuring  sites cMS and fixed measuring events tME.
% The spatial mean component ms is obtained by averaging the measurements
% at each measuring sites. Then a smoothed spatial mean component mssd
% is obtained by applying an exponential spatial filter to ms on a densified
% spatial grid.
% Similarly mt is obtained by averaging the measurement for each
% measuring event, and a smoothed temporal mean component mts is obtained
% by applying an exponential temporal filter to mt on a densified temporal grid.
% Then the space/time mean trend is simply given by
% mst(s,t)=mssd(s)+mtsd(t)-mean(mtsd)
%
% SYNTAX :
%
% [ms,mssd,mt,mtsd,sMSd,tMEd]=stmeanDensified_withNaN(Z,sMS,idMS,tME,kernParam,densParam,axMS);
%
% INPUTS :
%
%  Z     nMS by nME matrix of measurements for Z at the nMS monitoring
%                   sites and nME measuring events. Z may have NaN values.
%  sMS   nMS by 2   matrix of spatial x-y coordinates for the nMS monitoring
%                   sites
%  idMS  nMS by 1   vector with a unique id number for each monitoring site
%  tME   1 by nME   vector with the time of the measuring events
%  kernParam 1 by 5 kernel parameters to smooth the spatial and temporal average
%                   p(1)=dNeib  distance (radius) of spatial neighborhood
%                   p(2)=ar     spatial range of exponential smoothing function
%                   p(3)=tNeib  time (radius) of temporal neighborhood
%                   p(4)=at     temporal range of exponential smoothing function
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
%  ms    nMS by 1   vector of spatial average for each sMS location
%  mssd  nMSd by 1  vector of smoothed spatial average for each sMSd location
%  mt    1 by nME   vector of temporal average
%  mtsd  1 by nMEd  vector of smoothed temporal average
%  sMSd  nMSd by 2  spatial x-y coordinates for the densified sMS locations
%  tMEd  1 by nMEd  vector with the densified time of the measuring events
%
%
% NOTE :
%
% Use help stgridsyntax for help on s/t grid format



%
% Check the input arguments
%
nMS=size(Z,1);
nME=size(Z,2);
if size(sMS,1)~=nMS | size(sMS,2)~=2
  error('cMS must be a nMS by 2 matrix');
end;
if size(idMS,1)~=nMS | size(idMS,2)~=1
  error('idMS must be a nMS by 1 vector');
end;
if size(tME,1)~=1 | size(tME,2)~=nME
  error('tME must be a 1 by nME vector');
end;

% set kernel smoothing parameters
dNeib=kernParam(1);        % spatial (radius) use to select local neighborhood
ar=kernParam(2);           % spatial range of exponential smoothing function
tNeib=kernParam(3);        % time (radius) of temporal neighborhood
at=kernParam(4);           % temporal range of exponential smoothing function
if length(kernParam)>4
  tloop=kernParam(5);
else
  tloop=0;
end;

% set s/t grid densifying parameters
inclvoronoi=densParam(1);   % 1 to include the voronoi vertices
inclgrid=densParam(2);      % 1 to include a grid, 0 otherwise
nxpix=densParam(3);         % Number of pixels in the x-direction for the go grid
nypix=densParam(4);         % Number of pixels in the y-direction for the go grid
densifytME=densParam(5);    % 1 to densify tME, 0 otherwise
tMEtimeStep=densParam(6);   % time step to densify tME

% densify sMS
sMSd=sMS;
xMS=sMS(:,1);
yMS=sMS(:,2);
if inclvoronoi==1
  [vx,vy] = voronoi(xMS,yMS);
  sv=unique([vx(:) vy(:)],'rows');
  idx= (axMS(1)<=sv(:,1)) & (sv(:,1)<=axMS(2)) ...
     & (axMS(3)<=sv(:,2)) & (sv(:,2)<=axMS(4)) ;
  sMSd=unique([sMSd;sv(idx,:)],'rows');
end
if inclgrid==1
  [xg yg]=meshgrid(axMS(1):diff(axMS(1:2))/nxpix:axMS(2),axMS(3):diff(axMS(3:4))/nypix:axMS(4));
  sMSd=unique([sMSd;[xg(:) yg(:)]],'rows');
end

% densify tME
tMEd=tME;
if densifytME==1
  tMEd=sort(unique([tMEd tME(1):tMEtimeStep:tME(end)]));
end

%
%  Calculate the spatial averages ms
%
ms=nan(nMS,1);
for iMS=1:nMS
  ms(iMS)=mean(Z(iMS,~isnan(Z(iMS,:))));
end;

%
%  smooth the spatial average with an exponential filter to get mss
%
xMSd=sMSd(:,1);
yMSd=sMSd(:,2);
nMSd=length(xMSd);
mssd=nan(nMSd,1);
for iMSd=1:nMSd
  d=sqrt((xMS-xMSd(iMSd)).^2+(yMS-yMSd(iMSd)).^2);
  idxMSloc=find(d<dNeib & ~isnan(ms));   % only valid station means (skip all-NaN sites)
  w=exp(-d(idxMSloc)/ar);
  mssd(iMSd)=sum(ms(idxMSloc).*w)/sum(w);
end;

%
%  Calculate the temporal averages mt
%
mt=nan(1,nME);
for iME=1:nME
  mt(iME)=mean(Z(~isnan(Z(:,iME)),iME));
end;

%
%  smooth the temporal average with an exponential filter to get mts
%
nMEd=length(tMEd);
mtsd=nan(1,nMEd);
for iMEd=1:nMEd
  t=abs(tME-tMEd(iMEd));
  if tloop>0
    t=min(t,tloop-t);
  end;
  idxMEloc=find(t<tNeib & ~isnan(mt));   % only valid monthly means (skip empty months, e.g. missing years)
  w=exp(-t(idxMEloc)/at);
  mtsd(iMEd)=sum(mt(idxMEloc).*w)/sum(w);
end;

end
