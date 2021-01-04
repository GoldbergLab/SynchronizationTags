function [tags, tagData] = findVideoTags(xmlFile, nBits, showPlot)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% findVideoTags: Find binary synchronization tags within Phantom Camera 
%   Control-generated video metadata .xml file
% usage:  [tags, tagData] = findVideoTags(datFile, nBits)
%
% where,
%    tags is a struct array containing a list of the tags found within the
%       tagData. Each element contains the decoded tag ID number, the start
%       index of the tag (rising edge of the start marker), and the stop 
%       index of the tag (falling edge of the end marker).
%    tagData is a logical vector containing the extracted raw tag data.
%    xmlFile is a char array representing the path to a video metadata .xml
%       file
%    nBits is an optional # of bits to expect in the tags, which can
%       increase reliability of tag Ids. Default is NaN, meaning any # of
%       bits will be allowed.
%    showPlot is an optional boolean flag that determines whether or not to
%       plot the extracted tag data in a figure.
%
% See findTags for detailed information about the synchronization tag
%   concept.
%
% findVideoTags will extract the binary synchronization tag data from a 
%   Phantom Camera Control-generated video metadata .xml file
%
% See also: findTags, syncVideoToFPGA, findFPGATags
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('nBits', 'var')
    nBits = NaN;
end
if ~exist('showPlot', 'var')
    showPlot = false;
end


%% Parse XML file:

% relevant xml structure:
%
% <chd>
%   <TIMEBLOCK>
%       <Time frame="458">13:49:26.122 427.66 E</Time>

% Read file
rootNode = xmlread(xmlFile);
% Get list of <Time> elements
timeNodeList = rootNode.getElementsByTagName('Time');
% Find total # of <Time> elements (corresponds to # of frames in video)
N = timeNodeList.getLength;
% Preallocate tagData
tagData = false(1, N);
% Loop over each frame, extract tag data
for k = 0:N-1
    % Get the text content of <Time> element
    timeText = timeNodeList.item(k).getFirstChild.getTextContent;
    % Look for an "E" at the end of the text, which indicates a "1" in the
    %   binary tag data stream.
    if strcmp(timeText.charAt(timeText.length-1), 'E')
        tagData(k) = true;
    end
end

%% Plot data
if showPlot
    % Plot extracted tag data
    [~, name, ext] = fileparts(xmlFile);
    f = figure('Name', [name, ext]);
    ax = axes(f);
    plot(ax, tagData);
    ylim(ax, [-0.5, 1.5]);
end

%% Find tags in tag data
tags = findTags(tagData, nBits);