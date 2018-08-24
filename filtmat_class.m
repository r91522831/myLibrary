function [ fdata ] = filtmat_class( dt, cutoff, data, ftype, forder)

%  filtmat_class - filters data in forward and reverse directions using Butterworth filter
%  -------------   on columns of matrix elements.
%
%  John H. Challis, The Penn. State University (April 24, 1997)
%
%  calling - [ fdata ] = filtmat( dt, cutoff, data, ftype, forder)
%
%  inputs
%  ------
%  dt     - interval between samples  (units - seconds)
%  cutoff - required cut-off frequency/ies  (units - Hertz)
%  data   - the matrix containing the data, assumes individual data sets are in columns.
%  ftype  - specifies the filter type  [optional, default = 1]
%           ftype = 1 -> low-pass filter
%           ftype = 2 -> high-pass
%		    ftype = 3 -> band-pass
%  forder - order of filter  [optional, default = 2]
%
%  output
%  ------
%  fdata - the filtered input data
%
%  notes
%  -----
%  1)  If ftype is not specified a low-pass filter is assumed.
%  2)  If ftype = 2, then input cutoff should be a vector of two elements the lower and upper bounds
%      for the band-pass filter, e.g. cutoff = [ 5 10 ];
%  3)  If filter order (forder) is not specified then it assumed to be 2.
%  4)  As the Butterworth filter is applied in forward and reverse directions its order is effectively doubled.
%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                     %
%  set ftype and forder to defaults if not specified  %
%                                                     %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if nargin == 3
   ftype = 1;
   forder = 2;
end
%
if nargin == 4
   forder = 2;
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                           %
%  adjust cut-off to allow for double pass  %
%                                           %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
cutoff = cutoff / (sqrt(2) - 1) ^(0.5 / forder);


%%%%%%%%%%%%%%%%%%%%%%%%%%
%                        %
%  compute coefficients  %
%                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%
if ftype == 1
   [ b, a ] = butter( forder, 2 * cutoff * dt);					%  low-pass
elseif ftype == 2
   [ b, a ] = butter( forder, 2 * cutoff * dt, 'high');			%  high-pass
else
   [ b, a ] = butter( forder, 2 * cutoff * dt, 'bandpass');		%  band-pass
end


%%%%%%%%%%%%%%%%%%%
%                 %
%  how much data  %
%                 %
%%%%%%%%%%%%%%%%%%%
[ n_rows, n_cols] = size( data );


%%%%%%%%%%%%%%%%%%%%%
%                   %
%  filter the data  %
%                   %
%%%%%%%%%%%%%%%%%%%%%
fdata = zeros(n_rows, n_cols);
for i = 1:n_cols
   fdata(:, i) = filtfilt( b, a, data(:,i) );
end


%
%%
%%% The End %%%
%%
%

%  Additional Notes - the data is organized in columns in a matrix, for example
%  ----------------
%    1,  10
%    2,  11
%    3,  12
%    .,  ..
%    .,  ..
%    9,  19
%
%   so filtmat_class will filter the first column (1, 2, 3,...) and then the second column (10, 11, 12,  ...).
%
%
