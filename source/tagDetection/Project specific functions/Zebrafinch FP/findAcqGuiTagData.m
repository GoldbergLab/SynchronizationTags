function tagData = findAcqGuiTagData(datFile, showPlot)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% findAcqGuiTagData: Extract binary synchronization tag data from an
%   acquisitionGui generated .dat file.
% usage:  tagData = findAcqGuiTagData(datFile, showPlot)
%
% where,
%    tagData is a logical vector containing the extracted raw tag data.
%    datFile is a char array representing the path to an acquisitionGui 
%       .dat file.
%    showPlot is an optional boolean flag that determines whether or not to
%       plot the extracted tag data in a figure. (default false)
%
% See findTags for detailed information about the synchronization tag
%   concept.
%
% findAcqGuiTagData will extract the binary synchronization tag data from 
%   an acquisitionGui-generated .dat file.
%
% See also: findTags, syncTagStreams, syncDoricToAcqGui, findDoricTagData
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('showPlot', 'var')
    showPlot = false;
end

%% Read .dat file
[rawTagData, info] = egl_AA_daq(datFile);

% Find two levels
[~, vals] = kmeans(rawTagData, 2);
% Find threshold
threshold = mean(vals);
% Convert to logical
tagData = rawTagData > threshold;

%% Plot data
if showPlot
    [~, name, ext] = fileparts(datFile);
    f = figure('Name', [name, ext]);
    ax = axes(f);
    plot(ax, tagData);
    ylim(ax, [-0.5, 1.5]);
end