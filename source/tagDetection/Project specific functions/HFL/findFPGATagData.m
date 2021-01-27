function tagData = findFPGATagData(datFile, tagFieldName, showPlot)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% findFPGATags: Extract binary synchronization tag data from an FPGA 
%   generated .dat file
% usage:  tagData = findFPGATagData(datFile, tagFieldName)
%
% where,
%    tagData is a logical vector containing the extracted raw tag data.
%    datFile is a char array representing the path to a FPGA .dat file.
%    tagFieldName is a char array representing the header name of the
%       column within the FPGA .dat file that contains the tag data. Default
%       is 'CameraTimestamp'
%    showPlot is an optional boolean flag that determines whether or not to
%       plot the extracted tag data in a figure. (default false)
%
% See findTags for detailed information about the synchronization tag
%   concept.
%
% findFPGATags will extract the binary synchronization tag data from a 
%   FPGA-generated .dat file.
%
% See also: findTags, syncVideoToFPGA, findVideoTagData
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('tagFieldName', 'var')
    tagFieldName = 'CameraTimestamp';
end
if ~exist('showPlot', 'var')
    showPlot = false;
end

%% Read .dat file
warning('off', 'MATLAB:table:ModifiedAndSavedVarnames');
data = readtable(datFile);
warning('on', 'MATLAB:table:ModifiedAndSavedVarnames');

tagData = logical(data.(tagFieldName));

if iscolumn(tagData)
    tagData = tagData';
end

%% Plot data
if showPlot
    [~, name, ext] = fileparts(datFile);
    f = figure('Name', [name, ext]);
    ax = axes(f);
    plot(ax, tagData);
    ylim(ax, [-0.5, 1.5]);
end

% %% Find tags in tag data
% tags = findTags(tagData, nBits);