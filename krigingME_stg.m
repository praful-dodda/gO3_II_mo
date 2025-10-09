function [zk, vk] = krigingME_stg(pk,harddata,softdata,covmodel,covparam,nhmax,nsmax,dmax,order,options)

    % krigingME                 - prediction using kriging with measurement errors using space-time grid data
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
    % SYNTAX :
    %
    % [zk,vk]=krigingME_stg(pk,harddata,softdata,covmodel,covparam,nhmax,nsmax,dmax,order,options);
    %
    % INPUT :
    % 
    % pk        nk by d   matrix of coordinates for the estimation locations.
    %                     A line corresponds to the vector of coordinates at
    %                     an estimation location, so the number of columns
    %                     corresponds to the dimension of the space. There is
    %                     no restriction on the dimension of the space.
    % harddata  struct    struct with the following fields:
    %                     sMS: nMS by d matrix of unique spatial locations,
    %                     tME: 1 by nME vector of unique time events,
    %                     Z: nMS by nME matrix of values for the hard data at the coordinates
    %                     specified in sMS and tME.
    %                     Zisnotnan: nMS by nME matrix of logicals indicating where Z is not NaN.
    %                     nanratio: scalar indicating the ratio of NaNs in Z.
    %                     index_stg_to_stv: nMS by nME matrix of indices to map Z to stv.
    %                     p: nMS*nME by d matrix of unique spatial-time locations.
    % softdata  struct    struct with the following fields:
    %                     sMS: nMS by d matrix of unique spatial locations,
    %                     tME: 1 by nME vector of unique time events,
    %                     Z: nMS by nME matrix of values for the mean of the soft data at the
    %                     coordinates specified in sMS and tME.
    %                     Xvs: nMS by nME matrix of values for the variance of the soft data at
    %                     the coordinates specified in sMS and tME.
    %                     Zisnotnan: nMS by nME matrix of logicals indicating where Z is not NaN.
    %                     nanratio: scalar indicating the ratio of NaNs in Z.
    %                     index_stg_to_stv: nMS by nME matrix of indices to map Z to stv.
    %                     p: nMS*nME by d matrix of unique spatial-time locations.
    % covmodel  string    string that contains the name of the covariance model
    %                     that is used for the estimation (see the MODELS directory).
    %                     Variogram models can not be used with this function.
    % covparam  1 by k    vector of values for the parameters of covmodel, according
    %                     to the convention for the corresponding covariance model.
    % nhmax     scalar    maximum number of hard data values that are considered
    %                     for the estimation at the locations specified in pk.
    % nsmax     scalar    maximum number of soft data values that are considered
    %                     for the estimation at the locations specified in pk.
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


    
    if nargin < 10
        options(1) = 0;
    end

    % noindex = 1;

    npk = size(pk,1);
    % nsMSh = size(harddata.sMSh,1);
    % nsMSs = size(softdata.sMSs,1);

    if options(1) == 1
        num2strnk = num2str(npk);
    end

    zk = NaN(npk, 1);
    vk = NaN(npk,1);

    for i = 1:npk
        pk0 = pk(i,:);

        % [phlocal, zhlocal, ~, sumnhlocal, ~] = neighbours_stv(pk0, harddata.p(harddata.Zisnotnan,:), harddata.z(harddata.Zisnotnan), nhmax, dmax);
        [phlocal, zhlocal, ~, sumnhlocal, ~] = neighbours_stg(pk0, harddata, nhmax, dmax);
        % [pslocal, zslocal, ~, sumnslocal, index] = neighbours_stg(pk0, softdata, nsmax, dmax);
        
        % % PD edit this later
        try
            [pslocal, zslocal, ~, sumnslocal, index] = neighbours_stg(pk0, softdata, nsmax, dmax);
        catch ME
            sprintf(ME.message)
        end

        vslocal = softdata.vs(index);

        Khh = coord2K(phlocal, phlocal, covmodel, covparam);
        Kss = coord2K(pslocal, pslocal, covmodel, covparam);
        Khs = coord2K(phlocal, pslocal, covmodel, covparam);

        Kss=Kss+diag(vslocal);                               % add the error variances on the diagonal
        kh=coord2K(phlocal,pk0,covmodel,covparam);           % built the right-hand side vector for hard data
        ks=coord2K(pslocal,pk0,covmodel,covparam);           % built the right-hand side vector for soft data

        K=[[Khh,Khs];[Khs',Kss]];                            % built the composite left-hand side matrix
        k=[kh;ks];                                           % built the composite right-hand side matrix

        chslocal=[phlocal;pslocal];
        [X,x]=krigconstr(chslocal,pk0,order);
        index=findpairs(pk0,pslocal);

        if isempty(index)
            k0=coord2K(pk0,pk0,covmodel,covparam);             % compute the variance at pk0
        end

        if (sumnhlocal+sumnslocal)>0
            nx=size(X,2);
            Kadd=[[K,X];[X',zeros(nx)]];
            kadd=[k;x];
            lam=Kadd\kadd;                                     % compute the kriging weights lam
            lam=lam(1:(sumnhlocal+sumnslocal));                % remove the Lagrangians from the solution
            lamt=lam';
            zk(i)=lamt*[zhlocal;zslocal];                      % compute the kriging estimates zk(i)
            vk(i)=k0-2*lamt*k+lamt*K*lam;                      % compute the kriging variance vk(i)
        end

        if options(1) == 1
            disp([num2str(i),'/',num2strnk]);
        end
    end
end