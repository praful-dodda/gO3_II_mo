function [BME_obsUsed,BME_probaType,BME_localMean,BME_nhmax,BME_nsmax,BMEmethod]=parseBMEmethod(BMEmethod6digits)
% parse the BME method switches
%
% Parse the BME method switches coded in BMEmethod6digits into individual
% BME method switches. For example if BMEmethod6digits=110322, then the
% first digit is 1, the second digit is 1, the third digit is 0, etc.
% The output are value of each invidual digit stored in an individual
% variable
%
% SYNTAX :
%
% [BME_obsUsed,BME_probaType,BME_localMean,BME_nhmax,BME_nsmax]=parseBMEmethod(BMEmethod6digits)
%
% INPUT :
%
% BMEmethod6digits   a 6 digits number with 6 BME method switches
%                    default is 110322
%
% OUTPUT :
%
% BME_obsUsed, digit 1 of BMEmethod6digits, indicates which observations 
%              to use, as following  
%              1 use all observations
% BME_probaType, digit 2 of BMEmethod6digits, indicates the type of hard and 
%              soft data to use, as following  
%              1 treat all observations as hard data
% BME_localMean, digit 3 of BMEmethod6digits, indicates the type of 
%              local mean trend to use, as following
%              0 local mean trend is zero, order=NaN
%              1 local mean trend is constant, order=0
% BME_nhmax, digit 4 of BMEmethod6digits, indicates the value of nhmax to use 
%              1 nhmax=50
%              2 nhmax=100
%              3 nhmax=200
% BME_nsmax, digit 5 of BMEmethod6digits, indicates the value of nsmax to use 
%              1 nsmax=3
%              2 nsmax=4
%              3 nsmax=5
%              4 nsmax=50
%              5 nsmax=100
%              6 nsmax=200
% BMEmethod, digit 6 of BMEmethod6digits, indicates which method to use
%              1 use BME
%              2 use KrigingME

% version number
ver='6.0'; % version 6 digits update 0

% default input argument
if nargin<1, BMEmethod6digits=110322; end

BMEmethod_numberOfdigits=str2double(ver(1));

if length(num2str(BMEmethod6digits))~=BMEmethod_numberOfdigits
  error('BMEmethod6digits needs to be a vector of length 6');
end

BMEmethodStr=num2str(BMEmethod6digits);

BME_obsUsed=str2double(BMEmethodStr(1));
BME_probaType=str2double(BMEmethodStr(2));
BME_localMean=str2double(BMEmethodStr(3));
BME_nhmax=str2double(BMEmethodStr(4));
BME_nsmax=str2double(BMEmethodStr(5));