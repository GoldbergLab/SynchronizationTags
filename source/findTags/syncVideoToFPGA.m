function syncList = syncVideoToFPGA(videoRootDir, fpgaRootDir, matchDirection, nBits, plotSync)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% syncVideoToFPGA: Create a synchronization list to match FPGA and video files together.
% usage:  syncList = syncVideoToFPGA(videoRootDir, fpgaRootDir, 
%                                       matchDirection, nBits)
%
% where,
%    syncList is a struct array, one element for each "match from" file
%       (either fpga or video), and a match object indicating one or more
%       "match to" files that contained matching tags, along with alignment
%       info for those corresponding files.
%    videoRootDir is the root directory in which to look for the video .xml
%       metadata files.
%    fpgaRootDir is the root directory in which to look for the fpga .dat
%       files.
%    matchDirection is an optional char array indicating whether to match video to FPGA
%       or FPGA to video. One of {'FPGAToVideo', 'VideoToFPGA'}. Default is
%       'VideoToFPGA'
%    nBits is an optional # of bits to expect in the tags, which can
%       increase reliability of tag IDs, but is generally not necessary. 
%       Default is NaN, meaning any # of bits will be allowed.
%    plotSync is an option boolean flag indicating whether or not to plot
%       the synchronized tag data
%
% See findTags for detailed information about the synchronization tag
%   concept.
%
% syncVideoToFPGA will search through a set of video .xml metadata files, 
%   and fpga .dat files, and use the binary synchronization tags found within
%   each file to generate alignment information for the corresponding video
%   and fpga data.
%
% See also: findTags, findFPGATags, findVideoTags
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('matchDirection', 'var')
    matchDirection = 'VideoToFPGA';    
end
if ~exist('nBits', 'var')
    nBits = NaN;
end
if ~exist('plotSync', 'var')
    plotSync = true;
end

% videoRootDir = 'C:\Users\Brian Kardon\Dropbox\Documents\Work\Cornell Lab Tech\Projects\Synchronization\testing\HFL test data';
% fpgaRootDir = 'C:\Users\Brian Kardon\Dropbox\Documents\Work\Cornell Lab Tech\Projects\Synchronization\testing\HFL test data\test2';
% Find FPGA .dat files and video .xml files
fprintf('Finding FPGA .dat files...\n');
datFiles = findFilesByRegex(fpgaRootDir, '.*\.[dD][aA][tT]', false, false);
fprintf('...done. Found %d .dat files.\n', length(datFiles));
fprintf('Finding video .xml files...\n');
xmlFiles = findFilesByRegex(videoRootDir, '.*\.[xX][mM][lL]', false, false);
fprintf('...done. Found %d .xml files.\n', length(xmlFiles));

fprintf('\n');
fprintf('Extracting tag data from files...\n');
warning('off', 'MATLAB:table:ModifiedAndSavedVarnames');
%% Loop through DAT files and extract tag data
datTagData = struct('file', {}, 'tagData', {});
for k = 1:length(datFiles)
    file = datFiles{k};
    tagData = findFPGATagData(file, 'CameraTimestamp');
    tagDataIdx = length(datTagData)+1;
    datTagData(tagDataIdx).file = file;
    datTagData(tagDataIdx).tagData = tagData;
end
%% Loop through XML files and extract tag data
xmlTagData = struct('file', {}, 'tagData', {});
for k = 1:length(xmlFiles)
    file = xmlFiles{k};
    tagData = findVideoTagData(file);
    tagDataIdx = length(xmlTagData)+1;
    xmlTagData(tagDataIdx).file = file;
    xmlTagData(tagDataIdx).tagData = tagData;
end
warning('on', 'MATLAB:table:ModifiedAndSavedVarnames');
fprintf('...done extracting tag data from files.\n');

%% Extract tags from tag data
datTags = extractTagsFromDataset(datTagData, nBits);
xmlTags = extractTagsFromDataset(xmlTagData, nBits);

datTagIDs = [datTags.ID];
xmlTagIDs = [xmlTags.ID];
fprintf('\n');
fprintf('Tags found in .dat files:\n')
disp(datTagIDs)
fprintf('Tags found in .xml files:\n')
disp(xmlTagIDs)
fprintf('\n')

if strcmp(matchDirection, 'VideoToFPGA')
    baseTags = datTags;
    matchTags = xmlTags;
    baseTagData = datTagData;
    matchTagData = xmlTagData;
elseif strcmp(matchDirection, 'FPGAToVideo')
    baseTags = xmlTags;
    matchTags = datTags;
    baseTagData = xmlTagData;
    matchTagData = datTagData;
    
else
    fprintf('Invalid match direction: %s', matchDirection);
    return;
end

%% Construct synchronization mapping between files (syncList)
syncList = struct('file', {}, 'matches', {});
for k = 1:length(baseTags)
    baseTag = baseTags(k);
    baseTagID = baseTag.ID;
    fprintf('Processing base tag %d\n', baseTagID);
    fprintf('Base file = %s\n', baseTag.file);
    
    % Have we found matches for this tag before?
    baseIdx = find(strcmp({syncList.file}, baseTag.file), 1);
    if isempty(baseIdx)
        % This is a new base file - haven't encountered it yet.
        baseIdx = length(syncList)+1;
        syncList(baseIdx).matches = [];
    end
    
    % Select the matchTag that matches the base tag ID
    matchTagsSelected = matchTags([matchTags.ID] == baseTagID);

    for j = 1:length(matchTagsSelected)
        matchTag = matchTagsSelected(j);
        fprintf('\tProcessing match tag %d\n', matchTag.ID);
        fprintf('\tMatch file = %s\n', matchTag.file);
        % Get all matches so far, so we can potentially add to it
        matches = syncList(baseIdx).matches;
        % Prepare to add new match data
        if isempty(matches)
            % No matches yet. This'll be the first.
            matchIdx = 1;
            fileAlreadyMatched = false;
        else
            % Check if this matched file has been matched before
            matchIdx = find(strcmp({matches.matchFile}, matchTag.file), 1);
            if isempty(matchIdx)
                % First time matching this file - add it to the end.
                fileAlreadyMatched = false;
                matchIdx = length(matches)+1;
            else
                % This file has been matched before (with other tags)
                fileAlreadyMatched = true;
            end
        end
        
        % Calculate alignment info for match
        baseTagFileTagData = getTagData(baseTag.file, baseTagData);
        matchedTagFileTagData = getTagData(matchTag.file, matchTagData);

        [baseOverlap, matchOverlap] = overlapSegments(...
            [1, length(baseTagFileTagData)], ...
            [1, length(matchedTagFileTagData)], ...
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
                fprintf('Disagreement about file overlaps based on different tags (%s)! Max discrepancy=%d\n', num2str(matchTag.ID), maxDiscrepancy);
                disp(baseOverlap)
                disp(matches(matchIdx).baseOverlap)
                disp(matchOverlap)
                disp(matches(matchIdx).matchOverlap)
                disp('hi')
            end
        end
        
        % Add new match info
        matches(matchIdx).baseFile = baseTag.file;
        matches(matchIdx).matchFile = matchTag.file;
        matches(matchIdx).baseOverlap = baseOverlap;
        matches(matchIdx).matchOverlap = matchOverlap;
        matches(matchIdx).sampleRateRatio = (matchOverlap(2)-matchOverlap(1))/(baseOverlap(2)-baseOverlap(1));
        
        syncList(baseIdx).matches = matches;
        syncList(baseIdx).file = baseTag.file;
    end
end

if plotSync
    for k = 1:length(syncList)
        plotMatches(syncList(k), baseTagData, matchTagData, baseTags, matchTags);
    end
end

function tags = extractTagsFromDataset(tagDataSet, nBits)
% Takes a set of tagData from possibly consecutive files, and extracts all
% tags.
if ~exist('nBits', 'var')
    nBits = NaN;
end
tags = struct('ID', {}, 'start', {}, 'end', {}, 'file', {}, 'fileLength', {});

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
    extendedTagData = [preTagData, tagDataSet(k).tagData, postTagData];
    newTagsExtended = findTags(extendedTagData, nBits, Inf, length(preTagData));

    % Filter out tags that aren't actually in this file:
    newTags = struct('ID', {}, 'start', {}, 'end', {});
    for j = 1:length(newTagsExtended)
        if tagInFile(newTagsExtended(j), length(tagDataSet(k).tagData))
            newTags(end+1) = newTagsExtended(j);
        end
    end
    fprintf('   ...done. Found %d tags\n', length(newTags));
    fileField = repmat({file}, [1, length(newTags)]);
    [newTags.file] = fileField{:};
    fileLengthField = repmat({length(tagDataSet(k).tagData)}, [1, length(newTags)]);
    [newTags.fileLength] = fileLengthField{:};
    tags = [tags, newTags];
end

disp('Checking for duplicated tags...')
[duplicateTags, ~] = getCounts(tags, @(t)t, @areTagsDuplicates);
if duplicateTags > 0
    error('%s duplicate tag IDs in fpga dat files! Make sure you only run this function on one "run" of data at a time. Exiting.', num2str([duplicateTags.ID]));
end

function duplicate = areTagsDuplicates(t1, t2)
% Check if two tags are duplicates
sameID = (t1.ID == t2.ID);
sameFilename = strcmp(t1.file, t2.file);
notMatchingPartialTags = ~(t1.start < 1 && t2.end > t2.fileLength || t2.start < 1 && t1.end > t1.fileLength);
duplicate = sameID && (sameFilename || notMatchingPartialTags);

function tif = tagInFile(tag, fileSize)
% Determine if the tag is at least partially in the file or not
tif = ~isempty(overlapSegments([tag.start, tag.end], [1, fileSize]));

function plotMatches(syncElement, baseTagDataSet, matchTagDataSet, baseTagSet, matchTagSet)
% Plot matches:
baseTagData = getTagData(syncElement.file, baseTagDataSet);
baseTags = baseTagSet(strcmp({baseTagSet.file}, syncElement.file));
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

nMatch = length(syncElement.matches);
for k = 1:nMatch
    matchElement = syncElement.matches(k);
    matchTagData = getTagData(matchElement.matchFile, matchTagDataSet);
    matchTags = matchTagSet(strcmp({matchTagSet.file}, matchElement.matchFile));
    matchOverlapIdx = matchElement.matchOverlap(1):matchElement.matchOverlap(2);
    baseOverlapIdx = linspace(matchElement.baseOverlap(1), matchElement.baseOverlap(2), length(matchOverlapIdx));
    [~, name, ext] = fileparts(matchElement.matchFile);
    plot(ax, baseOverlapIdx, matchTagData(matchOverlapIdx)-1.5*k, 'DisplayName', [name, ext]);
%     r = fill(ax,...
%         [matchElement.baseOverlap(1), matchElement.baseOverlap(1), matchElement.baseOverlap(2), matchElement.baseOverlap(2)], ...
%         [-1.5*(k-1)-0.1,-1.5*(k-1)-0.4,-1.5*(k-1)-0.4,-1.5*(k-1)-0.1], ...
%         [1, 1, 2, 2]);
    for j = 1:length(matchTags)
        x = (matchTags(j).start + matchTags(j).end)/2;
        xNew = mapCoordinate(x, matchElement.matchOverlap, matchElement.baseOverlap);
        if xNew >= xDisplayRange(1) && xNew <= xDisplayRange(2)
            text(ax, xNew, 0.5 - 1.5*k, num2str(matchTags(j).ID),'HorizontalAlignment','center');
        end
    end
end
xlim(ax, xDisplayRange);
ylim(ax, [-0.5 - 1.5*nMatch, 1.5]);
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

function [oA, oB] = overlapSegments(sA, sB, rA, rB, roundOutputs)
% rA = reference segment A
% rB = reference segment B
% sA = segment to overlap A
% sB = segment to overlap B
% oA = overlapping part of segment A
% oB = overlapping part of segment B
% roundOutputs = boolean flag - round outputs to integer? Default true

if ~exist('roundOutputs', 'var')
    roundOutputs = true;
end

if ~exist('rA', 'var')
    rA = [0, 1];
end
if ~exist('rB', 'var')
    rB = [0, 1];
end

% Check validity of inputs
for segC = {rA, rB, sA, sB}
    seg = segC{1};
    assert(length(seg) == 2, 'Error, all inputs to overlapSegments must have length 2');
    assert(seg(1) <= seg(2), 'Error, all inputs to overlapSegments must have second value greater than the first');
end

% Scale conversion between coordinate system B and A
slopeBtoA = (rA(1) - rA(2))/(rB(1) - rB(2));
slopeAtoB = (rB(1) - rB(2))/(rA(1) - rA(2));

% Function to map numbers in coordinate system B to coordinate system A
mapBtoA = @(nB)slopeBtoA*(nB - rB(1)) + rA(1);
mapAtoB = @(nA)slopeAtoB*(nA - rA(1)) + rB(1);

% Segment B mapped to A coordinate system - "sB in A"
sBinA = mapBtoA(sB);

if sA(2) < sBinA(1) || sBinA(2) < sA(1)
    % |---A---| 
    %             |---B---|
    %          OR
    %             |---A---| 
    %  |---B---|
    oA = [];
elseif sA(1) <= sBinA(1) && sA(2) <= sBinA(2)
    % |---A---| 
    %       |---B---|
    oA = [sBinA(1), sA(2)];
elseif sBinA(1) <= sA(1) && sBinA(2) <= sA(2)
    %       |---A---| 
    %  |---B---|
    oA = [sA(1), sBinA(2)];
elseif sA(1) >= sBinA(1) && sA(2) <= sBinA(2)
    %     |---A---| 
    %   |-----B-----|
    oA = sA;
elseif sBinA(1) >= sA(1) && sBinA(2) <= sA(2)
    %   |-----A-----| 
    %     |---B---|
    oA = sBinA;
else
    error('Failed to identify segment overlap!');
end

oB = mapAtoB(oA);

if roundOutputs
    oA = round(oA);
    oB = round(oB);
end

function ext = getExtension(path)
[~, ~, ext] = fileparts(path);

% function newTagIds = deduplicateTagIds(tagIds)
% tagIdDuplicateCounts = [];
% for k = 1:length(tagIds)
%     tagIdDuplicateCounts(k) = sum(tagIds(1:k-1) == tagIds(k));
% end
% tagIdDuplicateCounts = 1-(2.^(-tagIdDuplicateCounts)); 
% newTagIds = tagIds + tagIdDuplicateCounts;