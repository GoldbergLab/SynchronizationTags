function syncList = syncTagStreams(fileStreams, fileParsers, nBits, plotSync)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% syncTagStreams: Create a synchronization list to match multiple file streams
%   together.
% usage:  syncList = syncTagStreams(fileStreams, matchDirection, nBits)
%
% where,
%    syncList is a struct array, one element for each "match from" file
%       (either fpga or video), and a match object indicating one or more
%       "match to" files that contained matching tags, along with alignment
%       info for those corresponding files. syncList has the following
%       structure:
%       
%    syncList = 1xN struct array. N is the number of base files that matched files in other data streams.
%       syncList(k).file = the file path of the kth base file
%       syncList(k).matches = a 1xM cell array, where M is the number of matching data streams provided.
%       syncList(k).matches{j} = match objects from the jth matching data streams matching the kth base file.
%       syncList(k).matches{j}(a) = a struct representing the ath match between files in the jth matching stream and the kth base file.
%       syncList(k).matches{j}(a).baseFile = the base filename, for convenience.
%       syncList(k).matches{j}(a).matchFile = the matching filename
%       syncList(k).matches{j}(a).baseFile = the base filename, for convenience.
%       syncList(k).matches{j}(a).baseOverlap = range of indices in base file that overlap match file.
%       syncList(k).matches{j}(a).matchOverlap = range of indices in match file that overlap base file.
%       syncList(k).matches{j}(a).sampleRateRatio = the detected sample rate ratio between the base file and the match file.
%       syncList(k).matches{j}(a).baseFileLength = # of samples in the base file, for convenience.
%       syncList(k).matches{j}(a).matchFileLength = # of samples in the match file, for convenience.
%
%    fileStreams is a cell array, containing a series of cell arrays, each
%       containing a set of filepaths representing one stream of data. The
%       first stream will be used as the "base" files, and the rest of the
%       files will be matched to the base files. The structure should be:
%
%    fileStreams = {
%      {'fileStreamA_1.aaa', 'fileStreamB_2.aaa', ... 'fileStreamA_N.aaa'},
%      {'fileStreamB_1.bbb', 'fileStreamB_2.bbb', ... 'fileStreamB_N.bbb'},
%       ...
%      {'fileStreamN_1.nnn', 'fileStreamN_2.nnn', ... 'fileStreamN_N.nnn'}
%    }
%
%       Note that there can be any number of files in each stream - they do
%       not have to have the same number.
%    fileParsers is a cell array containing functions that can parse tag 
%       data from the provided file series. There should be one fileParser 
%       for each element of fileStreams, and they should be in commensurate
%       order. So, the call
%
%           tagData = fileParsers{n}(fileStreams{n}{k})
%
%       should yield a 1-D logical array of tag data corresponding to the
%       kth file of file series #n.
%    nBits is an optional # of bits to expect in the tags, which can
%       increase reliability of tag IDs, but is generally not necessary. 
%       Default is NaN, meaning any # of bits will be allowed.
%    plotSync is an option boolean flag indicating whether or not to plot
%       the synchronized tag data
%
% See findTags for detailed information about the synchronization tag
%   concept.
%
% syncTagStreams will search through sets of data and use the binary 
%   synchronization tags found within each file to generate alignment 
%   information for the corresponding data streams
%
% See also: findTags
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('nBits', 'var')
    nBits = NaN;
end
if ~exist('plotSync', 'var')
    plotSync = true;
end

% Output file counts
for n = 1:length(fileStreams)
    fprintf('%d files provided in stream #%d\n', length(fileStreams{n}), n);
end
%% Loop through DAT files and extract tag data
fprintf('Parsing tag data from files...\n');
tagData = {};
for n = 1:length(fileStreams)
    tagData{n} = struct('file', {}, 'tagData', {});
    fprintf('\tParsing stream #%d:', n)
    for k = 1:length(fileStreams{n})
        fprintf(' %d', k)
        file = fileStreams{n}{k};
        tagDataArray = fileParsers{n}(file);
        tagDataIdx = length(tagData{n})+1;
        tagData{n}(tagDataIdx).stream = n;
        tagData{n}(tagDataIdx).file = file;
        tagData{n}(tagDataIdx).tagData = tagDataArray;
    end
    fprintf('\n')
end
fprintf('...done parsing tag data from files.\n');

%% Extract tags from tag data
fprintf('Extracting tags from tag data...\n');
tags = {};
tagIDs = {};
for n = 1:length(fileStreams)
    fprintf('\tExtracting tags from stream %d...\n', n)
    tags{n} = extractTagsFromDataset(tagData{n}, nBits);
    fprintf('\t...found %d tags.\n', length(tags{n}));
    tagIDs{n} = [tags{n}.ID];
end

%% Construct synchronization mapping between files (syncList)
syncList = struct('file', {}, 'matches', {});
for k = 1:length(tags{1})
    baseTag = tags{1}(k);
    baseTagID = baseTag.ID;
    
    baseIdx = find(strcmp({syncList.file}, baseTag.file), 1);
    % Have we found matches for this tag before?
    if isempty(baseIdx)
        % This is a new base file - haven't encountered it yet.
        baseIdx = length(syncList)+1;
        syncList(baseIdx).matches = [];
        syncList(baseIdx).file = baseTag.file;
        syncList(baseIdx).matches = {};
    end
    
    for n = 2:length(fileStreams)
        m = n-1;
        % Select the matchTag that matches the base tag ID
        matchTagsSelected = tags{n}([tags{n}.ID] == baseTagID);

        for j = 1:length(matchTagsSelected)
            matchTag = matchTagsSelected(j);
            % Get all matches so far, so we can potentially add to it
            if length(syncList(baseIdx).matches) < m
                syncList(baseIdx).matches{m} = [];
            end
            matches = syncList(baseIdx).matches{m};
            % Prepare to add new match data
            if isempty(matches)
                % No matches yet. This'll be the first.
                matchIdx = 1;
                fileAlreadyMatched = false;
            else
                % Check if this matched file has been matched before
                matchIdx = find(strcmp({matches.matchFile}, matchTag.file), 1);
                if isempty(matchIdx)
                    % First time matching this file - add it to the end of the
                    %   match list.
                    fileAlreadyMatched = false;
                    matchIdx = length(matches)+1;
                else
                    % This file has been matched before (via other tags)
                    fileAlreadyMatched = true;
                end
            end

            % Calculate alignment info for match
            [baseOverlap, matchOverlap] = overlapSegments(...
                [1, baseTag.fileLength], ...
                [1, matchTag.fileLength], ...
                [baseTag.start, baseTag.end], ...
                [matchTag.start, matchTag.end], true);

            if isempty(baseOverlap)
                % Even though the tag matches, the two files don't overlap.
                continue;
            end

            if fileAlreadyMatched
                if ~all(matches(matchIdx).baseOverlap == baseOverlap) || ...
                   ~all(matches(matchIdx).matchOverlap == matchOverlap)
                    maxDiscrepancy = max(abs([matches(matchIdx).baseOverlap - baseOverlap, matches(matchIdx).matchOverlap == matchOverlap]));
                    fprintf('\tDisagreement about file overlaps based on different tags (%s)! Max discrepancy=%d\n', num2str(matchTag.ID), maxDiscrepancy);
                    disp(baseOverlap)
                    disp(matches(matchIdx).baseOverlap)
                    disp(matchOverlap)
                    disp(matches(matchIdx).matchOverlap)
                end
            end

            % Add new match info
            matches(matchIdx).baseFile = baseTag.file;
            matches(matchIdx).matchFile = matchTag.file;
            matches(matchIdx).baseOverlap = baseOverlap;
            matches(matchIdx).matchOverlap = matchOverlap;
            matches(matchIdx).sampleRateRatio = (matchOverlap(2)-matchOverlap(1))/(baseOverlap(2)-baseOverlap(1));
            matches(matchIdx).baseFileLength = baseTag.fileLength;
            matches(matchIdx).matchFileLength = matchTag.fileLength;

            syncList(baseIdx).matches{m} = matches;
        end
    end
end

if plotSync
    for k = 1:length(syncList)
        plotMatches(syncList(k), tagData, tags);
    end
end

function tags = extractTagsFromDataset(tagDataSet, nBits)
% Takes a set of tagData from possibly consecutive files, and extracts all
% tags.
if ~exist('nBits', 'var')
    nBits = NaN;
end
tags = struct('ID', {}, 'start', {}, 'end', {}, 'file', {}, 'fileLength', {}, 'reliability', {});

for k = 1:length(tagDataSet)
    file = tagDataSet(k).file;
    [~, name, ext] = fileparts(file);
    fprintf('   Finding tags for %s...\n', [name, ext]);
    % Combine previous file, this file, and next file, and find tags (this
    %   catches sub-tag-length file overlaps
    if k == 1
        preTagData = [];
    else
        preTagData = tagDataSet(k-1).tagData;
    end
    if k == length(tagDataSet)
        postTagData = [];
    else
        postTagData = tagDataSet(k+1).tagData;
    end
    
    newTags = findTags(tagDataSet(k).tagData, preTagData, postTagData, nBits);

    fprintf('   ...done. Found %d tags\n', length(newTags));
    fileField = repmat({file}, [1, length(newTags)]);
    [newTags.file] = fileField{:};
    fileLengthField = repmat({length(tagDataSet(k).tagData)}, [1, length(newTags)]);
    [newTags.fileLength] = fileLengthField{:};
    tags = [tags, newTags];
end

fprintf('\t\tChecking for duplicated tags...\n')
[duplicateTags, ~] = getCounts(tags, @(t)t, @areTagsDuplicates);
if duplicateTags > 0
    error('%s duplicate tag IDs in fpga dat files! Make sure you only run this function on one "run" of data at a time. Exiting.', num2str([duplicateTags.ID]));
end
fprintf('\t\t...no duplicated tags found.\n');

function duplicate = areTagsDuplicates(t1, t2)
% Check if two tags are duplicates
sameID = (t1.ID == t2.ID);
sameFilename = strcmp(t1.file, t2.file);
notMatchingPartialTags = ~(t1.start < 1 && t2.end > t2.fileLength || t2.start < 1 && t1.end > t1.fileLength);
duplicate = sameID && (sameFilename || notMatchingPartialTags);

function tif = tagInFile(tag, fileSize)
% Determine if the tag is at least partially in the file or not
tif = ~isempty(overlapSegments([tag.start, tag.end], [1, fileSize]));

function plotMatches(syncElement, tagDataSet, tagSet)
% Plot matches:
baseTagData = getTagData(syncElement.file, tagDataSet{1});
baseTags = tagSet{1}(strcmp({tagSet{1}.file}, syncElement.file));
[~, name, ext] = fileparts(syncElement.file);
f = figure;
ax = axes(f);
plot(ax, 1:length(baseTagData), baseTagData, 'DisplayName', [name, ext]);
hold(ax, 'on');
% Plot tag IDs
for k = 1:length(baseTags)
    text(ax, (baseTags(k).start + baseTags(k).end)/2, 0.5, num2str(baseTags(k).ID),'HorizontalAlignment','center')
end

xDisplayRange = [min([baseTags.start, 1]), max([baseTags.end, length(baseTagData)])];

totalNMatch = 0;
for n = 2:length(tagDataSet)
    m = n - 1;
    nMatch = length(syncElement.matches{m});
    totalNMatch = totalNMatch + nMatch;
    for k = 1:nMatch
        matchElement = syncElement.matches{m}(k);
        matchTagData = getTagData(matchElement.matchFile, tagDataSet{n});
        matchTags = tagSet{n}(strcmp({tagSet{n}.file}, matchElement.matchFile));
        matchOverlapIdx = matchElement.matchOverlap(1):matchElement.matchOverlap(2);
        baseOverlapIdx = linspace(matchElement.baseOverlap(1), matchElement.baseOverlap(2), length(matchOverlapIdx));
        [~, name, ext] = fileparts(matchElement.matchFile);
        plot(ax, baseOverlapIdx, matchTagData(matchOverlapIdx)-1.5*k*m, 'DisplayName', [name, ext]);
        for j = 1:length(matchTags)
            x = (matchTags(j).start + matchTags(j).end)/2;
            xNew = mapCoordinate(x, matchElement.matchOverlap, matchElement.baseOverlap);
            if xNew >= xDisplayRange(1) && xNew <= xDisplayRange(2)
                text(ax, xNew, 0.5 - 1.5*k*m, num2str(matchTags(j).ID),'HorizontalAlignment','center');
            end
        end
    end
end
xlim(ax, xDisplayRange);
ylim(ax, [-0.5 - 1.5*totalNMatch, 1.5]);
legend(ax, 'Interpreter', 'none');

function xNew = mapCoordinate(x, xRange, xRangeNew)
% Map coordinate from one space to another
dx = xRange(2) - xRange(1);
dxNew = xRangeNew(2) - xRangeNew(1);
xNew = (x - xRange(1)) * dxNew / dx + xRangeNew(1);


function [counts, elements] = getCounts(x, idfunc, cmpfunc)
if ~exist('idfunc', 'var')
    idfunc = @(x)x;
end
if ~exist('cmpfunc', 'var')
    cmpfunc = @(x, y)x==y;
end
elements = unique2(x, idfunc, cmpfunc);
counts = zeros(size(elements));
dims = 1:length(size(x));
for k = 1:length(elements)
    for j = 1:length(x)
        counts(k) = sum(cmpfunc(idfunc(x(j)), idfunc(elements(k))), dims);
    end
end

function elements = unique2(x, idfunc, cmpfunc)
if ~exist('idfunc', 'var')
    idfunc = @(x)x;
end
if ~exist('cmpfunc', 'var')
    cmpfunc = @(x, y)x==y;
end
elements = [];
for k = 1:length(x)
    isUnique = true;
    for j = 1:length(elements)
        if cmpfunc(idfunc(x(k)), idfunc(elements(j)))
            isUnique = false;
            break;
        end
    end
    if isUnique
        elements = [elements, x(k)];
    end
end

function tagData = getTagData(filePath, allTagData)
tagData = allTagData(strcmp({allTagData.file}, filePath)).tagData;

function ext = getExtension(path)
[~, ~, ext] = fileparts(path);

% function newTagIds = deduplicateTagIds(tagIds)
% tagIdDuplicateCounts = [];
% for k = 1:length(tagIds)
%     tagIdDuplicateCounts(k) = sum(tagIds(1:k-1) == tagIds(k));
% end
% tagIdDuplicateCounts = 1-(2.^(-tagIdDuplicateCounts)); 
% newTagIds = tagIds + tagIdDuplicateCounts;