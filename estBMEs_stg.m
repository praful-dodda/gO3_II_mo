% Using this function in the analyze function 
% that gets - obs data, go data, cov data, KS, KG, BMEparam, estParam

function estBMEs_stg(KS, KG, obs, go, BMEparam, estParam)

    BMEmethod8digits = BMEparam.BMEmethod8digits;
    mapArea = estParam.mapArea;
    mapResolution = estParam.mapResolution;
    tkVec = estParam.tkVec;
    BMEsPlot = estParam.BMEsPlot;
    forceEst_sBME = estParam.forceEst_sBME;
    BMEsDir = estParam.BMEsDir;
    
    BMEprobaType = str2double(BMEmethod8digits(8));

    % BME filename - method, go, areaEst, mapRes, nsmax, nhmax, dataFormat
    BMEsFile = sprintf('BME%s_go%d_obsZeros%d_areaEst%d_mapResolution_%d_nsmax%d_%s', ...
        BMEmethod8digits, go.scenario, obs.obsZeroType, mapArea.areaEst, mapResolution, ...
        cov.BMEparam.nsmax, BMEparam.dataFormat);

    % appropriately get the estimation points
    % Get boundaries for the area of interest
    % [bounds, softIdx] = getTOARareaBoundaries(2, KS.softdata.p);

    % % Use in BME estimation
    % ck = getTOARmapGrid(0.5);
    % sk = ck(inpolygon(ck(:,1), ck(:,2), bounds([1 2 2 1]), bounds([3 3 4 4])), :);

    % appropriately get the estimation points based on map resolution and estimation area of interest
    sk = getEstCoord(mapArea, mapResolution, tkVec);
    
    sdata=[obs.sMS(:,1) obs.sMS(:,2)];

    sk = sk(~ismember(sk,sdata,'rows'),:); % remove estimation points that are also observation points

    for i=1:length(tkVec)
        fprintf('Estimating time %d of %d ...\n', i, length(tkVec));
        tk = tkVec(i);

        filename = sprintf('%s_month%d.mat', BMEsFile, tk);

        % check if file already exists
        if exist([BMEsDir '/' filename], 'file')~=2 || forceEst_sBME==1
            pk = [sk kron(tk, 1+0*sk(:,1))]; % add time column to sk
            % BME estimation
            switch BMEprobaType
                case 1
                    tic
                    % print BMEprobaMoments not implemented for stg version
                    error('BMEprobaType 1 not implemented for estBMEs_stg.m');
                    toc

                case 2
                    tic
                    % Select kriging method based on data format
                    switch BMEparam.dataFormat
                        case 'stv'
                            fprintf('    Using krigingME (STV format)...\n');
                            [XkBMEm, XkBMEv] = krigingME(pk, KS.harddata.p, KS.softdata.p, ...
                                KS.harddata.z, KS.softdata.z, KS.softdata.vs, ...
                                KG.covmodel, KG.covparam, BMEparam.nhmax, BMEparam.nsmax, ...
                                BMEparam.dmax, KG.order);

                        case 'stg'
                            fprintf('    Using krigingME_stg (STG format)...\n');
                            [XkBMEm, XkBMEv] = krigingME_stg(pk, KS.harddata, KS.softdata, ...
                                KG.covmodel, KG.covparam, BMEparam.nhmax, BMEparam.nsmax, ...
                                BMEparam.dmax, KG.order);

                        case 'stug'
                            fprintf('    Using krigingME_stug (STUG format)...\n');
                            grid_data = reformat_stg_to_stug(KS.softdata);
                            [XkBMEm, XkBMEv] = krigingME_stug(pk, KS.harddata.p, KS.softdata.p, ...
                                KS.harddata.z, KS.softdata.z, KS.softdata.vs, ...
                                KG.covmodel, KG.covparam, BMEparam.nhmax, BMEparam.nsmax, ...
                                BMEparam.dmax, KG.order, 0, grid_data);

                        otherwise
                            error('Invalid dataFormat: %s. Must be ''stv'', ''stg'', or ''stug''', ...
                                BMEparam.dataFormat);
                    end
                    toc
            end

            % Obtain YkBMEm by adding the global offset to Xk
            gok=stmeaninterp(go.sMS,go.tME,go.ms,go.mt,sk,tk);
            YkBMEm=XkBMEm+gok;

            %  Re-ajust XkBMEv by setting NaN to max of standard dev error
            XkBMEv(isnan(XkBMEv))=max(XkBMEv);
            if ~isreal(XkBMEv), XkBMEv=real(XkBMEv); end
            BMEs.sk=sk;
            BMEs.tk=tk;
            BMEs.XkBMEm=XkBMEm;
            BMEs.XkBMEv=XkBMEv;
            BMEs.gok=gok;
            BMEs.YkBMEm=YkBMEm;
            iME = find(obs.tME==tk);
            if ~isempty(harddata.YxhO)
                idxMSh = ~isnan(harddata.YxhO(:,iME));
                BMEs.sMSobs=harddata.YphO(idxMSh,:);
                BMEs.Yobs=harddata.YxhO(idxMSh,iME);
                BMEs.Xobs=harddata.Xh(idxMSh,iME);
            end
            if ~isempty(softdata.YxmsO)
                idxMSs = ~isnan(softdata.YxmsO(:,iME));
                BMEs.sMSobsS=softdata.YpsO(idxMSs,:);
                BMEs.YobsS=softdata.YxmsO(idxMSs,iME);
                BMEs.XObsS=softdata.Xs(idxMSh,iME);
            end
            BMEs.estGridArea=axMS_est;
            BMEs.estRegion=areaEst_sBME;

            save([BMEsDir '/' filename],'BMEs');
        else
            fprintf('File %s already exists. Loading file now ...%d.\n', filename, tk);
            load([BMEsDir '/' filename], 'BMEs');

            continue;

        end

        if BMEsPlot > 0
            % Plot BME estimation results
            sprintf('Plotting BME estimation results for time %d ...\n', tk);
            plotBMEs_stg(obs, go, cov, BMEparam, estParam);
        end

        

    end




end