function data_out = c3d_add_video_latency(data_in, display_latency)
%C3D_ADD_VIDEO_LATENCY Add min/max limits to video latency
%	DATA_OUT = C3D_ADD_VIDEO_LATENCY(DATA_IN, DISPLAY_LATENCY) adds minimum
%	and maximum video latencies to the Video_Latency field of the structure
%	DATA_IN.  These latencies are based on the send and acknowledge times
%	for the video frames, include a full refresh period for transmitting
%	the image to the display device and the DISPLAY_LATENCY input (in
%	second).  There is also some 'intelligence' which corrects some
%	acknowledgement times based on the fact that the minimum time between
%	the actual display of an image is the refresh period.
%
%	Note that the true DISPLAY_LATENCY is at least equal to the latency
%	reported by the manufacturer of the display device, and can be much
%	longer than the reported value.  Please see the Dexterity User Guide
%	referency section for more information.

if nargin==0
	error('---> No input provided ');
end

if nargin == 1 || isempty(display_latency) || ~isnumeric(display_latency) 
	error('---> No display_latency was specified, or was specified improperly. Must be a numeric value for display device latency (specified in seconds). ');

end

data_out = data_in;								%set the default

% for each trial of data in data_in
for ii = 1:length(data_in)
	if ~isempty(data_in(ii).VIDEO_LATENCY)
		refresh_period = 1/data_in(ii).VIDEO_SETTINGS.REFRESH_RATE;				%reported video refresh rate in sec (GUI computer clock)
		%reported video refresh rate is rounded to the nearest ms, and differences
		%of a few percent between GUI and real-time computer is possible.
		%refresh_period_floor puts minimum limit on the different that could be
		%recorded by the real-time computer.
		refresh_period_floor = 0.001 * floor( 0.95* refresh_period *1000);						
		ack_time_corrected = data_in(ii).VIDEO_LATENCY.ACK_TIMES;

		% The following correction is based on the fact that the time between video
		% display refresh is the refresh_period, which on the real-time computer
		% has a minimum expected value of refresh_period_floor.  As such, the time
		% between any two adjacent video acknowledgements must be
		% >=refresh_period_floor.  Any discrepancies with this fact are corrected
		% here.
		for jj = length(ack_time_corrected):-1:2
			if (ack_time_corrected(jj) - ack_time_corrected(jj-1)) < refresh_period_floor	%use of floor ensures that only those periods 
				ack_time_corrected(jj - 1) = ack_time_corrected(jj) - refresh_period_floor;
			end
		end

		% The minimum and maximum video latencies are calculated from the SEND and
		% corrected acknowledgement times, plus the following:
		% (1) the addition of a refresh period (required to transmit the image)
		% (2) the display_latency

		data_out(ii).VIDEO_LATENCY.DISPLAY_MIN_TIMES = data_in(ii).VIDEO_LATENCY.SEND_TIMES + refresh_period + display_latency;
		data_out(ii).VIDEO_LATENCY.DISPLAY_MAX_TIMES = ack_time_corrected + refresh_period + display_latency;
	else
		% no video latency data, so do nothing
	end
end
