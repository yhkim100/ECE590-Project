function trackMotion(obj)
%trackMotion Create an image acquisition motion detector.
% 
%    trackMotion(obj) acquires data from video input object (obj)
%    continuously and checks if any motion is detected from frame to frame
%
%    How to use: 
%      % Create video input object 
%       obj = videoinput('winvideo', 1);
%       trackMotion(obj)

try
    %Constants
    figureTitle = 'Motion Detector';
    %Make sure video is not currently running while we configure it 
    stop(obj);
    
    %Configure the video input object to continuously acquire data.
    triggerconfig(obj, 'manual');
    set(obj, 'Tag', figureTitle, ...
        'FramesAcquiredFcnCount', 1, ...            %After acquiring 1 frame, function will go into "frameCallback" function
        'ReturnedColorSpace', 'rgb', ...            %Set Colorspace, currently working in rgb 
        'TimerFcn', @frameCallback, ...             %Set name of callback function 
        'TimerPeriod', 0.1);                        %Time in seconds that must pass before frameCallback is called

    % Check to see if this object already has an associated figure.
    % Otherwise create a new one.
    ud = get(obj, 'UserData');
    if ~isempty(ud) && isstruct(ud) && isfield(ud, 'figureHandles') ...
            && ishandle(ud.figureHandles.hFigure)
        appdata.figureHandles = ud.figureHandles;
        figure(appdata.figureHandles.hFigure)       %Update pre-existing figure with new figurehandles
    else
        appdata.figureHandles = createNewFigure(obj, figureTitle);   %Create a new figure from scratch 
    end
    
    % Store the application data the video input object needs.
    appdata.background = [];
    obj.UserData = appdata;

    % Start the acquisition.
    start(obj);

    % Avoid peekdata warnings in case it takes too long to return a frame.
    warning off imaq:peekdata:tooManyFramesRequested
    
catch
    stop(obj);
    error('trackMotion failed due to error:\n%s', lasterr)
    
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function figData = createNewFigure(vid, figureTitle)
% Creates and initializes the figure.

% Create the figure and axes to plot into.
fig = figure('NumberTitle', 'off', 'MenuBar', 'none', ...
    'Name', figureTitle, 'DeleteFcn', @localDeleteFig);

% Create a spot for the image object display.
nbands = get(vid, 'NumberOfBands');
res = get(vid, 'ROIPosition');                          %ROIPosition is given as [Xoffset Yoffset Width Height]
himage = imagesc(rand(res(4), res(3), nbands));         %res(4) is Height, res(3) is Width

% Clean up the axes, we just want to see the video stream
ax = get(himage, 'Parent');
set(ax, 'XTick', [], 'XTickLabel', [], 'YTick', [], 'YTickLabel', []);



% Store the figure data.
figData.hFigure = fig;
figData.hImage = himage;
figData.textPosition = [0 0];


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function localDeleteFig(fig, event)

% Reset peekdata warnings.
warning on imaq:peekdata:tooManyFramesRequested


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function frameCallback(vid, event)
% Callback called by video object

% Check to make sure video is not corrupted
if ~isvalid(vid) || ~isrunning(vid)
    return;
end

% Access our application data.
appdata = get(vid, 'UserData');
background = appdata.background;

% Peek into the video stream. Since we are only interested
% in processing the current frame, not every single image
% frame provided by the device, we can flush any frames in
% the buffer.
frame = peekdata(vid, 1);
if isempty(frame),
    return;
end
flushdata(vid);

% First time through, a background image will be needed.
if isempty(background),
    background = getsnapshot(vid);
end

% Update the figure and our application data.
localUpdateFig(vid, appdata.figureHandles, frame, background);
appdata.background = frame;
set(vid, 'UserData', appdata);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function localUpdateFig(vid, figData, frame, background)
% Called by frameCallback function
% Update the figure display with the latest data.

% If the figure has been destroyed on us, stop the acquisition.
if ~ishandle(figData.hFigure),
    stop(vid);
    return;
end

% Plot the results.
I = imabsdiff(frame, background);
[graylevel EM] = graythresh(I); %Otsu Method to find threshold 

%convert frame to grayscale to find regions of motion
ImageDiffBW = rgb2gray(I);

blackwhite = (ImageDiffBW >= graylevel * 255);


%L = bwlabel(blackwhite);

%   WE CURRENTLY HAVE THE IMAGE SOMEWHAT SEGMENTING IN BLACK AND WHITE
%   WE NEED TO FIGURE OUT HOW TO MARK REGIONS OF MOTION
%   

%measurements = regionprops(L, 'BoundingBox', 'Area');
%[tmp, idx] = max(measurements.Area);
%draw boxes for areas of interest
%    thisBox = measurements(idx).BoundingBox;
%    insertObjectAnnotation(I,'rectangle',[thisBox(1), thisBox(2), thisBox(3), thisBox(4)],...
%        'Movement Detected','Color','red','LineWidth',2 );

    

%Rudimentary method of finding any motion in the frame
if(mean2(blackwhite) > 0.08)
   newFrame = insertText(frame,figData.textPosition, 'Movement Not Detected','FontSize', 40,'BoxColor','red'); 
else
   newFrame = insertText(frame,figData.textPosition, 'Movement Detected','FontSize',40,'BoxColor','green');
end

set(figData.hImage, 'CData', newFrame);

drawnow;


