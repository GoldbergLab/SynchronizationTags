function mappedRanges = mapDataStreams(syncList, baseFile, baseIndexRange, streamIndex)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% mapDataStreams: Map a range of samples in one data stream to a
%   corresponding range of samples in another data stream.
% usage:  matchRanges = mapDataStreams(syncList, baseFile, baseIndexRange, 
%                                      streamIndex)
%
% where,
%    mappedRanges is a struct array with two fields:
%       matchFile - one or more file paths, representing files that match 
%           the base index range, in correct chronological order. The nth 
%           file path corresponseds
%       matchIndexRange - one or more 2-vectors representing ranges of
%           indices in the corresponding match files.
%    syncList - a struct array generated by syncTagStreams. See the
%       syncTagStreams documentation for the structure of this input.
%    baseFile is a path to the base file that you need a correspondence
%       with in a matching data stream.
%    baseIndexRange is a 2-vector representing the range of indices you
%       wish to map onto a matching data stream.
%    streamIndex is an optional index of the matching stream to use, if 
%       there are multiple matching streams. Default is 1.

% See findTags for detailed information about the synchronization tag
%   concept.
%
% mapDataStreams will use a syncList generated by syncTagStreams to map a
%   range of indices in a file from one data stream to a range of indices 
%   in a matching file
%
% See also: findTags, syncTagStreams
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('streamIndex', 'var')
    streamIndex = 1;
end

matches = syncList(strcmp({syncList.file}, baseFile)).matches{streamIndex};

% Initialize output structure
mappedRanges = struct('matchFile', {}, 'matchIndexRange', {});

for k = 1:length(matches)
    [~, matchOverlap] = overlapSegments(baseIndexRange, [1, matches(k).matchFileLength], matches(k).baseOverlap, matches(k).matchOverlap, true);
    if ~isempty(matchOverlap)
        mappedRanges(k).matchFile = matches(k).matchFile;
        mappedRanges(k).matchIndexRange = matchOverlap;
    end
end
