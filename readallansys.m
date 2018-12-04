function readallansys

% check if data is already imported and saved in AnsysImportedData.mat
fullpath = pwd;
filename = [fullpath '\AnsysImportedData.mat'];
if false %exist(filename, 'file') == 2
    % File exists.
    useranswer = input('Do you want to re-import the original data (y/n)? ', 's');
    switch useranswer
        case 'y'
            doImport = true;
        case 'n'
            doImport = false;
        otherwise
            error('Invalid answer')
    end
else
    % File does not exist.
    doImport = true;
end

if doImport
    %% import internal loads files
    foldernames = dir('..\Results\Internal*');
    num_folders = length(foldernames);
    
    fprintf('Start importing %d folders, working on folder:  ', num_folders+4)
    for ii=1:num_folders
        fprintf('\b%d',ii)
        foldername = foldernames(ii).name;
        loads{ii,1} = foldername;
        loads{ii,2} = readansysresult(foldername);
    end
    
    %% import FeatLine.txt
    fname = '..\Results\Features_lines\FeatLine.txt';
    
    VarNames = {'Number', 'Keypoint_1', 'Keypoint_2', 'Length', 'Division', ...
        'NBNodes', 'NBElements', 'Material', 'Real', 'Type', 'Section'};
    
    featureLines  = readansysdatafile(fname, VarNames, ii+1);
    
    %% import FeatElem.txt
    fname = '..\Results\Features_elements\FeatElem.txt';
    
    VarNames = {'Element', 'Material' ,'Type', 'Real', 'Section'};
    
    featureElements = readansysdatafile(fname, VarNames, ii+2);
    
    %% import displacements
    foldername = 'Displacements_values';
    displacements{1,1} = foldername;
    displacements{1,2} = readansysresult(foldername);
    fprintf('\b\b%d',ii+3)
    
    %% import Hooklevel.txt
    fname = '..\Results\Hook_level\HookLevel.txt';
    
    VarNames = {'Heel','Trim','Slew','Luff','Fold','Hw_m', 'Lvert_m', 'Nb_Lift'};
    displacements{2,1} = 'Hook_level';
    displacements{2,2} = readansysdatafile(fname, VarNames, ii+4);
    
    %% save all imported data in a .mat file
    save('AnsysImportedData','loads', 'featureElements', 'featureLines', 'displacements')

    fprintf('\n')
else % doImport
    load AnsysImportedData
end % doImport


% assign the data in teh base workspace
assignin('base','loads', loads)
assignin('base','featureElements', featureElements)
assignin('base','featureLines', featureLines)
assignin('base','displacements', displacements)



function data = readansysdatafile(fname, VarNames, printnumber)
data = readtable(fname);
data.Properties.VariableNames = VarNames;
fprintf('\b\b%d',printnumber)
