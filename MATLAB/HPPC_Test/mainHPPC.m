clear all;
close all;
clc;

%% Estabilish connection with the instrument

disp('STEP 1 - ENABLE COMMUNICATION WITH THE INSTRUMENT:');

% Load VISA library
Instrlist = visadevlist;
% Create VISA object
visaObj = visadev(Instrlist.ResourceName);

% Set the timeout value
visaObj.Timeout = 10;       % [s]

% Check if the connection is successful
if strcmp(visaObj.Status, 'open')
    disp('  Instrument connection established.');
else
    error('  Failed to connect to the instrument.');
end

%% Initialization

disp('STEP 2 - INITIALIZE THE INSTRUMENT:');

% Reset the instrument to pre-defined values 
writeline(visaObj, '*RST');
% Clear status command
writeline(visaObj, '*CLS');

% Enable voltage measurements
writeline(visaObj, ':SENSe:FUNCtion:VOLTage ON');
% writeline(visaObj, ':SENSe:ELOG:FUNCtion:VOLTage ON');
% Enable current measurements
writeline(visaObj, ':SENSe:FUNCtion:CURRent ON');
% writeline(visaObj, ':SENSe:ELOG:FUNCtion:CURRent ON');

% Initialize acquisition
writeline(visaObj, ':INITiate:IMMediate:ACQuire');

disp('  Initialization done.');

%% CC-CV charge

% Data
Ts = 0.1;           % [s] Sampling time
Ilev = 1;           % [A] Current level during CC
Vliminstr = 4.4;    % [V] Voltage limit during CC - for the instrument
Vlimreal = 4.2;     % [V] Voltage limit during CC - real application

Ilimneg = 0.2;      % [A] Current negative limit during CV
Ilimpos = 2;        % [A] Current positive limit during CV

maxReadings = 100000;               % Max dimension of measured data
CurrCC = zeros(1, maxReadings);     % Current array for CC mode
VoltCC = zeros(1, maxReadings);     % Voltage array for CC mode

CurrCV = zeros(1, maxReadings);     % Current array for CV mode
VoltCV = zeros(1, maxReadings);     % Voltage array for CV mode

%------------------------------
% Set the operating mode to CC
%------------------------------

disp('STEP 3 - CC MODE:');

writeline(visaObj, ':SOURce:FUNCtion CURRENT');

% Set the voltage limit
writeline(visaObj, sprintf(':SOURce:VOLTage:LIMit:POSitive:IMMediate:AMPLitude %g', Vliminstr));
% Set the output current
writeline(visaObj, sprintf(':SOURce:CURRent:LEVel:IMMediate:AMPLitude %g', Ilev));

% Wait some time before turning the output on
pause(1);

% Enable the output
writeline(visaObj, ':OUTPut:STATe ON');

% Initialize index for data collection
idx = 0;

% Take a first measure
dc_ICC = str2double(writeread(visaObj, ':MEASure:SCALar:CURRent:DC?'));     % [A] Current
dc_VCC = str2double(writeread(visaObj, ':MEASure:SCALar:VOLTage:DC?'));     % [V] Voltage

% Update index after first measure
idx = idx + 1;

% Update the measurement arrays after first measure
CurrCC(idx) = dc_ICC;         % Current
VoltCC(idx) = dc_VCC;         % Voltage

%%%%%%%%%%%%%%%%%%%%%%%%%%% CC CHARGE CYCLE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Continue until the voltage reaches the imposed limit
while dc_VCC < Vlimreal
    
    % Sampling time
    pause(Ts);

    % Measure current
    dc_ICC = str2double(writeread(visaObj, ':MEASure:SCALar:CURRent:DC?'));

    % Measure voltage
    dc_VCC = str2double(writeread(visaObj, ':MEASure:SCALar:VOLTage:DC?'));

    % Update index after each measure
    idx = idx + 1;
    
    % Update the measurement arrays after each measure
    CurrCC(idx) = dc_ICC;
    VoltCC(idx) = dc_VCC;

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Shut down the output
writeline(visaObj, sprintf(':OUTPut:STATe %d', 0));

disp('  CC charge completed.');

% Trim the measurements
CurrCC = CurrCC(1:idx);
VoltCC = VoltCC(1:idx);

%------------------------------
% Set the operating mode to CV
%------------------------------

disp('STEP 4 - CV MODE:');

% Switch to CV
writeline(visaObj, ':SOURce:FUNCtion VOLTAGE');

% Set the current limits
writeline(visaObj, sprintf(':SOURce:CURRent:LIMit:NEGative:IMMediate:AMPLitude %g', Ilimneg));       
writeline(visaObj, sprintf(':SOURce:CURRent:LIMit:POSitive:IMMediate:AMPLitude %g', Ilimpos));         
% Set the voltage level to the value reached at the end of the CC cycle
writeline(visaObj, sprintf(':SOURce:VOLTage:LEVel:IMMediate:AMPLitude %g', VoltCC(end)));

% Wait some time before turning the output on
pause(1);

% Enable the output
writeline(visaObj, ':OUTPut:STATe ON');

% Initialize index for data collection
idx = 0;

% Take a first measure
dc_ICV = str2double(writeread(visaObj, ':MEASure:SCALar:CURRent:DC?'));     % [A] Current
dc_VCV = str2double(writeread(visaObj, ':MEASure:SCALar:VOLTage:DC?'));     % [V] Voltage

% Update index after first measure
idx = idx + 1;

% Update the measurement arrays after first measure
CurrCV(idx) = dc_ICV;
VoltCV(idx) = dc_VCV;

%%%%%%%%%%%%%%%%%%%%%%%%%%% CV CHARGE CYCLE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Continue until the current reaches the imposed negative limit
while dc_ICV > 0.2

    % Sampling time
    pause(Ts);

    % Measure current
    dc_ICV = str2double(writeread(visaObj, ':MEASure:SCALar:CURRent:DC?'));

    % Measure voltage
    dc_VCV = str2double(writeread(visaObj, ':MEASure:SCALar:VOLTage:DC?'));

    % Update index after each measure
    idx = idx + 1;

    % Update the measurement arrays after each measure
    CurrCV(idx) = dc_ICV;
    VoltCV(idx) = dc_VCV;

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Shut down the output
writeline(visaObj, sprintf(':OUTPut:STATe %d', 0));

disp('  CV charge completed.');

% Trim the measurements
CurrCV = CurrCV(1:idx);
VoltCV = VoltCV(1:idx);

disp('>> The battery is fully charged !! <<');

%% Plot voltage and current during CCCV charge

% Concatenate the measurements
CurrCharge = [CurrCC;                 % Current
        CurrCV];
VoltCharge = [VoltCC;                 % Voltage
        VoltCV];

figure;
subplot(1, 2, 1)
plot(1:length(CurrCharge), CurrCharge);
title('CCCV charge - Current');
xlabel('time [s]');
ylabel('Current [A]');
subplot(1, 2, 2)
plot(1:length(VoltCharge), VoltCharge);
title('CCCV charge - Voltage');
xlabel('time [s]');
ylabel('Voltage [V]');

%% Save voltage and current measurement in an external file

save currentCCCV.mat CurrCharge;
save voltageCCCV. mat VoltCharge;

%% Clear some variables

clear Ts Ilev Vliminstr Vlimreal Ilimneg Ilimpos maxReadings;
clear idx dc_ICC dc_ICC dc_ICV dc_VCV CurrCC VoltCC CurrCV VoltCV;

%% DISCHARGE CYCLES

% Let the cell rest before starting the discharge cycle
Rest = 10;          % [min]
WaitBar(sprintf("%g", Rest) + 'minutes rest', Rest * 60);

% Data
Ilev = -2;                              % [A] Current level during discharge
Vlimreal = 4.2;                         % [V] Voltage limit during discharge
TDis = 12;                              % [min] Period of one discharge cycle 
Ts = 0.1;                               % [s] Sampling time
disCapStep = 0.1;                       % 10% SOC decrease in each discharge

% Calculate the number of discharge cycles
numDisCycles = ceil(1/disCapStep);

% Initialize arrays to store measurements
maxReadingsDis = (TDis * 60)/Ts;          % Number of samples during one discharge cycle
maxReadingsRest = (Rest * 60)/Ts;         % Number of samples during rest periods

% Define time parameter for one discharge 
t = zeros(1, (maxReadingsDis + maxReadingsRest) * numDisCycles);
% Current array for one discharge
CurrDis = zeros(1, (maxReadingsDis + maxReadingsRest) * numDisCycles);
% Voltage array for one discharge
VoltDis = zeros(1, (maxReadingsDis + maxReadingsRest) * numDisCycles);

% Set the operating mode to CC
writeline(visaObj, ':SOURce:FUNCtion CURRENT');

% Set the voltage limit
writeline(visaObj, sprintf(':SOURce:VOLTage:LIMit:POSitive:IMMediate:AMPLitude %g', Vlimreal));
% Set the output current
writeline(visaObj, sprintf(':SOURce:CURRent:LEVel:IMMediate:AMPLitude %g', Ilev));

for cycle = 1:numDisCycles

    fprintf("Discharge cycle number: %g\n", cycle);

    % Enable the output
    writeline(visaObj, ':OUTPut:STATe ON');

    %%%%%%%%%%%%%%%%%%%%%%%%%%% DISCHARGE CYCLE %%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Continue for a total of 12 minutes

    for i = 1:maxReadingsDis
    
        % Measure current
        dc_IDis = str2double(writeread(visaObj, ':MEASure:SCALar:CURRent:DC?'));
    
        % Measure voltage
        dc_VDis = str2double(writeread(visaObj, ':MEASure:SCALar:VOLTage:DC?'));
    
        idx = (cycle - 1) * (maxReadingsDis + maxReadingsRest) + i;

        % Update time array
        t(idx) = (idx - 1) * Ts;
        % Update the measurement arrays after each measure
        CurrDis(idx) = dc_IDis;
        VoltDis(idx) = dc_VDis;
    
        % Sampling time
        pause(Ts);
    
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Disable the output
    writeline(visaObj, ':OUTPut:STATe OFF');

    fprintf("%g minutes rest period ...\n", Rest);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%% REST PERIOD %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Rest for a total of 10 minutes

    for i = 1:maxReadingsRest

        % Measure current
        dc_IDis = str2double(writeread(visaObj, ':MEASure:SCALar:CURRent:DC?'));
    
        % Measure voltage
        dc_VDis = str2double(writeread(visaObj, ':MEASure:SCALar:VOLTage:DC?'));

        idx = (cycle - 1) * (maxReadingsDis + maxReadingsRest) + maxReadingsDis + i;
        % Update time array
        t(idx) = (idx - 1) * Ts;
        % Update the measurement arrays after each measure
        CurrDis(idx) = dc_IDis;
        VoltDis(idx) = dc_VDis;

        % Sampling time
        pause(Ts);

    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end

%% Plot voltage and current during the discharge cycles
 
figure;
subplot(1, 2, 1)
plot(t, CurrDis);
title('Discharge cycle - current');
xlabel('time [s]');
ylabel('Current [A]');
subplot(1, 2, 2)
plot(t, VoltDis);
title('Discharge cycle - voltage');
xlabel('time [s]');
ylabel('Voltage [V]');

%% Save voltage and current measurement in an external file

save currentDis.mat CurrDis;
save voltageDis. mat VoltDis;

%% Clear some variables

clear Rest Ts Tdis Ilev Vlimreal disCapStep numDisCycles maxReadingsDis maxReadingsRest;
clear idx i cycle t dc_IDis dc_VDis CurrDis VoltDis;