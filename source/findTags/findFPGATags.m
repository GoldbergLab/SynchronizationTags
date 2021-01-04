function [tags, tagData] = findFPGATags(datFile, tagFieldName, nBits, showPlot)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% findFPGATags: Find binary synchronization tags within an FPGA generated 
%   .dat file
% usage:  [tags, tagData] = findFPGATags(datFile, tagFieldName, nBits)
%
% where,
%    tags is a struct array containing a list of the tags found within the
%       tagData. Each element contains the decoded tag ID number, the start
%       index of the tag (rising edge of the start marker), and the stop 
%       index of the tag (falling edge of the end marker).
%    tagData is a logical vector containing the extracted raw tag data.
%    datFile is a char array representing the path to a FPGA .dat file.
%    tagFieldName is a char array representing the header name of the
%       column within the FPGA .dat file that contains the tag data. Default
%       is 'CameraTimestamp'
%    nBits is an optional # of bits to expect in the tags, which can
%       increase reliability of tag Ids. Default is NaN, meaning any # of
%       bits will be allowed.
%    showPlot is an optional boolean flag that determines whether or not to
%       plot the extracted tag data in a figure.
%
% See findTags for detailed information about the synchronization tag
%   concept.
%
% findFPGATags will extract the binary synchronization tag data from a 
%   FPGA-generated .dat file, then extract the tags from that data.
%
% See also: findTags, syncVideoToFPGA, findVideoTags
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('nBits', 'var')
    nBits = NaN;
end
if ~exist('tagFieldName', 'var')
    tagFieldName = 'CameraTimestamp';
end
if ~exist('showPlot', 'var')
    showPlot = false;
end

%% Read .dat file
data = readtable(datFile);

tagData = logical(data.(tagFieldName));

%% Plot data
if showPlot
    [~, name, ext] = fileparts(datFile);
    f = figure('Name', [name, ext]);
    ax = axes(f);
    plot(ax, tagData);
    ylim(ax, [-0.5, 1.5]);
end

%% Find tags in tag data
tags = findTags(tagData, nBits);