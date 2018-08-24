function data_out = KINARM_add_subject_inertia(data_in, varargin)

%KINARM_ADD_SUBJECT_INERTIA Estimate arm segment inertias. 
%	DATA_OUT = KINARM_ADD_SUBJECT_INERTIA(DATA_IN) adds two new fields
%	(.RIGHT_ARM and .LEFT_ARM) to the DATA_IN structure.  These two new
%	fields contain subject arm inertia, mass and CofM properties for the
%	right and left arms and are used by KINARM_ADD_TORQUES to estimate
%	intramuscular torques.   Inertial properties are estimated based on 
%	subject morphometry stored in the DATA_IN structure, including subject
%	mass and upper arm length.   
% 
%	DATA_OUT = KINARM_ADD_SUBJECT_INERTIA(DATA_IN, 'mass', MASS) uses MASS
%	as the subject mass for estimating inertial properties instead of the
%	mass stored in the DATA_IN structure.  
%
%	DATA_OUT = KINARM_ADD_SUBJECT_INERTIA(DATA_IN,... , 'subject_type', SUBJECT_TYPE,...)
%	allows the option of explicitly specifying whether the subject was
%	'human' or 'NHP'.  If this option is not specified, then the
%	SUBJECT_TYPE is chosen based on the KINARM hardware version stored in
%	DATA_IN.  
%
%	DATA_OUT = KINARM_ADD_SUBJECT_INERTIA(DATA_IN, 'mass', MASS,...) uses MASS
%	as the subject mass for estimating inertial properties instead of the
%	mass stored in the DATA_IN structure.  
%
%	DATA_OUT = KINARM_ADD_SUBJECT_INERTIA(DATA_IN, 'L2_estimate', true,...) uses
%	an estimate of segment L2 length (forearm + hand) length based on
%	segment L1, rather than extracting L2 from the DATA_IN structure.  This
%	option may be useful when the calibrated 'finger tip' location was not
%	the tip of the middle finger (e.g. if the thumb or a knuckle was used
%	for calibration, or if a handle was used instead of a hand trough).  
% 
%	The input structure DATA_IN	should be of the form produced by 
%	DATA_IN = ZIP_LOAD. ex.
%
%   data = zip_load('183485624_2010-09-21_11-26-21.zip')
%   out = KINARM_add_subject_inertia(data.c3d(3), ...)
%
%   If the data is in Dexterit-E 2.3 or earlier format then the usage would
%   be:
%
%   data = c3d_load('Subject, Test_2879_1_N_tm_8_3_1.c3d')
%   out = KINARM_add_subject_inertia(data, ...)
%
%	The new output fields (.RIGHT_ARM and .LEFT_ARM) have the following subfields: 
%		.L1_L				- length of upper arm
%		.L1_M				- estimated mass of upper arm
%		.L1_C_AXIAL			- estimated CofM WRT to shoulder of upper arm
%		.L1_I				- estimated inertia of upper arm at CofM
%		.L2_L				- length of forearm + hand
%		.L2_M				- estimated mass of forearm + hand
%		.L2_C_AXIAL			- estimated CofM WRT to shoulder of forearm + hand
%		.L2_I				- estimated inertia of forearm + hand at CofM
%
%	All of these inertial parameters are estimated using the function
%	ESTIMATE_ARM_INERTIA found in this m-file. The default version of this
%	function provides an estimate of human arm inertias based on parameters
%	published by D.A. Winters (Biomechancis of Human Movement, 1979).
%
%	If a custom method for estimating arm inertia is desired, please see
%	the code for this m-file, and replace the estimate_arm_inertia
%	function found within. 

data_out = data_in;



% Validate the varargin	
x = 1;
input_mass = [];		%default
subject_type = [];		%default
L2_estimate = false;
while x <= length(varargin)
	if strncmpi(varargin{x}, 'mass', 4)
		x = x + 1;
		if length(varargin) >= x && isnumeric(varargin{x})
			input_mass = varargin{x};
		else
			error('---> Mass was not input or was not numeric.');
		end
	elseif strncmpi(varargin{x}, 'L2_estimate', 11)
		x = x + 1;
		if length(varargin) >= x && islogical(varargin{x})
			L2_estimate = varargin{x};
		else
			error('---> L2_estimate was not input or was not logical.');
		end
	elseif strncmpi(varargin{x}, 'subject_type', 12)
		x = x + 1;
		if length(varargin) >= x && ischar(varargin{x})
			subject_type = varargin{x};
		else
			error('---> type was not input or was not a string.');
		end
	end
	x = x + 1;
end

% for each trial, get the mass, L1 and L2 and the estimate the arm inertia
% for each arm (right and left).
for ii = 1:length(data_in)
	% determine the type of subject (human or NHP)
	if ~isempty(subject_type)
		type = subject_type;
	else
		if isfield(data_in(ii), 'RIGHT_KINARM') 
			version = data_in(ii).RIGHT_KINARM.VERSION;
		elseif isfield(data_in(ii), 'LEFT_KINARM')
			version = data_in(ii).LEFT_KINARM.VERSION;
		else
			version = [];
		end
		if isempty(version)
			error('---> KINARM version cannot be found in c3d file');
		else
			if strmatch('KINARM_H', version)
				type = 'human';
			elseif strmatch('KINARM_M', version)
				type = 'NHP';
			else
				error('---> KINARM version improperly specified in c3d file');
			end
		end
	end
	
	
	% estimated based on properties of an ideal subject, scaled by actual
	% subject's mass
	if isempty(input_mass)
		M_sbj = data_in(ii).EXPERIMENT.WEIGHT;				%kg
	else
		M_sbj = input_mass;
	end
	% Check to see if there is any data for the right arm
	if isfield(data_in(ii).CALIBRATION, 'RIGHT_L1');
		L1_L = data_in(ii).CALIBRATION.RIGHT_L1;		% calibrated upper arm length (m)
		L2_L = data_in(ii).CALIBRATION.RIGHT_L2;		% calibrated forearm + hand length (m)
		data_out(ii).RIGHT_ARM = estimate_arm_inertia(M_sbj, L1_L, L2_L, L2_estimate, type);
	end
	% Check to see if there is any data for the left arm
	if isfield(data_in(ii).CALIBRATION, 'LEFT_L1');
		L1_L = data_in(ii).CALIBRATION.LEFT_L1;			% calibrated upper arm length (m)
		L2_L = data_in(ii).CALIBRATION.LEFT_L2;			% calibrated forearm + hand length (m)
		data_out(ii).LEFT_ARM = estimate_arm_inertia(M_sbj, L1_L, L2_L, L2_estimate, type);
	end

end

%re-order the fieldnames so that the hand velocity and acceleration are
%with the hand position at the beginning of the field list
orig_names = fieldnames(data_in);
right_names = {'RIGHT_ARM'};
left_names = {'LEFT_ARM'};
%Before re-arranging them, check to see if they existed in the original
%data structure, in which case do NOT re-arrange
if ~isempty(strmatch('RIGHT_KINARM', orig_names, 'exact')) && isempty(strmatch(right_names{1}, orig_names, 'exact'))
	index = strmatch('RIGHT_KINARM', orig_names, 'exact') - 1;
	new_names = cat(1, orig_names(1:index), right_names, orig_names(index+1:length(orig_names)));
else
	new_names = orig_names;
end
if ~isempty(strmatch('LEFT_KINARM', orig_names, 'exact')) && isempty(strmatch(left_names{1}, orig_names, 'exact'))
	index = strmatch('LEFT_KINARM', new_names, 'exact') - 1;
	new_names = cat(1, new_names(1:index), left_names, new_names(index+1:length(new_names)));
end
data_out = orderfields(data_out, new_names);

disp('Finished adding subject inertia');



function ARM = estimate_arm_inertia(M_sbj, L1_L, L2_L, L2_estimate, type)

	% This function estimates inertia, mass and CofM for arm based on a
	% model of the arm, using subject mass, upper arm length and
	% forearm+hand length.
	%
	% If a custom version of this function is desired, it is important that
	% the output structure ARM retain the same fields:
	%	.L1_C_AXIAL
	%	.L1_I
	%	.L1_L
	%	.L1_M
	%	.L2_C_AXIAL
	%	.L2_I
	%	.L2_L
	%	.L2_M
	
	if strmatch('human', type, 'exact')
		%  For human data, segments are modelled using CofM and radius of
		%  gyration data from:
		%  Table A.2 and Fig 3.1 in Biomechancis of Human Movement, Winter D.A.
		%  (1979).  Also repeated in Table 3.1 and Fig 3.1 in Biomechancis
		%  and Motor Control of Human Movement, 2md edition , Winter D.A.
		%  (1987).  
		%  Note: although values for the combined forearm and hand are
		%  provided in these tables, the values in the tables are expressed
		%  as a fraction of forearm length, not combined forearm + hand
		%  length.  So  the combined forearm + hand values are calculated
		%  directly here, following this if statement
		prct_L1_L_h = 0.58;				%length of hand as fraction of length of upper arm
		prct_L1_L_fa = 0.79;			%length of forearm as fraction of length of upper arm

		prct_M_h = 0.006;				%mass of hand as fraction of subject mass
		prct_M_fa = 0.016;				%mass of forearm as fraction of subject mass
		prct_M_ua = 0.028;				%mass of upper arm as fraction of subject mass

		prct_L_h_C_h = 0.506;			%CofM (relative to prox. joint) of hand as fraction of length of hand
		prct_L_fa_C_fa = 0.430;			%CofM (relative to prox. joint) of forearm as fraction of length of forearm
		prct_L1_C_ua = 0.436;			%CofM (relative to prox. joint) of upper arm as fraction of length of upper arm
% 		prct_L2_C_fa_h = 0.682;			%CofM (relative to prox. joint) of forearm+hand as fraction of length of forearm (i.e not as fraction of length of forearm+hand!)

		prct_L_h_rho_h = 0.297;			%radius of gyration (about CofM) of hand as fraction of length of hand
		prct_L_fa_rho_fa = 0.303;		%radius of gyration (about CofM) of forearm as fraction of length of forearm
		prct_L1_rho_ua = 0.322;			%radius of gyration (about CofM) of upper arm as fraction of length of upper arm
	% 	prct_L2_rho_fa_h = 0.468;		%radius of gyration (about CofM) of	forearm+hand as fraction of length of forearm (i.e not as fraction of length of forearm+hand!

	elseif strmatch('NHP', type, 'exact')
		% For NHP data, segments are modelled using CofM and radius of
		% gyration data used in the study: Cheng and Scott, J. Morph (2000)
		% 245:206-224.  Some of the values here are different than those
		% originally published following a re-analysis of the original raw
		% data
		
		prct_L1_L_h = 0.72;				%length of hand as fraction of length of upper arm
		prct_L1_L_fa = 1.07;			%length of forearm as fraction of length of upper arm

		prct_M_h = 0.008;				%mass of hand as fraction of subject mass
		prct_M_fa = 0.024;				%mass of forearm as fraction of subject mass
		prct_M_ua = 0.036;				%mass of upper arm as fraction of subject mass

		prct_L_h_C_h = 0.40;			%CofM (relative to prox. joint) of hand as fraction of length of hand
		prct_L_fa_C_fa = 0.44;			%CofM (relative to prox. joint) of forearm as fraction of length of forearm
		prct_L1_C_ua = 0.49;			%CofM (relative to prox. joint) of upper arm as fraction of length of upper arm

		prct_L_h_rho_h = 0.251;			%radius of gyration (about CofM) of hand as fraction of length of hand
		prct_L_fa_rho_fa = 0.261;		%radius of gyration (about CofM) of forearm as fraction of length of forearm
		prct_L1_rho_ua = 0.249;			%radius of gyration (about CofM) of upper arm as fraction of length of upper arm
	else
		error(['---> Inadmissable ''subject_type'' ' type ' given']);
	end
	
% calculate values for combined forearm + hand 
	prct_L1_L_fa_h = prct_L1_L_h + prct_L1_L_fa;				%length of forearm+hand as percent of length of upper arm

	prct_M_fa_h = prct_M_h + prct_M_fa;							%mass of forearm+hand as percent of subject mass
	
	prct_L2_L_h = prct_L1_L_h / prct_L1_L_fa_h;					%length of hand as percent of length of forearm+hand
	prct_L2_L_fa = 1 - prct_L2_L_h;								%length of forearm as percent of length of forearm+hand
	prct_L2_C_h = prct_L_h_C_h * prct_L2_L_h + prct_L2_L_fa;	%CofM (relative to prox. joint) of hand as percent of length of forearm+hand
	prct_L2_C_fa = prct_L_fa_C_fa * prct_L2_L_fa;				%CofM (relative to prox. joint) of forearm as percent of length of forearm+hand
	prct_L2_C_fa_h = (prct_M_h * prct_L2_C_h + prct_M_fa * prct_L2_C_fa) / prct_M_fa_h;		%CofM (relative to prox. joint) of forearm+hand as percent of length of forearm+hand
	
	prct_L2_rho_h = prct_L_h_rho_h * prct_L2_L_h;				%radius of gyration (about CofM) of hand as percent of length of forearm+hand
	prct_L2_rho_fa = prct_L_fa_rho_fa * prct_L2_L_fa;			%radius of gyration (about CofM) of forearm as percent of length of forearm+hand
	prct_L2_rho_fa_h = sqrt( (prct_M_h * (prct_L2_rho_h^2 + (prct_L2_C_fa_h - prct_L2_C_h)^2)...
		+ prct_M_fa * (prct_L2_rho_fa^2 + (prct_L2_C_fa_h - prct_L2_C_fa)^2) ) / prct_M_fa_h); 
			
	ARM.L1_L = L1_L;			% upper arm length (m)
	if L2_estimate
		ARM.L2_L = prct_L1_L_fa_h * L1_L;				% Estimated forearm + hand length (m)
	else
		ARM.L2_L = L2_L;			% forearm + hand length (m)
	end

	if M_sbj > 0
		ARM.L1_M = prct_M_ua * M_sbj;					% Estimated upper arm mass (kg)
		ARM.L1_C_AXIAL = prct_L1_C_ua * ARM.L1_L;		% Estimated upper arm CofM (relative to prox. joint) (m)
		L1_rho = prct_L1_rho_ua * ARM.L1_L;				% Estimated upper arm radius of gyration (m)
		ARM.L1_I = ARM.L1_M * L1_rho^2;					% Estimated upper arm inertia (kg.m^2) at CofM
		
		ARM.L2_M = prct_M_fa_h * M_sbj;					% Estimated forearm + hand mass (kg)
		ARM.L2_C_AXIAL = prct_L2_C_fa_h * ARM.L2_L;		% Estimated forearm + hand CofM (relative to prox. joint) (m)
		L2_rho = prct_L2_rho_fa_h * ARM.L2_L;			% Estimated forearm + hand radius of gyration (m)
		ARM.L2_I = ARM.L2_M * L2_rho^2;					% Estimated forearm + hand inertia (kg.m^2) at CofM
	else
		error(['---> Mass of subject for trial ''' data_in.FILE_NAME ''' was <=0.']);
 	end
