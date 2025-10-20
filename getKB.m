function [KG,KS,BMEparam]=getKB(obs,go,cov,BMEmethod5digits)

if nargin<1, obs=7; end;
if nargin<2, go=3; end;
if nargin<3, cov=[]; end;
if nargin<4, BMEmethod5digits=11932; end;

if isnumeric(obs), obs=getAPobservationalData(obs); end
if isnumeric(go),  go=getAPglobalOffset(obs,go,0); end
if isempty(cov), cov=getAPcov(obs,go,0); end;

[BME_obsUsed,BME_probaType,BME_localMean,BME_nhmax,BME_nsmax]=parseBMEmethod(BMEmethod5digits);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
% Get KG, the General Knowledge base for the global offset removed variable
switch BME_localMean
  case 9
    KG.order=NaN;
  case 1
    KG.order=0;
  otherwise
    error('BME_localMean must be equal to 0 or 9');
end    
KG.covmodel=cov.covmodel;
KG.covparam=cov.covparam;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
% Get KS, the Site-specific Knowledge base for the global offset removed variable

% remove the global offset from the observational data
X=obs.Y-stmeaninterp(go.sMS,go.tME,go.ms,go.mt,obs.sMS,obs.tME);

% set observational data in proper format for estimation
switch BME_probaType
  case 1 % obs are treated as hard data
    [ph,xh]=valstg2stv(X,obs.sMS,obs.tME);
    idx=~isnan(xh);
    KS.ph=ph(idx,:);
    KS.xh=xh(idx);
    KS.ps=[];
    KS.softpdftype=1;
    KS.xsm=[];
    KS.xsv=[];
    KS.nl=[];
    KS.limi=[];
    KS.probdens=[];
  case 2 
    % to be implemented later
  otherwise
    error('BME_probaType must be equal to 1 ');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
% Get BME parameters

% get the space/time metric
c01=KG.covparam{1}(1);
ar1=KG.covparam{1}(2);
at1=KG.covparam{1}(3);
c02=KG.covparam{2}(1);
ar2=KG.covparam{2}(2);
at2=KG.covparam{2}(3);
stmetric=(c01*ar1/at1+c02*ar2/at2)/(c01+c02);  % variance weighted metric average

% set the BME paramaters
switch BME_nhmax
  case 1, BMEparam.nhmax=50;             % max number of hard data
  case 2, BMEparam.nhmax=100;             
  case 3, BMEparam.nhmax=200;            
  otherwise error('BME_nhmax must be equal to 1, 2 or 3');
end
switch BME_nsmax
  case 1, BMEparam.nsmax=3;             % max number of soft data
  case 2, BMEparam.nsmax=4;             
  case 3, BMEparam.nsmax=5;            
  case 4, BMEparam.nsmax=50;            
  case 5, BMEparam.nsmax=100;            
  case 6, BMEparam.nsmax=200;            
  otherwise error('BME_nhmax must be equal to 1, 2 or 3');
end
BMEparam.dmax=[10 10 stmetric]; % dmax(1) spatial search radius, dmax(2) temporal search radius, dmax(3) space/time metric
maxpts=500000;        % number of function eval for integration
rEps=0.05;           % Relative numerical error allowable
nMom=2;              % Calculate the mean and variance
BMEparam.options=BMEoptions;
BMEparam.options(1)=0;
BMEparam.options(3)=maxpts;
BMEparam.options(4)=rEps;
BMEparam.options(8)=nMom;


