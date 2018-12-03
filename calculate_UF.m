function [FCparam, UF_FC, PA_FC, mySWL_FC] = calculate_UF(displacements, loads, cylname)

%% Static Parameters
% parameters from GeneralParameters.m
GeneralParameters
% MainHookBlockWeight = 3;   % (tons)
%
% MaxSlewSpeed = 1.1;        % rpm (revolution per minute)
% MaxHJibSpeed = 2;          % [m/s]
%
% Main_hoist_speed = 30;  % (m/min)

% parameters from AnsysParmeters.m
% Main_Capacity = 100;      % tons
AnsysParameters


%% Parameter Table

% define table for to store all luff, fold and pose related values
paramTable = displacements{1,2}{2}; % select thw 2nd displacement belonging to SWL load case.
HookLevelDatas = displacements{2,2}; % containing vertical height of hook to deck

% add HookLevelDatas to paramTable
paramTable.Hw_m = HookLevelDatas.Hw_m;
paramTable.Lvert_m = HookLevelDatas.Lvert_m;

% Determine the crane stiffness for main winch
paramTable = StiffenessCalculationOptim(paramTable, {'Main'});

% clip to slewspeed to obey the maximum horizontal jib speed.
paramTable = SlewspeedCalculation(paramTable, MaxSlewSpeed, MaxHJibSpeed);

%% calculate UF for cylinders
switch cylname
    case 'Luffing'
        myloads = loads{4,2};
        cylno = 1;
    case 'Folding'
        myloads = loads{2,2};
        cylno = 2;
end
[FCparam, UF_FC, PA_FC, mySWL_FC] = calculateUFcylinder (paramTable, myloads, cyl_geom(cylno), Main_hoist_speed, Main_Capacity, MainHookBlockWeight, true);

function [collectparam, UF1, PA1, mySWL] = calculateUFcylinder (paramTable, cyl_Loads, L_cyl_geom, Main_hoist_speed, Main_Capacity, MainHookBlockWeight, doInverse)

% params
SWL_Main = 150;                 % (tons)
Hoist_speed = Main_hoist_speed; % [m/min]
Hsign = 0;                      % [m]
LiftType = 1;                   % Deck lift  Sea lift=2
CraneType = 0;                  % offshore crane
Capacity = Main_Capacity;       % load as been used by Ansys

% some trace info
fprintf('Running %s, step:   ', cyl_Loads{1,2}(1:end-6))

mySWL = [];
options = optimset;
options.Display = 'off';
% options.MaxIter = 10;
collectparam = table;
% loop over 11x luff angle and 16x fold angle (176)
nn=0;
for ii=1:176
    nn=nn+1;
    % some trace info
    fprintf('\b\b\b%03d',ii)
    
    paramTable_line = table2struct(paramTable(ii,:)); % Assume fixed order in paramTable
    forceline       = 2*ii;                           % Assume 2 lines per luff fold datapoint
    
    % select the loads belonging to the luff, fold combination
    forceresults = combineLoads(cyl_Loads, forceline);
    
    % get SWL
    SWL = SWL_Main;
    
    % get Ltot length of the cylinder
    paramTable_line.Ltot = cyl_Loads{1,1}(forceline,:).Length_mm;
    
    % option to determine what UF you would like to get.
    UF_name = 'All';
    
    % compute all user factors and the cylinder load
    [UF1(nn), PA1(nn,:), paramTable_line] = CylinderUF_SWL(SWL, UF_name, 1,...
        paramTable_line, forceresults,...
        Hoist_speed, ...
        Hsign, ...
        LiftType, ...
        CraneType, ...
        MainHookBlockWeight, ...
        Capacity, ...
        L_cyl_geom); %#ok
    swl = 1:10:3*SWL;
    
    for kk=1:length(swl)
        uf(kk)= CylinderUF_SWL(swl(kk), UF_name, 1,...
            paramTable_line, forceresults,...
            Hoist_speed, ...
            Hsign, ...
            LiftType, ...
            CraneType, ...
            MainHookBlockWeight, ...
            Capacity, ...
            L_cyl_geom);
    end
    
    if false
        UF_P = reshape([uf(:).Pressure],4,length(swl))';
        marker = ['.','*','o','^'];
        figure(10)
        titlestr = num2str(ii);
        plot(swl,UF_P,marker(1),'DisplayName', titlestr)
        hold all
        xlabel('SWL [tonne]'),ylabel('UF_{pressure}')
    end
    % add the computed values to the paramTable
    collectparam(nn,:) =  struct2table(paramTable_line);
    
    if doInverse
        % loop over the horizontal directions [u0; u1; f0; f1];
        for jj=1:4
            % create a function handle with SWL as variable
            % select horizontal direction
            hordir = jj;
            % select which UF to use. {CylindersBuck, Pressure, TractionForce}
            UF_name = 'Pressure';
            % estimate an initial value for SWL. (divide SWL with current UF)
            myscale = UF1(nn).(UF_name);
            SWL_x0 = min(SWL/myscale(jj), 10*SWL); % don't allow SWL_x0 to be larger than 10xSWL
            SWL_x0 = max(SWL_x0, 0.1); % don't allow SWL_x0 to be lower than 0.1
            
            myfun = @(SWL_ph) CylinderUF_SWL(SWL_ph, UF_name, hordir,...
                paramTable_line, forceresults,...
                Hoist_speed, ...
                Hsign, ...
                LiftType, ...
                CraneType, ...
                MainHookBlockWeight, ...
                Capacity, ...
                L_cyl_geom);
            
            
            % compute the SWL for which the UF = zero
            mySWL(nn,jj) = fzero(myfun, SWL_x0, options);%#ok
        end
    end
end
fprintf(' \n')


function [UF, PA, paramTable_line] = CylinderUF_SWL(SWL, UF_name, hordir,...
    paramTable_line, allLoads,...
    Hoist_speed, ...
    Hsign, ...
    LiftType, ...
    CraneType, ...
    MainHookBlockWeight, ...
    Capacity, ...
    L_cyl_geom)

Ltot = paramTable_line.Ltot;

% compute DAF
paramTable_line = DAFCalculationOptim(paramTable_line, ...
    SWL, Hoist_speed, Hsign, LiftType, CraneType);

% compute LoadsFactors
TrueSWL = SWL + MainHookBlockWeight;
paramTable_line = LoadsFactorsCalculationOptim(paramTable_line, ...
    TrueSWL, Hsign, CraneType, Capacity );

% compute the sum of forces
pl = paramTable_line;
ForceSum = SumLoads(allLoads.loads1, allLoads.loads2, allLoads.loads3, allLoads.loads4, allLoads.loads5, ...
    pl.DAF, pl.SWL_Factor, pl.LateralLoad_Factor, pl.RadialLoad_Factor);

% select one of the horizontal direction (u0, u1, f0, f1)
L_cyl_CombinedForces = ForceSum(:,1); % 3rd dim is hor direction. 1 for u0
PA = L_cyl_CombinedForces(:) .* 1e3;

% select which UF to compute
UF = CylinderCalculation( PA, Ltot, L_cyl_geom, UF_name );

% select horizontal direction for UF value
if ~strcmp(UF_name, 'All')
    % CylinderCalculation makes UF to 0 in these cases.
    UF = UF(hordir);
end

function result = combineLoads(loads, forceline)
%
% loads is a cell array with at least 5 rows and 2 columns
% in the first column a table with load data in column 6-11 exist
%
% in the second column of the cell array the name of the loads is stored.

% works onlly for Main Winch now

% get the name from the loads
result.name = loads{1,2};

result.loads1 = loads{1,1}{forceline,6:11};
result.loads2 = loads{2,1}{forceline,6:11};
result.loads3 = loads{3,1}{forceline,6:11};
result.loads4 = loads{4,1}{forceline,6:11};
result.loads5 = loads{5,1}{forceline,6:11};

function LoadSum = SumLoads(loads1, loads2, loads3, loads4, loads5, DAF, SWL_Factor, LateralLoad_Factor, RadialLoad_Factor)

% pre allocate
LoadSum = zeros(4,6);

% make the 4 directions
ccw = [-1 1];
unfold = 1;
u0 = [ ccw  unfold];
u1 = [-ccw  unfold];
f0 = [ ccw -unfold];
f1 = [-ccw -unfold];
temp = [u0; u1; f0; f1];

% loop over the 4 directions
for pp = 1:4
    % Combine the loads using the operatonal_case parameters
    LoadSum(pp,:) =                   loads1 + ...
        DAF .* SWL_Factor .*             loads2 + ...
        temp(pp,1)*                      loads5 + ...
        temp(pp,2)*LateralLoad_Factor .* loads3 + ...
        temp(pp,3)*RadialLoad_Factor  .* loads4;
end