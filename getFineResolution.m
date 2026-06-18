function getFineResolution(BMEs)
% 
% getFineResolution
% takes NASA 0.1 reoslution and applies it to 0.5 degree BME estimation to
% create BME estimate at fine resolution (0.1 degrees)
%
% SYNTAX:
%   getFineResolution(BMEs)
%
% INPUT:
%   BMEs structure
%       BMEs.estimate = x by y vector of BME space time estimations of OSDMA8
%       BMEs.grid = x by 2 vector of estimation points (lon, lat)
%       BMEs.tk = 1 by y vector estimation years 
%       BMEs.var = x by y vector of space time BME variance 
%
% OUTPUT:
%   fine resolution files are saved in FineResolution folder
%

[nxpix,nypix]=getPixels;

%open NASA G5NR-Chem fine resolution netcdf file
ncid=netcdf.open('dma8-g5nr-chem-jul13-jun14.nc');
nclon=netcdf.getVar(ncid,0); %x
nclat=netcdf.getVar(ncid,1); %y
ncozone=netcdf.getVar(ncid,2); %val

%put NASA model is necessary format
[X,Y]=meshgrid(nclat,nclon);
rotatedozone=rot90(ncozone);
rotatedlat=rot90(X);
rotatedlon=rot90(Y);
flippedozone=flipud(rotatedozone);
flippedlat=flipud(rotatedlat);
flippedlon=flipud(rotatedlon);
M2.value=flippedozone;
M2.lat=flippedlat;
M2.lon=flippedlon;

%cut off latitudes not in estiamtion domain
f=2;
g=1351;
M2updated.lon=M2.lon(f:g,:);
M2updated.lat=M2.lat(f:g,:);
M2updated.value=M2.value(f:g,:);

%chance null values from -999 to NaN
indexNaN=M2updated.value==-999;
M2updated.value(indexNaN)=NaN;

% aggregate NASA file to 0.5 degrees by creating index numbering all the
% 0.5 degrees grid cells
% create matric of 0.5 degree grid numbers
filenamegridnumbers='GridNumbers13503600.mat';
if exist(filenamegridnumbers)==2
    load(filenamegridnumbers)
else
    number=1;
    [rows,columns]=size(M2updated.value);
    gridnumbers=zeros(rows,columns);
    startx=1;
    starty=1;
    for x=1:(columns/5)
        for y=1:(rows/5)
            gridnumbers(starty:starty+4,startx:startx+4)=number;
            starty=starty+5;
            number=number+1;
            if y==(rows/5)
                startx=startx+5;
                starty=1;
            end
        end
    end
    save(filenamegridnumbers,'gridnumbers');
end

%find the average of the 0.5 degree grid cell (25 NASA grid cells)
if exist('NASAag13503600.mat')==2
    load('NASAag13503600.mat');
else
    for i=1:max(max(gridnumbers))
        idx=gridnumbers==i;
        M2ag(i)=mean(M2updated.value(idx),'omitnan');
    end
    save('NASAag13503600.mat','M2ag');
end

%reshape BME estimation grid points to "map" format
M1.lon=reshape(BMEs.grid(:,1),[nypix+1,nxpix+1]);
M1.lat=reshape(BMEs.grid(:,2),[nypix+1,nxpix+1]);

%create output folder
folder='FineResolution';
if exist(folder)~=7
    mkdir(folder);
end

for t=1:length(BMEs.tk)
    
    %reshape BME estimate for year into "map" format
    M1.values=reshape(BMEs.estimate(:,t),[nypix+1,nxpix+1]);
    M1.var=reshape(BMEs.var(:,t),[nypix+1,nxpix+1]);
    
    filenamefinal=[folder '/FineResolution' num2str(BMEs.tk(t)) '.mat'];
    if exist(filenamefinal)==2
        load(filenamefinal);
    else 
        
    Final=zeros(size(M2updated.value));
    Finalv_constant=zeros(size(M2updated.value));
    Finalv_interp=zeros(size(M2updated.value));
    currentyearvalues=M1.values;
    
    %go through all grids
    for i=1:max(max(gridnumbers))
        idx=find(gridnumbers==i);
        
        % difference = BME coarse estimation - NASA average 
        % if either BME coarse or NASA average is NaN, difference is NaN
        if isnan(currentyearvalues(i))
            difference=NaN;
        elseif isnan(M2ag(i))
            difference=NaN;
        else
            difference=currentyearvalues(i)-M2ag(i); %try this
        end
        
        % BME fine = NASA average + difference
        % if differece is NaN then 
        for k=1:length(idx)
            j=idx(k);
            if isnan(difference)
                Final(j)=NaN; %final estimate
                Finalv_constant(j)=NaN; %final variance where variance is the same in 0.5 grid
                Finalv_interp(j)=NaN; % final variance where variance is interpolated
                continue;
            end
            if isnan(M2updated.value(j))
                Final(j)=NaN; %final estimate
                Finalv_constant(j)=NaN; %final variance where variance is the same in 0.5 grid
                Finalv_interp(j)=NaN;  % final variance where variance is interpolated
                continue;
            end
            Final(j)=difference+M2updated.value(j);
            Finalv_constant(j)=M1.var(i); %final variance where variance is the same in 0.5 grid
            
            lon_point=M2updated.lon(j);
            lat_point=M2updated.lat(j);
            Finalv_interp(j)=interp2(M1.lon,M1.lat,M1.var,lon_point,lat_point);  % final variance where variance is interpolated
        end
        
    end
    
    %save yearly output 
    save(filenamefinal, 'Final', 'Finalv_constant', 'Finalv_interp');
    end
    
    % display results showing average
    if 0
        disp(["Year: " num2str(BMEs.tk(t))]);
        disp(["Average of NASA original: " num2str(mean(M2updated.value(:),'omitnan'))]);
        disp(["Average of NASA aggregated: " num2str(mean(M2ag))]);
        disp(["Average of BME Estimate original: " num2str(mean(M1.values(:),'omitnan'))]);
        disp(["Average of BME Estimate final: " num2str(mean(Final(:),'omitnan'))]);
    end
end


end