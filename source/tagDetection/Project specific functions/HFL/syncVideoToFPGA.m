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
%       the synchronized tag data. Default is false.
%
% See findTags for detailed information about the synchronization tag
%   concept.
%
% syncVideoToFPGA will search through a set of video .xml metadata files, 
%   and fpga .dat files, and use the binary synchronization tags found within
%   each file to generate alignment information for the corresponding video
%   and fpga data. This is a wrapper function for syncTagStreams that
%   performs the file-finding process prior to running syncTagStreams.
%
% See also: syncTagStreams, findTags, findFPGATagData, findVideoTagData
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
    plotSync = false;
end

% Find FPGA .dat files and video .xml files
fprintf('Finding FPGA .dat files...\n');
datFiles = findFilesByRegex(fpgaRootDir, '.*\.[dD][aA][tT]', false, false);
fprintf('...done. Found %d .dat files.\n', length(datFiles));
fprintf('Finding video .xml files...\n');
xmlFiles = findFilesByRegex(videoRootDir, '.*\.[xX][mM][lL]', false, false);
fprintf('...done. Found %d .xml files.\n', length(xmlFiles));

switch matchDirection
    case 'VideoToFPGA'
        syncList = syncTagStreams({datFiles, xmlFiles}, {@findFPGATagData, @findVideoTagData}, nBits, plotSync);
    case 'FPGAToVideo'
        syncList = syncTagStreams({xmlFiles, datFiles}, {@findVideoTagData, @findFPGATagData}, nBits, plotSync);
end