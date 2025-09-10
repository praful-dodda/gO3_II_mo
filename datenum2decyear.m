function decimalYear = datenum2decyear(datenumValue)
% Convert MATLAB datenum to decimal year
    dateVector = datevec(datenumValue);
    year = dateVector(:, 1);
    dayOfYear = datenumValue - datenum(year, 1, 1) + 1;
    daysInYear = datenum(year + 1, 1, 1) - datenum(year, 1, 1);
    decimalYear = year + (dayOfYear - 1) ./ daysInYear;
end