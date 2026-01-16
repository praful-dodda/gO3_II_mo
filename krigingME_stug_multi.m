function [zk,vk]=krigingME_stug_multi(ck,ch,cs,zh,zs,vs,covmodel,covparam,nhmax,nsmax,dmax,order,options, hard_data, soft_data)

% krigingME_stug_multi           - prediction using kriging with measurement errors (Nov 27, 2025) version 3.0,
%                                   Multi-dataset version with backward compatibility
%
% Account for uncertainties by using a variation of kriging.
% The uncertainties at the data locations are modeled as random
% noises, and the resulting data can be considered as probabilitic
% soft data. These probabilistic soft data are assumed to be
% completely characterized by their mean and their variance. As
% these are only second-order moments related information, a linear
% kriging algorithm can still process adequately any mixture of these
% soft data with hard data.
%
% NEW IN VERSION 3.0:
% - Supports multiple soft datasets via cell arrays
% - Single soft data: soft_data is struct, cs/zs/vs are vectors
% - Multiple soft data: soft_data is cell array, cs/zs/vs are cell arrays
% - Fully backward compatible with version 2.0c
%
% SYNTAX :
%
% [zk,vk]=krigingME_stug_multi(ck,ch,cs,zh,zs,vs,covmodel,covparam,nhmax,nsmax,dmax,order,options);
%
% INPUT :
%
% ck         nk by d   matrix of coordinates for the estimation locations.
%                      A line corresponds to the vector of coordinates at
%                      an estimation location, so the number of columns
%                      corresponds to the dimension of the space. There is
%                      no restriction on the dimension of the space.
% ch         nh by d   matrix of coordinates for the hard data locations,
%                      with the same convention as for ck.
% cs         ns by d   matrix of coordinates for the soft data locations (single dataset),
%                      OR cell array of matrices (multiple datasets)
%                      with the same convention as for ck.
% zh         nh by 1   vector of values for the hard data at the coordinates
%                      specified in ch.
% zs         ns by 1   vector of values for the mean of the soft data (single dataset),
%                      OR cell array of vectors (multiple datasets)
%                      at the coordinates specified in cs.
% vs         ns by 1   vector of values for the variance of the soft data (single dataset),
%                      OR cell array of vectors (multiple datasets)
%                      at the coordinates specified in cs.
% covmodel   string    string that contains the name of the covariance model
%                      that is used for the estimation (see the MODELS directory).
%                      Variogram models can not be used with this function.
% covparam   1 by k    vector of values for the parameters of covmodel, according
%                      to the convention for the corresponding covariance model.
% nhmax      scalar    maximum number of hard data values that are considered
%                      for the estimation at the locations specified in ck.
% nsmax      scalar    maximum number of soft data values that are considered
%                      for the estimation at the locations specified in ck.
%                      For multiple datasets: total across all datasets
% dmax       scalar    maximum distance between an estimation location and
%                      existing hard/soft data locations. All hard/soft data
%                      locations separated by a distance smaller than dmax from
%                      an estimation location will be included in the estimation
%                      process for that location, whereas other hard/soft data
%                      locations are neglected.
% order      scalar    order of the polynomial mean along the spatial axes at the
%                      estimation locations. For the zero-mean case, NaN (Not-a-
%                      Number) is used.
% options    scalar    optional parameter that can be used if the default value
%                      is not satisfactory (otherwise it can simply be omitted
%                      from the input list of variables). options(1) is taking
%                      the value 1 or 0 if the user wants or does not want to
%                      display the order number of the location which is
%                      currently processed, respectively.
% hard_data  struct    optional structure for hard data (STG format, for future use)
% soft_data  struct OR cell array of structs
%                      Single dataset: struct with fields .x, .y, .time, .Lon, .Lat, .Z
%                      Multiple datasets: cell array {soft1, soft2, ...}
%                      Each struct should be compatible with neighbours_stug_optimized
%
% OUTPUT :
%
% zk         nk by 1   vector of estimated values at the estimation locations. A
%                      value coded as NaN means that no estimation has been performed
%                      at that location due to the lack of available data.
% vk         nk by 1   vector of estimation (kriging) variances at the estimation
%                      locations. As for zk, a value coded as NaN means that no
%                      estimation has been performed at the corresponding location.
%
% NOTE :
%
% 1- Note that in the case there are no available hard data at all,
% ch and zh can be entered as the empty [ ] matrices.
%
% 2- All the specific conventions for specifying nested models,
% multivariate or space-time cases are the same as for kriging.m.
%
% 3- For multiple soft datasets, neighbors are gathered from each dataset
% separately and then combined. The total number of soft neighbors is
% constrained by nsmax across all datasets.

%%%%%% Initialize the parameters

if nargin<13
  options(1)=0;
end

if nargin<14
  hard_data = struct();
end

if nargin<15
    soft_data = struct();
end

% ---- soft neighbor selection mode for multi-dataset case ----
softNeighborMode = 1;  % 0 = aggregate (default), 1 = per-dataset

%%%%%% Detect if we have multiple soft datasets
hasMultipleSoftDatasets = iscell(soft_data) && ~isempty(soft_data);

if hasMultipleSoftDatasets
    nSoftDatasets = length(soft_data);
    fprintf('krigingME_stug_multi: Processing %d soft datasets\n', nSoftDatasets);

    % Validate cell array inputs for cs, zs, vs if provided
    if ~isempty(cs) && ~iscell(cs)
        error('For multiple soft datasets, cs must be a cell array');
    end
    if ~isempty(zs) && ~iscell(zs)
        error('For multiple soft datasets, zs must be a cell array');
    end
    if ~isempty(vs) && ~iscell(vs)
        error('For multiple soft datasets, vs must be a cell array');
    end
else
    nSoftDatasets = 1;
end

noindex=~iscell(ck);       % test if there is an index for the variables
if noindex==1
  nk=size(ck,1);           % nk is the number of estimation points
else
  nk=size(ck{1},1);
  nindexk=length(ck{2});
  if nindexk==1
    ck{2}=ck{2}*ones(nk,1);
  end
end

if options(1)==1
  num2strnk=num2str(nk);
end

zk=zeros(nk,1)*NaN;
vk=zeros(nk,1)*NaN;

%%%%%% Main loop starts here

for i=1:nk
  if noindex==1
    ck0=ck(i,:);
  else
    ck0={ck{1}(i,:),ck{2}(i)};
  end

  % Get hard data neighbors
  [chlocal,zhlocal,~,sumnhlocal,~]=neighbours_stg(ck0,hard_data,nhmax,dmax);

  % Get soft data neighbors - handle single or multiple datasets
  if hasMultipleSoftDatasets
      % Multiple soft datasets - gather neighbors from each
      cslocal_all = [];
      zslocal_all = [];
      vslocal_all = [];
      sumnslocal_total = 0;

      % Calculate max neighbors per dataset to distribute nsmax
      % Strategy: gather from all datasets, then trim to nsmax total
      for iDataset = 1:nSoftDatasets
          if ~isempty(soft_data{iDataset})
              % Get neighbors from this dataset
              [cslocal_i, zslocal_i, ~, sumnslocal_i, index_i] = ...
                  neighbours_stug_optimized(ck0, soft_data{iDataset}, nsmax, dmax);

              if sumnslocal_i > 0
                  % Get variances for this dataset
                  if iscell(vs) && iDataset <= length(vs)
                      vslocal_i = vs{iDataset}(index_i);
                  elseif isstruct(soft_data{iDataset}) && isfield(soft_data{iDataset}, 'Zv')
                      % Extract variance from structure if available
                      % This assumes Zv is stored in a compatible format
                      % May need adjustment based on actual data structure
                      vslocal_i = extractVarianceFromIndex(soft_data{iDataset}, index_i);
                  else
                      error('Cannot find variance data for soft dataset %d', iDataset);
                  end

                  % Accumulate neighbors
                  cslocal_all = [cslocal_all; cslocal_i];
                  zslocal_all = [zslocal_all; zslocal_i];
                  vslocal_all = [vslocal_all; vslocal_i];
                  sumnslocal_total = sumnslocal_total + sumnslocal_i;
              end
          end
      end

        if softNeighborMode == 0
            % ---- Mode 0: nsmax is TOTAL across all soft datasets (legacy behavior) ----
            % Trim to nsmax total neighbors if we exceeded


            % Trim to nsmax total neighbors if we exceeded
            if sumnslocal_total > nsmax
                % Compute distances to select closest nsmax neighbors
                if noindex==1
                    dists = sqrt(sum((cslocal_all - repmat(ck0, size(cslocal_all,1), 1)).^2, 2));
                else
                    % Handle space-time distance
                    spatial_dists = sqrt(sum((cslocal_all(:,1:end-1) - ...
                        repmat(ck0{1}, size(cslocal_all,1), 1)).^2, 2));
                    temporal_dists = abs(cslocal_all(:,end) - ck0{2}(1));
                    % Use same metric as dmax (assuming dmax is [spatial, temporal, metric])
                    if length(dmax) >= 3
                        dists = spatial_dists + dmax(3) * temporal_dists;
                    else
                        dists = spatial_dists + temporal_dists;
                    end
                end

                [~, sort_idx] = sort(dists);
                keep_idx = sort_idx(1:nsmax);

                cslocal = cslocal_all(keep_idx, :);
                zslocal = zslocal_all(keep_idx);
                vslocal = vslocal_all(keep_idx);
                sumnslocal = nsmax;
            else
                cslocal = cslocal_all;
                zslocal = zslocal_all;
                vslocal = vslocal_all;
                sumnslocal = sumnslocal_total;
            end
        else
            % ---- Mode 1: nsmax is PER DATASET, no global trimming ----
            % Each dataset already capped at nsmax in neighbours_stug_optimized
            cslocal = cslocal_all;
            zslocal = zslocal_all;
            vslocal = vslocal_all;
            sumnslocal = sumnslocal_total;
        end 

  else
      % Single soft dataset (backward compatible)
      if isempty(soft_data) || (isstruct(soft_data) && isempty(fieldnames(soft_data)))
          % No soft data - use legacy cs/zs/vs vectors
          [cslocal,zslocal,~,sumnslocal,index]=neighbours(ck0,cs,zs,nsmax,dmax);
          if ~isempty(index) && ~isempty(vs)
              vslocal=vs(index);
          else
              vslocal = [];
          end
      else
          % Use soft_data structure
          [cslocal,zslocal,~,sumnslocal,index]=neighbours_stug_optimized(ck0,soft_data,nsmax,dmax);
          if ~isempty(index) && ~isempty(vs)
              vslocal=vs(index);
          else
              vslocal = [];
          end
      end
  end

  % Build kriging matrices (same as original)
  if (sumnhlocal+sumnslocal)>0 && ~isempty(vslocal)
      Khh=coord2K(chlocal,chlocal,covmodel,covparam);      % built the left-hand side matrix for hard data
      Kss=coord2K(cslocal,cslocal,covmodel,covparam);      % built the left-hand side matrix for soft data
      Khs=coord2K(chlocal,cslocal,covmodel,covparam);      % built the left-hand side matrix for hard-soft data
      Kss=Kss+diag(vslocal);                               % add the error variances on the diagonal
      kh=coord2K(chlocal,ck0,covmodel,covparam);           % built the right-hand side vector for hard data
      ks=coord2K(cslocal,ck0,covmodel,covparam);           % built the right-hand side vector for soft data

      K=[[Khh,Khs];[Khs',Kss]];                            % built the composite left-hand side matrix
      k=[kh;ks];                                           % built the composite right-hand side matrix

      if noindex==1
        chslocal=[chlocal;cslocal];
      else
        chslocal{1}=[chlocal{1};cslocal{1}];
        chslocal{2}=[chlocal{2};cslocal{2}];
      end
      [X,x]=krigconstr(chslocal,ck0,order);                % build the constraint matrices

      k0=coord2K(ck0,ck0,covmodel,covparam);             % compute the variance at ck0

      nx=size(X,2);
      Kadd=[[K,X];[X',zeros(nx)]];
      kadd=[k;x];
      lam=Kadd\kadd;                                     % compute the kriging weights lam
      lam=lam(1:(sumnhlocal+sumnslocal));                % remove the Lagrangians from the solution
      lamt=lam';
      zk(i)=lamt*[zhlocal;zslocal];                      % compute the kriging estimates zk(i)
      vk(i)=k0-2*lamt*k+lamt*K*lam;                      % compute the kriging variance vk(i)
  elseif (sumnhlocal>0)
      % Only hard data available - standard kriging
      Khh=coord2K(chlocal,chlocal,covmodel,covparam);
      kh=coord2K(chlocal,ck0,covmodel,covparam);

      [X,x]=krigconstr(chlocal,ck0,order);
      k0=coord2K(ck0,ck0,covmodel,covparam);

      nx=size(X,2);
      Kadd=[[Khh,X];[X',zeros(nx)]];
      kadd=[kh;x];
      lam=Kadd\kadd;
      lam=lam(1:sumnhlocal);
      lamt=lam';
      zk(i)=lamt*zhlocal;
      vk(i)=k0-2*lamt*kh+lamt*Khh*lam;
  end

  if options(1)==1
    disp([num2str(i),'/',num2strnk]);
  end
end

end

%%%%%% Helper function to extract variance from soft_data index
function vslocal = extractVarianceFromIndex(soft_data, index)
    % Extract variance values from soft_data structure given linear indices
    % This assumes soft_data has .Zv field with variance data

    if isfield(soft_data, 'Zv') && ~isempty(soft_data.Zv)
        % Direct indexing into Zv array
        vslocal = soft_data.Zv(index);
    elseif isfield(soft_data, 'Z') && isfield(soft_data, 'x')
        % Grid structure - extract from 3D array
        % index is linear index into the grid
        [nx, ny, nt] = size(soft_data.Z);
        [ix, iy, it] = ind2sub([nx, ny, nt], index);
        vslocal = zeros(length(index), 1);
        for i = 1:length(index)
            if isfield(soft_data, 'Zv')
                vslocal(i) = soft_data.Zv(ix(i), iy(i), it(i));
            else
                error('Variance field Zv not found in soft_data structure');
            end
        end
    else
        error('Cannot extract variance from soft_data structure');
    end
end
