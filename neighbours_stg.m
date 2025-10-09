function [psub,zsub,dsub,nsub,index]=neighbours_stg(p0,data,nmax,dmax)
% neighbours_stg    - space/time neighbourhood selection in stg format
%
% Select a subset of space/time coordinates p and values z with the shortest
% space/time distance with coordinate p0. The data is provided in space/time
% grid (stg) format
%
% SYNTAX :
%
% [psub,zsub,dsub,nsub,index]=neighbours_stg(p0,data,nmax,dmax);
%
% INPUT :
%
% p0    1 by 3     vector of 2D space and time coordinate of point p0,
%                  where the first two columns are spatial cordinates, and 
%                  the last is time
% data_stg struct  struture indicating space/time locations where the data
%                  is available. The data z at n space/time points p is 
%                  defined by the n by 1 vector z of values, and n by 3 
%                  matrix p with long, lat and time of each value of z. 
%                  The variables p and z provide the data in space/time 
%                  vector (stv) format. It can be converted to space/time
%                  grid (stg) format using 
%                  [Z,sMS,tME,nanratio]=valstv2stg(ch,z) where Z is of size
%                  nMS by nME, sME is a nMS by 2 matrix with the spatial
%                  coordinate of nMS Monitoring Stations (MS), and tME is a
%                  1 by nME vector of Monitoring Events (ME). Z holds the
%                  the values of z organized by MS along the rows and by ME
%                  along the columns. Generally there will be some missing
%                  data at some rows and columns, which will be recorded as
%                  nan. Hence nanratio is the ratio (or fraction) of
%                  elements of Z that are nan. The values can be converted 
%                  from stg back to stv format using 
%                  [p_stg,z_stg]=valstg2stv(Z,sMS,tME), and p and z are 
%                  obtained from p_stg and z_stg using 
%                  p=p_stg(~isnan(z_stg),:)
%                  z=z_stg(~isnan(z_stg))
%                  A logical array that is true when Z is not a nan is
%                  Zisnotnan=~isnan(Z)
%                  Let index_stg be a logical index for z_stg, such that 
%                  z_stg(index_stg) selects some values of z_stg. Likewise
%                  let index be a logical index for z, such that z(index)  
%                  selects some values of z. If we want find what is the
%                  index such that z(index) is the same as 
%                  z_stg(index_stg), then we need the following variable:
%                  index_stg_to_stv=cumsum(Zisnotnan(:))
%                  Indeed, it turns out that if we have index_stg_to_stv, 
%                  then index can be obtained from index_stg as follows:
%                  index=index_stg_to_stv(index_stg)
%                  Hence, the fields for data that are needed are
%                    data.Zisnotnan   nMS by nME logical array, true if Z is not a nan
%                    data.sMS  nMS by 2  spatial coordinates of nMS Monitoring Stations (MS)
%                    data.tME  1 by nME  time of nME Monitoring Events (ME)
%                    data.nanratio  scalar  fraction of Z values that are nan
%                    data.index_stg_to_stv  nMS*nME by 1 vector converting 
%                      an index_stg for z_stg to an index for z. It can be
%                      calcated as data.index_stg_to_stv=cumsum(data.Zisnotnan(:))
%                    data.p  n by 3  matrix of the space/time coordinate of z, where n<=nMS*nME
%                    data.z  n by 1  vector of the values z
% nmax  scalar     maximum number of lines of z that must be kept.
% dmax  scalar     vector of length 3,
%                    dmax(1) is the maximum spatial distance between p and p0,
%                    dmax(2) is the maximum temporal distance between p and p0,
%                    dmax(3) space/time metric, such that :
%                      space/time distance=spatial distance+dmax(3)*temporal distance.
%
% OUTPUT :
%
% psub  m by d+1   matrix which is a subset of lines of the p matrix (m<=n and m<=nmax)
% zsub  m by 1     vector which is a subset of lines of the z vector.
% dsub  m by 2     first and second columns are the spatial and temporal distance between psub and p0.
% nsub  scalar     length of the zsub vector.
% index m by 1     vector giving the ordering of the lines in psub with
%                    respect to the initial matrix p.
% EXAMPLE
% 
% p0=[0 0 0];
% nMS=10;
% nME=5;
% Z=rand(10,5);
% Z(1:3:50)=nan;
% data.sMS=rand(nMS,2);
% data.tME=1:nME;
% data.Zisnotnan=~isnan(Z);
% data.nanratio=sum(~data.Zisnotnan(:))/length(data.Zisnotnan(:));
% data.index_stg_to_stv=cumsum(data.Zisnotnan(:));
% [p_stg,z_stg]=valstg2stv(Z,data.sMS,data.tME);
% data.p=p_stg(~isnan(z_stg),:);
% data.z=z_stg(~isnan(z_stg));
% nmax=5;
% dmax=[100 100 0.1];
% [psub,zsub,dsub,nsub,index]=neighbours_stg(p0,data,nmax,dmax);

nMS=size(data.sMS,1); % number of MS
nME=size(data.tME,2); % number of ME

if isempty(data.z)

  psub=[];
  zsub=[];
  dsub=[];
  nsub=0;
  index=[];
  return

end

s0=p0(1:end-1);                   % spatial location of p0
t0=p0(end);                       % time of p0

% Initialise indexMSsub to an index of all MS (size nMS by 1) Initialise
% indexMEsub to an index of all ME (size 1 by nME) At this stage there are
% nMS * nME candidate neighbors, which can be very large

indexMSsub=(1:nMS)';              %   indexMSsub = index of MS subset
dMSsub=coord2dist(data.sMS,s0);        %   dMSsub = distance between MS subset and s0

indexMEsub=(1:nME);               %   indexMEsub : index of ME subset
dMEsub=abs(data.tME-t0);               %   dMEsub : time difference between ME subset and t0

% Reduce the candidate neighbors to only retain MS that are within dmax(1)
% of s0 and ME that are within damx(2) of t0. This reduces the set of
% candidate neighbors if dmax(1) and/or dmax(2) is restrictive

idx1 = dMSsub<=dmax(1);           % only keep MS with distance <= dmax(1)
indexMSsub=indexMSsub(idx1);
dMSsub=dMSsub(idx1);
nMSsub=length(indexMSsub);

idx2 = dMEsub<=dmax(2);           % only keep ME with time differences <= dmax(2)
indexMEsub=indexMEsub(idx2);
dMEsub=dMEsub(idx2);
nMEsub=length(indexMEsub);

% Further reduce the candidate neighbors to only retain the nmax MS that
% are closest in space to s0. This can considerably reduce the candidate 
% when stations nMS is large and nmax is much smaller. However if there are
% missing values (i.e. values recorded as false in Zisnotnan), then we need
% to increase the number of candidate MS to account for missing values. 
% Hence we retain at least nmax/(1-data.nanratio). Since we need whole 
% number, we retain ceil(nmax/(1-data.nanratio)) MS closest to s0.
% 

[~,idx]=sort(dMSsub);         % sort indexMSsub and dMSsub by increasing 
indexMSsub=indexMSsub(idx);   % distance between s0 and the MS location
dMSsub=dMSsub(idx);

nMSsubReduced=nMSsub;             % keep at most ceil(nmax/(1-data.nanratio)) MS
if ceil(nmax/(1-data.nanratio))<nMSsubReduced
  nMSsubReduced=ceil(nmax/(1-data.nanratio));
end
indexMSsubReduced=indexMSsub(1:nMSsubReduced);
dMSsubReduced=dMSsub(1:nMSsubReduced);

% Likewise reduce the candidate ME by including only those which are no
% further in space/time from t0 as the furthest selected MS is from s0. The
% furthest selected MS from s0 is at a spatial distance dMSsubReduced(end)
% from s0. Hence we calculate the space/time distance from t0 to the ME
% using dmax(3)*dMEsub to convert time differences into spatial distances,
% and amongst the ME for which dmax(3)*dMEsub<=dMSsubReduced(end) we select
% the one that has the maximum distance between t0 and the ME time.

[~,idx]=sort(dMEsub);        % sort indexMEsub and dMEsub by increasing
indexMEsub=indexMEsub(idx);  % distance between s0 and the ME time
dMEsub=dMEsub(idx);

% Select only the ME that are no further from t0 than the furthest selected
% MS is from s0
nMEsubReduced=max(find(dmax(3)*dMEsub<=dMSsubReduced(end)));
indexMEsubReduced=indexMEsub(1:nMEsubReduced);
dMEsubReduced=dMEsub(1:nMEsubReduced);

nsubReduced=sum(reshape(data.Zisnotnan(indexMSsubReduced,indexMEsubReduced),...
  nMSsubReduced*nMEsubReduced,1));

% If nsubReduced<nmax, check to see if we have have reduced the candidate
% neighbors. This can happen if the fraction of nans is highly unevenly
% distributed across space and time. In that case, gradually increase the
% candidate MS and ME neighbors, which can be done if nMSsubReduced<nMSsub
% or nMEsubReduced<nMEsub. To do that, create a set of nMSsubReduced
% candidate values and store them in nMSsubCandidates. Likewise create a
% set of nMEsubReduced candidate values and store them in nMEsubCandidates.
% Then progressively increase either nMSsubReduced or nMEsubReduced amongst
% its corresponding set of candidate values. Do this while while
% nsubReduced<nmax and as long as either nMEsubReduced or nMEsubReduced has
% not reached its highest possible candidate value.

% If nsubReduced<nmax then try to increase nMSsubReduced or nMEsubReduced

% PD add the following lines. Remove this later
% fprintf('nsubReduced: %d\n', nsubReduced)
% fprintf('nmax: %d\n', nmax)
% fprintf('nMSsubReduced: %d\n', nMSsubReduced)
% fprintf('nMSsub: %d\n', nMSsub)
% fprintf('nMEsubReduced: %d\n', nMEsubReduced)
% fprintf('nMEsub: %d\n', nMEsub)

% try 
%   nMEsubReduced<nMEsub;
% catch ME
%   sprintf(ME.message)
%   if isempty(nMEsubReduced)
%     nMEsubReduced = 0;
%   end
% end

if isempty(nMEsubReduced)
  nMEsubReduced = 0;
end

if nsubReduced<nmax  && (nMSsubReduced<nMSsub || nMEsubReduced<nMEsub)

  if nMSsubReduced<nMSsub
    nsteps=min(floor(log10(nMSsub-nMSsubReduced))+2,5);
    nMSsubCandidates=unique(round(logspace(log10(nMSsubReduced),log10(nMSsub),nsteps)));
  else
    nMSsubCandidates=nMSsub;
  end

  if nMEsubReduced<nMEsub
    nsteps=min(floor(log10(nMEsub-nMEsubReduced))+2,5);
    nMEsubCandidates=unique(round(logspace(log10(nMEsubReduced),log10(nMEsub),nsteps)));
  else
    nMEsubCandidates=nMEsub;
  end

  ii=1; jj=1;

  while nsubReduced<nmax && ( ii+1<=length(nMSsubCandidates) || jj+1<=length(nMEsubCandidates) )

    if ii+1>length(nMSsubCandidates)
      jj=jj+1;
    elseif jj+1>length(nMEsubCandidates)
      ii=ii+1;
    else
      delta_dst_along_MS=dMSsub(nMSsubCandidates(ii+1))-dMSsub(nMSsubCandidates(ii));
      % delta_dst_along_ME=dmax(3)*(dMEsub(nMEsubCandidates(ii+1))-dMEsub(nMEsubCandidates(ii)));
      % PD removed this line in Oct. 2024 and replaced with the line
      % below
      
      % % PD edit this later
      try
        delta_dst_along_ME=dmax(3)*(dMEsub(nMEsubCandidates(jj+1))-dMEsub(nMEsubCandidates(jj)));
      catch ME
          sprintf(ME.message)
      end

      if delta_dst_along_MS<delta_dst_along_ME
        ii=ii+1;
      else
        jj=jj+1;
      end

    end

    nMSsubReduced=nMSsubCandidates(ii);
    indexMSsubReduced=indexMSsub(1:nMSsubReduced);
    dMSsubReduced=dMSsub(1:nMSsubReduced);

    nMEsubReduced=nMEsubCandidates(jj);
    indexMEsubReduced=indexMEsub(1:nMEsubReduced);
    dMEsubReduced=dMEsub(1:nMEsubReduced);

    nsubReduced=sum(reshape(data.Zisnotnan(indexMSsubReduced,indexMEsubReduced),nMSsubReduced*nMEsubReduced,1));
  end

end

% Set nMSsub to nMSsubReduced and nMEsub to nMEsubReduced
indexMSsub=indexMSsubReduced;
dMSsub=dMSsubReduced;
nMSsub=nMSsubReduced;

indexMEsub=indexMEsubReduced;
dMEsub=dMEsubReduced;
nMEsub=nMEsubReduced;

nsub=nsubReduced;

% If the number of selected neighbours is less than nmax, then return them
% without sorting them.
% If the number of selected neighbours is more than nmax, then sort them by increating 
% space/time distance from p0, and return the nmax clostest to p0
% 

% Create an index to the selected values that are not nans
Index=repmat(indexMSsub,1,nMEsub)+repmat((indexMEsub-1)*nMS,nMSsub,1);
index_stg=Index(:);
ds=repmat(dMSsub,nMEsub,1);
dt=reshape(repmat(dMEsub,nMSsub,1),nMSsub*nMEsub,1);

indexZsubIsNotNan=reshape(data.Zisnotnan(indexMSsub,indexMEsub),nMSsub*nMEsub,1);
index_stg=index_stg(indexZsubIsNotNan);
ds=ds(indexZsubIsNotNan);
dt=dt(indexZsubIsNotNan);

dst=ds+dmax(3)*dt;

% Return the selected values if there are less then nmax of them. Otherwise
% return only the nmax that are closest in space/time to p0
if length(index_stg)<=nmax
  dsub=[ds dt];
else
  [~,idx]=sort(dst);
  index_stg=index_stg(idx(1:nmax),1);
  dsub=[ds(idx(1:nmax),1) dt(idx(1:nmax),1)];
end

index=data.index_stg_to_stv(index_stg);
nsub=length(index);

% extract the subset p and z
psub=data.p(index,:);                  % extract the subset p
zsub=data.z(index);                    % extract the subset z



