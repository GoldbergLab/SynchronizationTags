function tagData = findDoricTagData(csvFile, tagFieldName, showPlot)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% findDoricTagData: Extract binary synchronization tag data within Doric
%   Neuroscience Studio generated .csv data file
% usage:  tagData = findDoricTagData(csvFile)
%
% where,
%    tagData is a logical vector containing the extracted raw tag data.
%    csvFile is a char array representing the path to a Doric Neuroscience
%       Studio csv data file.
%    tagFieldName is a char array representing the header name of the
%       column within the .csv file that contains the tag data. You can
%       control this within Doric Neuroscience Studio by clicking on the
%       "Graph(s)" button on the sync tag channel, and editing the "trace
%       name". Default is 'SyncTags'
%    showPlot is an optional boolean flag that determines whether or not to
%       plot the extracted tag data in a figure. (default false)
%
% See findTags for detailed information about the synchronization tag
%   concept.
%
% findDoricTagData will extract the binary synchronization tag data from a
%   Doric Neuroscience Studio generated .csv data file
%
% See also: findTags, syncTagStreams, syncDoricToAcqGui, findAcqGuiTagData
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('tagFieldName', 'var')
    tagFieldName = 'SyncTags';
end
if ~exist('showPlot', 'var')
    showPlot = false;
end

%% Read .dat file
load('DoricSyncTagsReadOpts.mat', 'inOpts');

%warning('off', 'MATLAB:table:ModifiedAndSavedVarnames');
data = readtable(csvFile, inOpts);
%warning('on', 'MATLAB:table:ModifiedAndSavedVarnames');

tagData = data.(tagFieldName);

%% Plot data
if showPlot
    % Plot extracted tag data
    [~, name, ext] = fileparts(csvFile);
    f = figure('Name', [name, ext]);
    ax = axes(f);
    plot(ax, tagData);
    ylim(ax, [-0.5, 1.5]);
end