function calc_visual_stimulus_time()
% The purpose of this function is to provide sample code that calculates the time at which a visual stimulus would have
% been presented to a subject.

% Load data into MATLAB
filename = 'sampleDataForLatencyCalc.zip';
singleExamData = zip_load(filename);

% Calculate the period of a single frame of video
tVideoFramePeriod = 1 / singleExamData.c3d(1).VIDEO_SETTINGS.REFRESH_RATE;

% Specify, or estimate, the subject display’s response time 
tDisplayResponseTime = 0.008;	% e.g. if specifying the display's response time
tFeedForward = singleExamData.c3d(1).VIDEO_SETTINGS.FEED_FORWARD;
tDisplayResponseTime = tFeedForward - 2.5 * tVideoFramePeriod; % e.g. if estimating the display's response time

numTrials = length(singleExamData.c3d);
for trial = 1:numTrials
	% Retrieve the data from a single trial
	trialData = singleExamData.c3d(trial);

	% Estimate the display time of all video frames:
	trialData = c3d_add_video_latency(trialData, tDisplayResponseTime);

	% Identify the time at which the visual stimulus of interest was commanded
	% NOTE: This section of code will be unique for each Task Program
	eventIndex = find(strncmp('TARGET_ON', trialData.EVENTS.LABELS, 9), 1);
	tVisStimRequest = trialData.EVENTS.TIMES(eventIndex);

	% Identify the video frame that displayed the visual stimulus of interest
	videoFrameNum = find(trialData.VIDEO_LATENCY.SEND_TIMES > tVisStimRequest, 1); 

	% Retrieve the time at which the frame showing the visual stimulus of interest was displayed to the subject.
	tVisStimFrameAck  = trialData.VIDEO_LATENCY.ACK_TIMES(videoFrameNum);
	tVisStimFrameDisplayed  = trialData.VIDEO_LATENCY.DISPLAY_MAX_TIMES(videoFrameNum);

	% If desired and appropriate, correct for the impact of location of the visual stimulus on the screen location
	% NOTE: This section of code will be unique for each Task Program
	yBottomOfDisplay = trialData.VIDEO_SETTINGS.DISPLAY_SIZE_M(2); % units of m
	tpRow = trialData.TRIAL.TP;										
	targetRow = trialData.TP_TABLE.Start_Target(tpRow);
	yVisStim = trialData.TARGET_TABLE.Y_GLOBAL(targetRow) / 100; % target table has units of cm
	tLatencyLocation = tVideoFramePeriod * (yVisStim / yBottomOfDisplay);
	tVisStimDisplayed = tVisStimFrameDisplayed + tLatencyLocation; % time that visual stimulus was presented to subject

	% If desired, calculate and display the contributions to the overall latency at which the visual stimulus was 
	% displayed vs requested.
	tVisStimFrameSend  = trialData.VIDEO_LATENCY.SEND_TIMES(videoFrameNum);
	latencyWaitingForVsync = round( (tVisStimFrameSend - tVisStimRequest) * 1000);	% ms
	latencyLocation = round(tLatencyLocation * 1000);	% ms
	latencyResponseTime = round(tDisplayResponseTime * 1000);	% ms
	latencyTotal = round( (tVisStimDisplayed - tVisStimRequest) * 1000);		% ms
	latencyProcessing = latencyTotal - latencyResponseTime - latencyLocation - latencyWaitingForVsync; % ms
	if trial == 1
		fprintf('\r');
		display( ['Latency contributions from: waiting for Vsync + Transmission & processing + location'...
			' + response time = total latency ms'] );
	end
	display(['Trial ' num2str(trial) ': ' num2str(latencyWaitingForVsync) ' + ' num2str(latencyProcessing)...
		' + ' num2str(latencyLocation) ' + ' num2str(latencyResponseTime) ' = ' num2str(latencyTotal) ' ms'] );
end