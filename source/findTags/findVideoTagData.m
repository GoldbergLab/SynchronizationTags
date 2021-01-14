function tagData = findVideoTagData(xmlFile, showPlot)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% findVideoTagData: Extract binary synchronization tag data within Phantom
%   Camera Control-generated video metadata .xml file
% usage:  tagData = findVideoTagData(datFile)
%
% where,
%    tagData is a logical vector containing the extracted raw tag data.
%    xmlFile is a char array representing the path to a video metadata .xml
%       file
%    showPlot is an optional boolean flag that determines whether or not to
%       plot the extracted tag data in a figure. (default false)
%
% See findTags for detailed information about the synchronization tag
%   concept.
%
% findVideoTagData will extract the binary synchronization tag data from a 
%   Phantom Camera Control-generated video metadata .xml file
%
% See also: findTags, syncVideoToFPGA, findFPGATagData
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('showPlot', 'var')
    showPlot = false;
end

%% Parse XML file:

% relevant xml structure:
%
% <chd>
%   <CineFileHeader>
%       <TotalImageCount>5277</TotalImageCount>
%   <TIMEBLOCK>
%       <Time frame="458">13:49:26.122 427.66 E</Time>

% Read file
rootNode = xmlread(xmlFile);
% Get image count, for double-checking that we got all the frames.
cineFileHeaders = rootNode.getElementsByTagName('CineFileHeader');
cineFileHeader = cineFileHeaders.item(0);
totalImageCounts = cineFileHeader.getElementsByTagName('TotalImageCount');
totalImageCount = totalImageCounts.item(0);
Ncheck = str2double(totalImageCount.getFirstChild.getTextContent);
% Find section containing time elements. Careful! There is one <Time>
%   element that does NOT represent a frame - it's in the <CineFileHeader>
%   node. It was throwing me off by adding an extra spurious 0 to the data.
timeBlockNodes = rootNode.getElementsByTagName('TIMEBLOCK');
timeBlockNode = timeBlockNodes.item(0);
% Get list of <Time> elements
timeNodeList = timeBlockNode.getElementsByTagName('Time');
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
        tagData(k+1) = true;
    end
end

if N ~= Ncheck
    error('Error reading tag data from file %s\nNumber of samples retrieved from file do not match the number of recorded frames!', xmlFile)
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

% %% Find tags in tag data
% tags = findTags(tagData, nBits);