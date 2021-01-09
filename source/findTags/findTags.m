function tags = findTags(tagBinaryID, nBits, nTags, fileStartOffset)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% findTags: find binary synchronization tags in a vector of digital data.
% usage:  tags = tagData(tagData[, nTags])
%
% where,
%    tags is a struct array containing a list of the tags found within the
%       tagData. Each element contains the decoded tag ID number, the start
%       index of the tag (rising edge of the start marker), and the stop 
%       index of the tag (falling edge of the end marker).
%    tagData is a 1D vector of tag data. It can be logical, or any type
%       that can evaluate to logical.
%    nBits is an optional number of bits to expect in the tag data.
%       Providing this can improve reliability of tag IDs where there is 
%       the possibility of missing chunks of data. If omitted, or set to 
%       NaN (default), tags with any number of bits are identified without 
%       generating an error.
%    nTags is an optional number describing the maximum # of tags to find.
%       If omitted, or set to Inf (default), all tags are found.
%    fileStartOffset is an optional parameter indicating how much the data
%       has been shifted by pre-file data (to account for sub-tag file 
%       overlaps) without affecting the output indices. Default is 0.
%
% Synchronizing two data streams requires a reference signal that is 
%   is present in both streams, and is either identical, or at least has
%   some precisely timed and identifiable corresponding features. A simple
%   solution is to generate a train of square pulses, and record as a 
%   channel in both streams. Then, matching up the nth rising edge in
%   each stream allows us to create a map between the sample indices in the
%   two streams.
%
%   Unfortunately, in practice, this is often insufficient. For example,
%   for long recording sessions, the data will most likely be chunked into
%   many files, and may be very long. Then, to find, for example, the
%   the 1,882,113th pulse in each stream can be very computationaly
%   intensive - we would have to count pulses from the very beginning of
%   both streams to be sure!
%
%   Or suppose one stream has data missing? Perhaps one of the streams had 
%   a hiccup and lost some time, or perhaps a whole file was deleted for 
%   some reason. Then the whole scheme falls apart - how many pulses are 
%   missing? Who knows?! Even worse if the experimenter is unaware of the 
%   data loss. Headache city.
%
%   Synchronization tags are designed to be a step up. They provide
%   regular, uniquely identifiable, binary "time stamps" in each stream 
%   that can be matched up without counting from the beginning of the data
%   streams. See the function findTags for a detailed description of their
%   structure.
%
% findTags looks through a vector of binary data to identify these "binary 
%   synchronization tags". These tags have a particular format, designed
%   to be sampled simultaneously by two different data acquisition devices.
%   After acquisition, the binary sync tags can be used to easily and
%   accurately align the two data streams from the two devices, even if
%   they have time offsets, missing data, or different sampling rates.
%   The format of the binary tags is as follows:
%
%   1_       ________   _       _         _   _   _     ________
%   0_  ____|        |_| |_____| |__ ... | |_| |_| |___|        |______
%
%           |<== M1 ==>|<A>|<B>|<C>| ... |<D>|<E>|<F>|<== M2 ==>|
%                      |<========= Tag ID ==========>|
%
%  M1: Start marker
%  A: 1st bit - an "on" bit
%  B: 2nd bit - an "off" bit
%  C: 3rd bit - an "on" bit
%  ...
%  D: N-2 bit - an "on" bit
%  E: N-1 bit - an "on" bit
%  F: Nth bit - an "on" bit
%  M2: End marker. 
%
%   The start marker (M1) consists of one long high period followed by a low
%       period of width pulseWidth. The high period should be at least
%       several times longer than one pulseWidth
%
%   The Tag ID section (parts A-F) contains a binary representation of a 
%   whole number, which is the "tag ID". A valid tag ID section:
%       - consist of a series of one or more "bits", each of which is one of
%           - "on"  (one high pulseWidth, one low pulseWidth)
%           - "off" (two low pulseWidths)
%       - be unique to the data set. Typically it will be a
%           uniformly increasing binary number starting with 1. 
%       - have at least one "on" bit (a tag with all "off" bits is invalid)
%
%   The end marker (M2) consists of one low pulseWidth, followed by a long high
%       period. The high period should be the same length as the high
%       period for the start marker.
%
% See also: makeSyncTag

% Version: <version>
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('nBits', 'var')
    nBits = NaN;
end
if ~exist('nTags', 'var')
    nTags = Inf;
end
if ~exist('fileStartOffset', 'var')
    fileStartOffset = 0;
end

%% Prepare
% Initialize output tags structure
tags = struct('ID', {}, 'start', {}, 'end', {});

% Ensure tag data is a column vector
if isrow(tagBinaryID)
    tagBinaryID = tagBinaryID';
end

%% Identify pulse locations
% Find where tagData is high
risingEdgeTimes = find(diff(tagBinaryID)==1)+1;
fallingEdgeTimes = find(diff(tagBinaryID)==-1);
% Note that the above will NOT mark a high on the first sample as a rising edge.
%   which is good.

if isempty(risingEdgeTimes) || isempty(fallingEdgeTimes)
    % No tags.
    return;
end

% Discard initial falling edge
if fallingEdgeTimes(1) < risingEdgeTimes(1)
    fallingEdgeTimes(1) = [];
end
% Discard final rising edge
if risingEdgeTimes(end) > fallingEdgeTimes(end)
    risingEdgeTimes(end) = [];
end

if length(fallingEdgeTimes) ~= length(risingEdgeTimes)
    error('Rising/falling edges do not match up. Something has gone wrong.');
end

% Match up rising edges and falling edges to get pulses
pulseWidthTimes = fallingEdgeTimes - risingEdgeTimes + 1;

if length(pulseWidthTimes) < 2
    % No tags found.
    return;
end

%% Determine pulse structure of file
tagStruct = struct();
pulseTypeIdx = kmeans(pulseWidthTimes, 2);
[pw1s, badPw1s] = rmoutliers(pulseWidthTimes(pulseTypeIdx==1), 'quartiles');
[pw2s, badPw2s] = rmoutliers(pulseWidthTimes(pulseTypeIdx==2), 'quartiles');
pw1 = mean(pw1s);
pw2 = mean(pw2s);

pw1std = std(pw1s);
pw2std = std(pw2s);

if pw1 < pw2
    tagStruct.pulseId = 1;
    tagStruct.markerId = 2;
    tagStruct.pulseWidth = pw1;
    tagStruct.markerWidth = pw2;
    tagStruct.pulseStd = pw1std;
    tagStruct.markerStd = pw2std;
    badPulseIdx = find(badPw1s);
    badMarkerIdx = find(badPw2s);
else
    tagStruct.pulseId = 2;
    tagStruct.markerId = 1;
    tagStruct.pulseWidth = pw2;
    tagStruct.markerWidth = pw1;
    tagStruct.pulseStd = pw2std;
    tagStruct.markerStd = pw1std;
    badPulseIdx = find(badPw2s);
    badMarkerIdx = find(badPw1s);
end

if ~isempty(badPulseIdx)
    fprintf('Warning, %d non-standard-width pulses found!\n', length(badPulseIdx));
end
if ~isempty(badMarkerIdx)
    fprintf('Warning, %d non-standard-width markers found!\n', length(badMarkerIdx));
end

%% Check for bad data
% Make sure marker and pulse lengths are stereotyped and widely separated
if tagStruct.pulseWidth + tagStruct.pulseStd > tagStruct.markerWidth - tagStruct.markerStd
    disp('ERROR! Marker widths and pulse widths are not well separated. Tag IDs are unreliable!');
    return;
end
% Make sure pulse length variation is not comparable to pulse length
if tagStruct.pulseStd / tagStruct.pulseWidth > 0.25
    disp('ERROR! Pulse widths have too much variation. Tag IDs are unreliable! Exiting.');
    return;
end
% Make sure marker length variation is not comparable to marker length
if tagStruct.markerStd / tagStruct.markerWidth > 0.25
    disp('ERROR! Marker widths have too much variation. Tag IDs are unreliable! Exiting.');
    return;
end

%% Loop over tag data and find tags
% Generate a list of all potential tags, starting with any consecutive
% pair of markers
markerIdx = find(pulseTypeIdx == tagStruct.markerId);
for k = 1:length(markerIdx)-1
    markerIdx1 = markerIdx(k);
    markerIdx2 = markerIdx(k+1);
%     if any(markerIdx1 == badMarkerIdx) || any(markerIdx2 == badMarkerIdx)
%         disp('Bad marker!')
%         continue;
%     end
    firstDataPulseIdx = markerIdx1+1;
    lastDataPulseIdx = markerIdx2-1;
    if firstDataPulseIdx > lastDataPulseIdx
%         disp('No data pulses found, not a tag, at least not a valid one.')
        continue;
    end
    numDataPulses = lastDataPulseIdx - firstDataPulseIdx + 1;
    if mod(numDataPulses, 2) ~= 0
        disp('Tag is invalid - not mirrored');
        continue;
    end
    dataPulseIdx = (markerIdx1+1):(markerIdx2-1);
%     if ~isempty(intersect(dataPulseIdx, badPulseIdx))
%         disp('Tag contains a bad pulse - skip it.');
%         continue;
%     end
    try
        dataStart = fallingEdgeTimes(markerIdx1) + tagStruct.pulseWidth+1;
        dataEnd = risingEdgeTimes(markerIdx2) - tagStruct.pulseWidth;
        dataMid = (dataStart + dataEnd)/2;
        startTime = dataStart - tagStruct.pulseWidth*2;
        endTime = dataMid;
        startTimeM = dataMid - tagStruct.pulseWidth;
        endTimeM = dataEnd + tagStruct.pulseWidth;
%         fprintf('Total data size (pw) = %f\n', (dataEnd - dataStart)/tagStruct.pulseWidth);
        [tagBinaryID, tagBinaryIDM] = getMirroredTagBinaryID(risingEdgeTimes(dataPulseIdx), startTime, endTime, startTimeM, endTimeM, tagStruct);

        if ~isnan(nBits) && length(tagBinaryID) ~= nBits
            disp('Wrong # of bits - possibly data missing.')
            continue;
        end
        tagId = convertTagDataToId(tagBinaryID);
        tagIdM = convertTagDataToId(tagBinaryIDM);
        if tagId ~= tagIdM
            fprintf('Mirrored tag data does not match! %d ~= %d\n', tagId, tagIdM);
            continue;
        end
        nextTagIndex = length(tags)+1;
        tags(nextTagIndex).ID = tagId;
        tags(nextTagIndex).start = risingEdgeTimes(markerIdx1);
        tags(nextTagIndex).end = fallingEdgeTimes(markerIdx2);
        if (length(tags) >= nTags)
            return;
        end
    catch me
        disp(getReport(me));
    end
end

%% Loop over tags and adjust for fileStartIndex
for k = 1:length(tags)
    tags(k).start = tags(k).start - fileStartOffset;
    tags(k).end = tags(k).end - fileStartOffset;
end

end

function zeroData = getZeros(tagStruct, lastBitTime, currentBitTime)
    % Calculate how many bits were skipped between this one and the last
    %   one - that's how many zeros there are that need to be added.
    if currentBitTime == lastBitTime
        % No bits
        zeroData = '';
        return;
    end
    nZeros = ((currentBitTime - lastBitTime) / (tagStruct.pulseWidth*2)) - 1;
    % Make sure the number of bits is close to an integer - if not,
    %   something's wrong.
    nZerosError = abs(round(nZeros) - nZeros);
    if nZerosError > 0.2
        error('ERROR! Non-integer number of bits (%f) found in tag data. Tag IDs may be unreliable! Skipping this tag.', nZeros);
    end
    nZeros = round(nZeros);
    zeroData = repmat('0', [1, nZeros]);
end

function tagId = convertTagDataToId(tagData)
    tagId = bin2dec(tagData);
end

function [tagBinaryID, tagBinaryIDM] = getMirroredTagBinaryID(dataPulseRisingEdgeTimes, startTime, endTime, startTimeM, endTimeM, tagStruct)
% Extract tag data and mirrored tag data from data portion of a tag
% MidTime is the start time for the mirrored tag data
dpret = dataPulseRisingEdgeTimes(1:(length(dataPulseRisingEdgeTimes)/2));
dpretM = dataPulseRisingEdgeTimes((length(dataPulseRisingEdgeTimes)/2 + 1):end);

tagBinaryID = getTagBinaryID(dpret, startTime, endTime, tagStruct);
tagBinaryIDM = flip(getTagBinaryID(dpretM, startTimeM, endTimeM, tagStruct));
end

function tagBinaryID = getTagBinaryID(dataPulseRisingEdgeTimes, startTime, endTime, tagStruct)
% Decode the tag data from the data segment of a tag
if iscolumn(dataPulseRisingEdgeTimes)
    dataPulseRisingEdgeTimes = dataPulseRisingEdgeTimes';
end
% fprintf('startTime=%d, endTime=%d, dp=%f\n', startTime, endTime, (endTime-startTime)/tagStruct.pulseWidth)
tagBinaryID = '';
lastBitTime = startTime;
for currentBitTime = dataPulseRisingEdgeTimes
    zeroData = getZeros(tagStruct, lastBitTime, currentBitTime);
    tagBinaryID = ['1', zeroData, tagBinaryID];
    lastBitTime = currentBitTime;
end
% Add trailing zeros
zeroData = getZeros(tagStruct, lastBitTime, endTime);
tagBinaryID = [zeroData, tagBinaryID];
end