%ZIP_LOAD Load and format c3d files from zip archives created with 
%   Dexterit-E 3.0 and higher.
%
%   C3D_DATA = ZIP_LOAD opens all zip files in the correct directory and
%   loads each recorded .c3d file stored in the zips and outputs the data
%   into the structure C3D_DATA.  Each element of C3D_DATA corresponds to a
%   single .zip file.   
%
%   C3D_DATA contains two fields:
%		.c3d - this field contains all of the data from the .c3d files
%		stored in the .zip file.  
%		.filename - the filename of the .zip file
%
%   The format of the data in the .c3d field is identical to the format
%   loaded up by C3D_LOAD for data saved by Dexterit-E 2.3 and earlier.
%   Please see C3D_LOAD for a description of this format.  
% 
%   C3D_DATA = ZIP_LOAD(ZIP_FILENAME) only opens ZIP_FILENAME.
%   ZIP_FILENAME can contain the '*' wildcard.
%   
%   C3D_DATA = ZIP_LOAD(ZIP_FILENAME1, ZIP_FILENAME2) opens ZIP_FILENAME1
%   and ZIP_FILENAME2 and outputs the data into the C3D_DATA structure.
%   ZIP_FILENAME1 and ZIP_FILENAME2 can both contain the % '*' wildcard.
%   Any number of filenames can be listed.  
%   
%   C3D_DATA = C3D_LOAD('dir', DIRECTORY) looks for all .zip files in
%   DIRECTORY.
%   
%   C3D_DATA = ZIP_LOAD('c3d_filename', C3D_FILENAME) will load up only
%   those c3d files within specified zip files that correspond to
%   C3D_FILENAME.   C3D_FILENAME can contain the '*' wildcard.  
%  
%   In addition, this method takes the 'ignore' and 'keep' arguments that
%   C3D_LOAD does (applying them through calls to C3D_LOAD).  Please see
%   C3D_LOAD for the argument descriptions. 
%



% Written by Ian Brown November 2010
% BKIN Technologies, Kingston, ON

% Modified by Duncan McLean for BKIN Technologies, Kingston, ON. Nov, 2010
% Takes all of the arguments that c3d_load does.
%
function c3dstruct = zip_load(varargin)

x = 1;
num_files = 0;
% Save old directory
olddir = cd;
% be sure we jump back to the right place on exit
% C = onCleanup(@()cd(olddir));

newArgs = {};
c3d_filename = '*.c3d';		% by default, load all c3d files

while x <= length(varargin)
    % See if the user included a directory to look in
    if strncmpi(varargin{x}, 'dir', 3)
        x = x + 1;
        cd(varargin{x});
    elseif strncmpi(varargin{x}, 'c3d_filename', 12)
        x = x + 1;
        c3d_filename = varargin{x};
    elseif strncmpi(varargin{x}, 'ignore', 6)
        x = x + 1;
        newArgs = cat(2, newArgs, 'ignore');
        newArgs = cat(2, newArgs, varargin{x});
    elseif strncmpi(varargin{x}, 'keep', 4)
        x = x + 1;
        newArgs = cat(2, newArgs, 'keep');
        newArgs = cat(2, newArgs, varargin{x});
	else
		num_files = num_files + 1;
 		zipfiles{num_files} = varargin{x};
        varargin{x} = [];
    end
    x = x + 1;
end

% ensure that c3d_filename passed to c3d_load ends in .c3d
temp = strfind(c3d_filename, '.');
if isempty(temp)
	c3d_filename = [c3d_filename '.c3d'];
else
	c3d_filename = [c3d_filename(1:temp) 'c3d'];
end


if num_files > 0
	% check for '*' wild card in filename - expand file list if it exists
	for ii = num_files:-1:1
		if ~isempty(findstr('*', zipfiles{ii}))
			temp = dir(zipfiles{ii});
			zipfiles = [zipfiles {temp.name}];
			%erase the filename with the wildcard
			zipfiles(ii) = [];		
		end
	end
	num_files = length(zipfiles);
	if num_files == 0
		disp(strvcat(' ','WARNING!!!  No zip files found.'));
		c3dstruct = [];
		return;
	end
else
	% Get all c3d files
	zipfiles = dir('*.zip');
	if isempty(zipfiles)
		disp(strvcat(' ','WARNING!!!  No zip files found in:', pwd));
		c3dstruct = [];
		return;
	end
	zipfiles = {zipfiles.name};
end

c3dstruct = [];
% we need to current directory so we can jump from it to the temp folder.
zipRootFolder = cd;

for x = 1:length(zipfiles)
    %make a temp directory to place files in
    unzipToName = tempname();
    unzip(zipfiles{x}, unzipToName)
    cd (unzipToName)
    
    %Modified November 17, 2011 by JMP to accommodate Mac and PC directory
    %structures.
    if ~exist('raw\common.c3d', 'file') && ~exist('raw/common.c3d', 'file')
		disp(strvcat(' ','WARNING!!!  Not a Dexterit-E zip file: ', zipfiles{x}));
        cd(zipRootFolder)
        rmdir(unzipToName, 's');
        continue
    end
    
	cd( 'raw' );
    
    % get the common file so we can use it to place parameters in 
    % all other c3d structs.
    common_data = c3d_load('common.c3d', newArgs{:});
    delete('common.c3d');
    
    % bulk load the c3d files
    zip_data.c3d = c3d_load(c3d_filename, newArgs{:});    
    zip_data.filename = zipfiles(x);
    
    cd ('..');
	% if there are analysis results in the exam then load them
    if exist('analysis/analysis.c3d', 'file') || exist('analysis\analysis.c3d', 'file')
        cd ('analysis')
        zip_data.analysis = c3d_load('analysis.c3d', newArgs{:});
    end
    
    %clean up the temp folder we made.
    cd(zipRootFolder)
    rmdir(unzipToName, 's');

    common_fields = fieldnames(common_data);

    % remove the ...HandX, ...HandY and FILENAME fields
    common_fields(strmatch('Right_HandX', common_fields)) = [];
    common_fields(strmatch('Right_HandY', common_fields)) = [];
    common_fields(strmatch('Left_HandX', common_fields)) = [];
    common_fields(strmatch('Left_HandY', common_fields)) = [];
    common_fields(strmatch('FILE_NAME', common_fields)) = [];

    %for each trial, add the common data back in
    for ii = 1:length(zip_data.c3d)
        for jj = 1:length(common_fields)
            zip_data.c3d(ii).(common_fields{jj}) = common_data.(common_fields{jj});
        end        
    end
    
    
    
    zip_data = correctXTorque(zip_data);
    c3dstruct = cat(1, c3dstruct, zip_data);
end

