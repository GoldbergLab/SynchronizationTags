function tagData = makeSyncTag(tagNumbers, pulseWidth, taggingPeriod, tagMarkerDuration, integerBitSize, plotData, timingJitter, makeDeletion, mirrored)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% makeSyncTag: A testing function to generate synchronization tags for 
%    testing the function findTags
% usage:  tagData = makeSyncTag(tagNumbers, pulseWidth, taggingPeriod,
%                                   tagMarkerDuration, integerBitSize, 
%                                   plotData)
%         tagData = makeSyncTag(tagNumbers, pulseWidth, taggingPeriod, 
%                                   tagMarkerDuration, integerBitSize, 
%                                   plotData, timingJitter)
%         tagData = makeSyncTag(tagNumbers, pulseWidth, taggingPeriod, 
%                                   tagMarkerDuration, integerBitSize, 
%                                   plotData, timingJitter, makeDeletion)
%
% where,
%    tagData is the a logical output vector representing the binary tag
%       data generated. Use this as the input to findTags for testing.
%    tagNumbers is a list of integers representing the tag IDs to generate
%    pulseWidth is an integer representing the length of a single pulse
%       width in samples
%    taggingPeriod is the number of pulse widths between the start of one
%       tag and the start of the next.
%    tagMarkerDuration is the number of pulse widths between the start of a
%       tag marker and the end of the same tag marker.
%    integerBitSize is the number of bits to accomodate within the tag
%       data. This will determine the space allotted for tag data between
%       tag markers, and the maximum possible number of unique tags.
%       max unique tags = 2^integerBitSize.
%    plotData is an optional boolean flag indicating whether or not to plot
%       the generated tags in a figure. Default is true.
%    timingJitter is an optional number indicating how much error to add to
%       the timing of the pulses, to simulate real-world jitter. It is the 
%       standard deviation of a distribution from which to draw a timing
%       error for each rising or falling edge. Default is 0 (exact timing)
%    makeDeletion is an optional boolean flag indicating whether or not to
%       randomly delete a section of the output tag data, to simulate real
%       world loss of data.
%    mirrored is an optional boolean flag indicating whether or not the
%       tags should be mirrored; an older version of this project used
%       unmirrored tags. Default is true.
%
%   makeSyncTag is a utility function that synthesizes simulated tag data
%   that can be used to test the tagging functionality, primarly by feeding
%   it into the function findTags. It can generate arbitary trains of tags
%   with arbitrary timing parameters, including real-world jitter and data
%   loss. See findTags for a full description of the tagging system.
%
% See also: findTags
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('timingJitter', 'var') || isempty(timingJitter)
    timingJitter = 0;
end

if ~exist('makeDeletion', 'var') || isempty(makeDeletion)
    makeDeletion = false;
end

if ~exist('plotData', 'var') || isempty(plotData)
    plotData = true;
end

if ~exist('integerBitSize', 'var') || isempty(integerBitSize)
    integerBitSize = ceil(log2(max(tagNumbers)))+1;
end

if ~exist('mirrored', 'var') || isempty(mirrored)
    mirrored = true;
end

if (2^integerBitSize < max(tagNumbers))
    disp('Warning, integerBitSize is not sufficient for the given tag numbers')
end
if any(tagNumbers < 1) || any(floor(tagNumbers) ~= tagNumbers)
    disp('Warning, tagNumbers must be whole numbers (integers > 0)')
end

%pulse = 0*(1:addTimingError(pulseWidth, timingJitter));
tagStart = [(getPulse(tagMarkerDuration*pulseWidth, timingJitter)+1), getPulse(pulseWidth, timingJitter)];
tagEnd = [getPulse(pulseWidth, timingJitter), (getPulse(tagMarkerDuration*pulseWidth, timingJitter)+1)];
tagData = [];
for j = 1:length(tagNumbers)
    tagNumber = tagNumbers(j);
    tagDataPattern = reverse(dec2bin(tagNumber, integerBitSize));
    currentTagData = [tagStart];
    tagBits = [];
    for k = 1:length(tagDataPattern)
        if (strcmp(tagDataPattern(k), '1'))
            tagBits = [tagBits, getOnBit(pulseWidth, timingJitter)];
        else
            tagBits = [tagBits, getOffBit(pulseWidth, timingJitter)];
        end
    end
    if mirrored
        currentTagData = [currentTagData, tagBits, flip(tagBits), tagEnd];
    else
        currentTagData = [currentTagData, tagBits, tagEnd];
    end
    tagData = [tagData, currentTagData];
    if (j < length(tagNumbers))
        tagData = [tagData, getPulse(pulseWidth*(taggingPeriod - floor(length(currentTagData)/pulseWidth)), timingJitter)];
    end
end
% Pad beginning and end so it looks nice
padSize = 20;
tagData = [getPulse(padSize, timingJitter), tagData, getPulse(padSize, timingJitter)];
tagData = logical(tagData);

if makeDeletion
    deletion = sort(randi(length(tagData), [1, 2]));
    tagData = [tagData(1:deletion(1)), tagData(deletion(2):end)];
end

if plotData
    f = figure; 
    l = plot(tagData); 
    ax = l.Parent;
    ax.YLim = [-0.5, 1.25]; 
    ax.XLim = [0, length(tagData)];
    ax.YTick = [];
    ax.XTick = [];
    hold(ax, 'on');
    plot(ax, 1:length(tagData), 0*(1:length(tagData)), 'r:');
    plot(ax, 1:length(tagData), (1+0*(1:length(tagData))), 'g:');
end

function onBit = getOnBit(pulseWidth, timingJitter)
onBit = [(1+getPulse(pulseWidth, timingJitter)), getPulse(pulseWidth, timingJitter)];

function offBit = getOffBit(pulseWidth, timingJitter)
offBit = [getPulse(pulseWidth, timingJitter), getPulse(pulseWidth, timingJitter)];

function pulse = getPulse(pulseWidth, timingJitter)
pulse = zeros(1, addTimingError(pulseWidth, timingJitter));

function timingError = addTimingError(timeIdx, timingJitter)
timingError = max([0, round(normrnd(timeIdx, timingJitter))]);