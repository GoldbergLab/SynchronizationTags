function syncList = syncDoricToAcqGui(doricRootDir, acqGuiRootDir, matchDirection, nBits, plotSync)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% syncDoricToAcqGui: Create a synchronization list to match Doric 
%   fiberphotometry files and acquisitionGui files together.
% usage:  syncList = syncDoricToAcqGui(doricRootDir, acqGuiRootDir, 
%                                       matchDirection, nBits)
%
% where,
%    syncList is a struct array, one element for each "match from" file
%       (either Doric or acquisitionGui), and a match object indicating one
%       or more "match to" files that contained matching tags, along with 
%       alignment info for those corresponding files.
%    doricRootDir is the root directory in which to look for the doric .csv
%       files.
%    acqGuiRootDir is the root directory in which to look for the
%       acquisitionGui .dat files.
%    matchDirection is an optional char array indicating whether to match
%       Doric to acquisitionGui or acquisitionGui to Doric. One of 
%       {'DoricToAcqGui', 'AcqGuiToDoric'}. Default is 'DoricToAcqGui'
%    nBits is an optional # of bits to expect in the tags, which can
%       increase reliability of tag IDs, but is generally not necessary. 
%       Default is NaN, meaning any # of bits will be allowed.
%    plotSync is an option boolean flag indicating whether or not to plot
%       the synchronized tag data. Default is false.
%
% See findTags for detailed information about the synchronization tag
%   concept.
%
% syncDoricToAcqGui will search through a set of Doric .csv files, and 
%   acquisitionGui .dat files, and use the binary synchronization tags 
%   found within each file to generate alignment information for the 
%   corresponding Doric and acquisitionGui data. This is a wrapper function
%   for syncTagStreams that performs the file-finding process prior to 
%   running syncTagStreams.
%
% See also: syncTagStreams, findTags, findDoricTagData, 
%   findAcquisitionGuiTagData
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('matchDirection', 'var')
    matchDirection = 'AcqGuiToDoric';    
end
if ~exist('nBits', 'var')
    nBits = NaN;
end
if ~exist('plotSync', 'var')
    plotSync = false;
end

% Find acqGui .dat files and Doric .csv files
fprintf('Finding acqGui .dat files...\n');
datFiles = findFilesByRegex(acqGuiRootDir, '.*\.[dD][aA][tT]', false, false);
fprintf('...done. Found %d .dat files.\n', length(datFiles));
fprintf('Finding Doric .csv files...\n');
csvFiles = findFilesByRegex(doricRootDir, '.*\.[cC][sS][vV]', false, false);
fprintf('...done. Found %d .csv files.\n', length(csvFiles));

switch matchDirection
    case 'DoricToAcqGui'
        syncList = syncTagStreams({datFiles, csvFiles}, {@findAcqGuiTagData, @findDoricTagData}, nBits, plotSync);
    case 'AcqGuiToDoric'
        syncList = syncTagStreams({csvFiles, datFiles}, {@findDoricTagData, @findAcqGuiTagData}, nBits, plotSync);
end