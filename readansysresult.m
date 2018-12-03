function result = readansysresults(foldername)

% readansysresult

% get all textfilenames from foldername
fnames = dir(['..\Results\' foldername '\*.txt']);

% define load variable names
VarNamesLoad = {'Heel','Trim','Slew','Luff','Fold','FX_kN','FY_kN',...
    'FZ_kN','MX_kNm','MY_kNm','MZ_kNm','Length_mm','Radius_mm','Nb_Lift','Node'};

% define element variable names
VarNamesElement = {'Node', 'I1_J2', 'Elem','FX_kN','FY_kN',...
    'FZ_kN','MX_kNm','MY_kNm','MZ_kNm', 'Heel','Trim','Slew','Luff','Fold', ...
    'Radius_mm', 'Nb_Lift'};

% define displacement variable names
VarNamesDisplacement = {'Heel', 'Trim', 'Slew', 'Luff', 'Fold', 'UX_mm', 'UY_mm', ...
    'UZ_mm', 'SWL_kN', 'Radius_mm', 'Nb_Lift'};

% loop over loadcases
for ii = 1:length(fnames)
    % get filename for specific load case
    fname = fnames(ii).name;
    
    % import the text file as table
    data = readtable([fnames(ii).folder '\' fname]);
    % set the table column names
    switch length(data.Properties.VariableNames)
        case 11
            data.Properties.VariableNames = VarNamesDisplacement;
        case 15
            data.Properties.VariableNames = VarNamesLoad;
        case 16
            data.Properties.VariableNames = VarNamesElement;
    end
    
    % collect all loadcases in a cell
    result{ii,1} = data;
    result{ii,2} = fname;
end

% move row 2 (_10.txt) to last row of result
result(ii+1,:) = result(2,:);
result(2,:) = [];

