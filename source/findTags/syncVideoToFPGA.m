function syncList = syncVideoToFPGA(videoRootDir, fpgaRootDir, matchDirection, deduplicate, nBits)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% syncVideoToFPGA: Create a synchronization list to match FPGA and video files together.
% usage:  syncList = syncVideoToFPGA(videoRootDir, fpgaRootDir, 
%                                       matchDirection, deduplicate, nBits)
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
%    deduplicate is an optional boolean flag to attempt to de-duplicate
%       repeated tags based on the alphabetical file order. Not
%       recommended.
%    nBits is an optional # of bits to expect in the tags, which can
%       increase reliability of tag Ids. Default is NaN, meaning any # of
%       bits will be allowed.
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
if ~exist('deduplicate', 'var')
    deduplicate = false;
end
if ~exist('nBits', 'var')
    nBits = NaN;
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
datAndXmlFiles = [datFiles, xmlFiles];

tags = struct('data', {}, 'start', {}, 'end', {}, 'file', {});
fprintf('\n');
fprintf('Finding tags in data...\n');
warning('off', 'MATLAB:table:ModifiedAndSavedVarnames');
allTagData = struct('file', {}, 'tagData', {});
for k = 1:length(datAndXmlFiles)
    file = datAndXmlFiles{k};
    [~, name, ext] = fileparts(file);
    fprintf('   Finding tags for %s...\n', [name, ext]);
    switch lower(ext)
        case '.dat'
            [newTags, tagData] = findFPGATags(file, 'CameraTimestamp', nBits);
        case '.xml'
            [newTags, tagData] = findVideoTags(file, nBits);
    end
    allTagDataIdx = length(allTagData)+1;
    allTagData(allTagDataIdx).file = file;
    allTagData(allTagDataIdx).tagData = tagData;
    
    fprintf('   ...done. Found %d tags\n', length(newTags));
    fileField = repmat({file}, [1, length(newTags)]);
    [newTags.file] = fileField{:};
    tags = [tags, newTags];
end
warning('on', 'MATLAB:table:ModifiedAndSavedVarnames');
fprintf('...done finding tags in data.\n');

datTags = tags(strcmp(cellfun(@getExtension, {tags.file}, 'UniformOutput', false), '.dat'));
xmlTags = tags(strcmp(cellfun(@getExtension, {tags.file}, 'UniformOutput', false), '.xml'));
datTagIDs = [datTags.data];
xmlTagIDs = [xmlTags.data];
fprintf('\n');
fprintf('Tags found in .dat files:\n')
disp(datTagIDs)
fprintf('Tags found in .xml files:\n')
disp(xmlTagIDs)
fprintf('\n')

disp('Checking for duplicated tags...')
duplicatedDatTagIDs = length(datTagIDs) - length(unique(datTagIDs));
if duplicatedDatTagIDs > 0
    msg = sprintf('%d duplicate tag IDs in fpga dat files! Make sure you only run this function on one "run" of data at a time. Exiting.', duplicatedDatTagIDs);
    if deduplicate
        disp(msg);
        fprintf('\tAttempting to deduplicate...\n');
        datTagIDs = deduplicateTagIds(datTagIDs)
        fprintf('\t...done\n');
    else
        disp(msg);
        datTag
        error(msg);
    end
end

duplicatedXmlTagIDs = length(xmlTagIDs) - length(unique(xmlTagIDs));
if duplicatedXmlTagIDs > 0
    msg = sprintf('%d duplicate tag IDs in video xml files! Make sure you only run this function on one "run" of data at a time..', duplicatedXmlTagIDs);
    if deduplicate
        disp(msg);
        fprintf('\tAttempting to deduplicate...\n');
        xmlTagIDs = deduplicateTagIds(xmlTagIDs)
        fprintf('\t...done\n');
    else
        error(msg);
    end
end
disp('...done')

fprintf('\n');

if strcmp(matchDirection, 'VideoToFPGA')
    baseTags = datTags;
    matchTags = xmlTags;
elseif strcmp(matchDirection, 'FPGAToVideo')
    baseTags = xmlTags;
    matchTags = datTags;
else
    fprintf('Invalid match direction: %s', matchDirection);
    return;
end

syncList = struct('file', {}, 'matches', {});
for k = 1:length(baseTags)
    baseTag = baseTags(k);
    baseTagID = baseTag.data;
    matchTag = matchTags([matchTags.data] == baseTagID);

    if ~isempty(matchTag)
        % We found a match for this tag
        baseIdx = find(strcmp({syncList.file}, baseTag.file), 1);
        if isempty(baseIdx)
            baseIdx = length(syncList)+1;
            syncList(baseIdx).matches = [];
        end
    
        matches = syncList(baseIdx).matches;
        
        % Calculate stats on match
        baseTagFileTagData = getTagData(baseTag.file, allTagData);
        matchedTagFileTagData = getTagData(matchTag.file, allTagData);

        [baseOverlap, matchOverlap] = overlapSegments(...
            [1, length(baseTagFileTagData)], ...
            [1, length(matchedTagFileTagData)], ...
            [baseTag.start, baseTag.end], ...
            [matchTag.start, matchTag.end]);

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
                matchIdx = length(matches);
            else
                % This file has been matched before (with other tags)
                fileAlreadyMatched = true;
            end
        end
        
        if fileAlreadyMatched
            if ~all(matches(matchIdx).baseOverlap == baseOverlap) || ...
               ~all(matches(matchIdx).matchOverlap == matchOverlap)
                disp('Disagreement about file overlaps based on two different tags!');
            end
        end
        
        matches(matchIdx).baseFile = baseTag.file;
        matches(matchIdx).matchFile = matchTag.file;
        matches(matchIdx).baseOverlap = baseOverlap;
        matches(matchIdx).matchOverlap = matchOverlap;
        matches(matchIdx).sampleRateRatio = (matchOverlap(2)-matchOverlap(1))/(baseOverlap(2)-baseOverlap(1));
        
        syncList(baseIdx).matches = matches;
        syncList(baseIdx).file = baseTag.file;
    end
end

for k = 1:length(syncList)
    plotMatches(syncList(k), allTagData);
end

function plotMatches(syncElement, allTagData)
% Plot matches:
baseTagData = getTagData(syncElement.file, allTagData);
[~, name, ext] = fileparts(syncElement.file);
f = figure;
ax = axes(f);
plot(ax, 1:length(baseTagData), baseTagData, 'DisplayName', [name, ext]);
hold(ax, 'on');
nMatch = length(syncElement.matches);
for k = 1:nMatch
    matchElement = syncElement.matches(k);
    matchTagData = getTagData(matchElement.matchFile, allTagData);
    matchOverlapIdx = matchElement.matchOverlap(1):matchElement.matchOverlap(2);
    baseOverlapIdx = linspace(matchElement.baseOverlap(1), matchElement.baseOverlap(2), length(matchOverlapIdx));
    [~, name, ext] = fileparts(matchElement.matchFile);
    plot(ax, baseOverlapIdx, matchTagData(matchOverlapIdx)-1.5*k, 'DisplayName', [name, ext]);
%     r = fill(ax,...
%         [matchElement.baseOverlap(1), matchElement.baseOverlap(1), matchElement.baseOverlap(2), matchElement.baseOverlap(2)], ...
%         [-1.5*(k-1)-0.1,-1.5*(k-1)-0.4,-1.5*(k-1)-0.4,-1.5*(k-1)-0.1], ...
%         [1, 1, 2, 2]);
end
ylim(ax, [-0.5 - 1.5*nMatch, 1.5]);
legend(ax, 'Interpreter', 'none');

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
    assert(seg(1) < seg(2), 'Error, all inputs to overlapSegments must have second value greater than the first');
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

function newTagIds = deduplicateTagIds(tagIds)
tagIdDuplicateCounts = [];
for k = 1:length(tagIds)
    tagIdDuplicateCounts(k) = sum(tagIds(1:k-1) == tagIds(k));
end
tagIdDuplicateCounts = 1-(2.^(-tagIdDuplicateCounts)); 
newTagIds = tagIds + tagIdDuplicateCounts;