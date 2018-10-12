function varargout=EEGAnalyzer(varargin)
% The "EEG Analyzer" toolbox for SPM provides a user-friendly interface for 
% M/EEG visualization. It reads SPM M/EEG files and also offers basic M/EEG 
% filtering options. If present, events are also shown.
% Version 1 - 4 May 2018           
% Author : Rudy ERCEK (rercek@ulb.ac.be)
% Website : https://bitbucket.org/ulbeeg/eeganalyzer
% License : GPL v2, see https://www.gnu.org/licenses/gpl-2.0.txt
% Copyright © 2013-2018 - Université Libre de Bruxelles

%global/persistent variables as a structure/object
persistent guieega  %graphical user interfaces containing controls/parameters
persistent filters  %filters object
persistent eeg      %loaded data object with signals

if ~nargin
    if ~isempty(findobj('Tag','maineegfig')) %check if figure is already opened
        figure(guieega.fig); %activate the figure (only one EEGAnalyzer instance can be opened !)
        return;
    end
    scr=get(0,'ScreenSize');          %get the screen size
    if (scr(3)<1024) || (scr(4)<720)  %the screen size should be at least of 1024x720
        msgbox('You have to set the display with at least 720 lines and 1024 rows!','Screen size error','error','modal');
        return
    end
    
    %variables corresponding to some preferences
    guieega.division=8; %default number of division (r/w)
    guieega.timerdelay=2; %default delay before updating the display signals
    guieega.filtdefaultorder=3; %default filter order (read only)
    guieega.icons.sz=13; %default icon size (read only)
    
    %usefull variables
    guieega.play=0;     %eeg is playing or not ...
    guieega.stepplay=1; %1s step by default
    guieega.xstart=NaN; %start time of the window
    guieega.xend=NaN;   %stop time of the window
    guieega.ymin=NaN;   %minimum voltage value for each channel
    guieega.ymax=NaN;   %maximum voltage value for each channel
    guieega.ymean=NaN;  %mean voltage value for each channel
    guieega.legtyp=1;   %view channels type on legends
    
    %some empty objects for showing data/info        
    guieega.axes=[];    %axes for each selected channels
    guieega.hplot=[];   %plot for each selected channels
    guieega.legend=[];  %legend for each selected channels
    guieega.events=[];  %events vertical lines    
    
    %icons object (creation by algorithm)         
    guieega.icons.stop=zeros(guieega.icons.sz,guieega.icons.sz,3); %stop button icon (black square)
    guieega.icons.play=zeros(guieega.icons.sz,guieega.icons.sz,3); %play button icon (black arrow)
    guieega.icons.event=NaN([guieega.icons.sz,guieega.icons.sz,3]);%prev/next event button icon (empty arrow)
    f=3; %height factor for show/hide button icon
    guieega.icons.sig=zeros(f*guieega.icons.sz,guieega.icons.sz,3);%show/hide signal button icon
    for i=1:floor(guieega.icons.sz/2); %create arrows icons
           guieega.icons.play(i,2*i:end,:)=NaN; %NaN for transparency
           guieega.icons.play(guieega.icons.sz+1-i,2*i:end,:)=NaN; %NaN for transparency
           guieega.icons.event(i,2*i:min(guieega.icons.sz,2*i+2),:)=0;
           guieega.icons.event(guieega.icons.sz+1-i,2*i:min(guieega.icons.sz,2*i+2),:)=0;
           guieega.icons.sig(f*(i-i)+1:f*i,2*i:end,:)=NaN; 
           guieega.icons.sig(f*guieega.icons.sz+1-(f*(i-1)+1:f*i),2*i:end,:)=NaN;           
    end  
    guieega.icons.event(ceil(guieega.icons.sz/2),guieega.icons.sz-1:end,:)=0;
    
    %main figure/dialog
    guieega.figtitle='EEG Analyzer'; %Main figure title
    guieega.fig=figure('Name',guieega.figtitle,'Position',[scr(3)/2-512 scr(4)/2-360 1024 720],'Units','pixels','MenuBar','none','ToolBar','none','NumberTitle','off','DoubleBuffer','on','Tag','maineegfig','CloseRequestFcn','EEGAnalyzer(''close'')');
    
    %controls in the middle area of the figure
    guieega.listsig=uicontrol('Style','listbox','Units','normalized','Position',[0.02 0.1 0.12 0.85],'Callback','EEGAnalyzer(''delayselectsig'')','Max',100,'Enable','off','TooltipString','List of all channels'); %signal list
    guieega.defcol=get(guieega.listsig,'BackgroundColor'); %default color for all controls    
    set(guieega.fig,'Color',guieega.defcol);
    guieega.showsigbt=uicontrol('Style','pushbutton','Units','normalized','Position',[0 0.1 0.02 0.85],'String','<','Callback','EEGAnalyzer(''showhide'')','TooltipString','Hide the channels list','CData', guieega.icons.sig(:,end:-1:1,:)); %button to show/hide signal list   
    guieega.panelslider=uicontrol('Style','slider','Units','normalized','Position',[0.98 0.1 0.02 0.85],'Callback','EEGAnalyzer(''movepanel'')','Visible','off');  %left slider when the number of signal is above the division
   
    %refresh timer for signal selection (delay)
    guieega.refreshtimer=timer('StartDelay',guieega.timerdelay,'TimerFcn','EEGAnalyzer(''selectsig'')');    
    
    %top controls of the main figure (window/scale/filters)
    guieega.window.name={'Window','Full','1 min','20 sec','10 sec','4 sec','2 sec','1 sec','0.6 sec','0.1 sec','0.01 sec'};
    guieega.window.value=[0 0 60 20 10 4 2 1 0.6 0.1 0.01];
    guieega.window.list=uicontrol('Style','popup','Units','normalized','Position',[0.0 0.97 0.07 0.028],'String',guieega.window.name,'Callback','EEGAnalyzer(''changewindow'',''list'')','Enable','off','TooltipString','Change the temporal window size of the signals');
    guieega.window.edit=uicontrol('Style','edit','Units','normalized','Position',[0.07 0.97 0.07 0.028],'String','','Callback','EEGAnalyzer(''changewindow'',''edit'')','Enable','off','TooltipString','Change the temporal window size of the signals');
    
    guieega.scale.name={'Scale µV','Auto','Full','1µV','2µV','5µV','10µV','20µV','50µV','70µV','100µV','150µV','200µV','500µV','700µV','1000µV','2000µV'};
    guieega.scale.value=[0 -1 0 1 2 5 10 20 50 70 100 150 200 500 700 1000 2000];
    guieega.scale.list=uicontrol('Style','popup','Units','normalized','Position',[0.14 0.97 0.07 0.028],'String',guieega.scale.name,'Callback','EEGAnalyzer(''changescale'',''list'')','Enable','off','TooltipString','Change the voltage scale');
    guieega.scale.edit=uicontrol('Style','edit','Units','normalized','Position',[0.21 0.97 0.07 0.028],'String','','Callback','EEGAnalyzer(''changescale'',''edit'')','Enable','off','TooltipString','Change the voltage scale');
    
    xx=0.18+0.1;
    guieega.filt.lowcut.name={'Low-Cut','Off','0.16Hz','0.3Hz','0.53Hz','0.6Hz','0.7Hz','0.8Hz','1.0Hz','1.2Hz','1.6Hz','3.0Hz','5.0Hz','10.0Hz','20.0Hz'};
    guieega.filt.lowcut.value=[0 0 0.16 0.3 0.53 0.6 0.7 0.8 1 1.2 1.6 3 5 10 20];
    guieega.filt.lowcut.list=uicontrol('Style','popup','Units','normalized','Position',[xx 0.97 0.07 0.028],'String',guieega.filt.lowcut.name,'Callback','EEGAnalyzer(''changecutoff'',''listlowcut'')','Enable','off','Tag','filtctrl','TooltipString','Change the current filter low-cut frequency');
    guieega.filt.lowcut.edit=uicontrol('Style','edit','Units','normalized','Position',[xx+.07 0.97 0.06 0.028],'String','','Callback','EEGAnalyzer(''changecutoff'',''edit'')','Enable','off','Tag','filtctrl','TooltipString','Change the current filter low-cut frequency');
    
    guieega.filt.highcut.name={'High-Cut','Off','15Hz','30Hz','40Hz','50Hz','60Hz','70Hz','80Hz','90Hz','100Hz'};
    guieega.filt.highcut.value=[0 0 15 30 40 50 60 70 80 90 100];
    guieega.filt.highcut.list=uicontrol('Style','popup','Units','normalized','Position',[xx+.13 0.97 0.07 0.028],'String',guieega.filt.highcut.name,'Callback','EEGAnalyzer(''changecutoff'',''listhighcut'')','Enable','off','Tag','filtctrl','TooltipString','Change the current filter high-cut frequency');
    guieega.filt.highcut.edit=uicontrol('Style','edit','Units','normalized','Position',[xx+.20 0.97 0.06 0.028],'String','','Callback','EEGAnalyzer(''changecutoff'',''edit'')','Enable','off','Tag','filtctrl','TooltipString','Change the current filter high-cut frequency');
    
    guieega.filt.order.name={'Filter Order','6dB/oct (1)','12dB/oct (2)','18dB/oct (3)','24dB/oct (4)','30dB/oct (5)','36dB/oct (6)','42dB/oct (7)','48dB/oct (8)','54dB/oct (9)'};
    guieega.filt.order.value=[guieega.filtdefaultorder 1 2 3 4 5 6 7 8 9];
    guieega.filt.order.list=uicontrol('Style','popup','Units','normalized','Position',[xx+.26 0.97 0.1 0.028],'String',guieega.filt.order.name,'Callback','EEGAnalyzer(''changecutoff'',''listorder'')','Enable','off','Tag','filtctrl','TooltipString','Change the current Butterworth filter order');
    guieega.filt.order.edit=uicontrol('Style','edit','Units','normalized','Position',[xx+.36 0.97 0.06 0.028],'String','','Callback','EEGAnalyzer(''changecutoff'',''edit'')','Enable','off','Tag','filtctrl','TooltipString','Change the current Butterworth filter order');
    
    guieega.filt.type.list=uicontrol('Style','popup','Units','normalized','Position',[xx+.42 0.97 0.1 0.028],'String',{'Passband','Stopband'},'Callback','EEGAnalyzer(''changecutoff'',''edit'')','Enable','off','Tag','filtctrl','TooltipString','Change the current filter type');
    
    guieega.filt.list=uicontrol('Style','popup','Units','normalized','Position',[xx+.52 0.97 0.08 0.028],'String','Filters','Callback','EEGAnalyzer(''changefilt'')','Enable','off','Tag','filtctrl','TooltipString','Select the current filter');
    guieega.filt.add=uicontrol('Style','pushbutton','Units','normalized','Position',[xx+.60 0.97 0.02 0.028],'String','+','Callback','EEGAnalyzer(''addfilt'')','Enable','off','Tag','filtctrl','TooltipString','Add a new butterworth filter in the filters list');
    guieega.filt.remove=uicontrol('Style','pushbutton','Units','normalized','Position',[xx+.62 0.97 0.02 0.028],'String','-','Callback','EEGAnalyzer(''rmfilt'')','Enable','off','Tag','filtctrl','TooltipString','Remove the current filter');
    
    guieega.filt.show=uicontrol('Style','pushbutton','Units','normalized','Position',[xx+.64 0.97 0.08 0.028],'String','Freq. response','Callback','EEGAnalyzer(''showfilter'')','Enable','off','TooltipString','Show the frequency response of the filters');
    
    %main area objects in order to display EEG signals
    guieega.ytext.normal='Voltage (\muV) \rightarrow';
    guieega.ytext.reverse='\leftarrow Voltage (\muV)';    
    guieega.mainax=axes('Units','normalized','Position',[0.18 0.1 0.8 0.85],'Visible','on','Ytick',[]);
    guieega.xlabel=xlabel('Time (s)');
    guieega.ylabel=ylabel(guieega.ytext.reverse);
    guieega.mainpanel=uipanel('Units','normalized','Position',[0.18 0.1 0.8 0.85],'BorderType','none');
    guieega.axpanel=uipanel('Parent',guieega.mainpanel,'Position',[0 0 1 1],'BorderType','none');
    guieega.ax=axes('Parent',guieega.axpanel,'Units','normalized','Position',[0 0 1 1],'Visible','on','ButtonDownFcn','EEGAnalyzer(''clickax'')','YGrid','on');            
   
    %controls in the bottom of the main figure for moving the (time) window
    guieega.timeslider=uicontrol('Style','slider','Units','normalized','Position',[0.18 0 0.72 0.03],'Callback','EEGAnalyzer(''movewindow'')','Enable','off','Tag','play','TooltipString','Change the position of the current time window in the EEG');    
    guieega.stopbt=uicontrol('Style','pushbutton','Units','normalized','Position',[0 0 0.0225 0.03],'String','','Callback','EEGAnalyzer(''stop'')','Enable','off','Tag','play','CData',guieega.icons.stop,'TooltipString','Stop playing the signals');
    guieega.playbt=uicontrol('Style','pushbutton','Units','normalized','Position',[0.0225 0 0.0225 0.03],'String','','Callback','EEGAnalyzer(''play'')','Enable','off','Tag','play','CData',guieega.icons.play,'TooltipString','Play the selected signals');
    guieega.stepedit=uicontrol('Style','edit','Units','normalized','Position',[0.045 0 0.06 0.03],'String','1','Callback','EEGAnalyzer(''changestep'')','Enable','off','Tag','play','TooltipString','Incremental step (in sec.) when playing the signals');
    guieega.gotoedit=uicontrol('Style','edit','Units','normalized','Position',[0.105 0 0.075 0.03],'String','0','Callback','EEGAnalyzer(''goto'')','Enable','off','Tag','play','TooltipString','Signals begin in the display window');
    guieega.preveventbt=uicontrol('Style','togglebutton','Units','normalized','Position',[0.9 0 0.0225 0.03],'String','','Callback','EEGAnalyzer(''jumpevent'',0)','Enable','off','Tag','eventctrl','CData',guieega.icons.event(:,end:-1:1,:),'TooltipString','Jump the middle of the window to the previous event');
    guieega.listevent=uicontrol('Style','popup','Units','normalized','Position',[0.9225 0 0.055 0.03],'String','event','Enable','off','Tag','eventctrl','TooltipString','Select the event type to jump to');
    guieega.nexteventbt=uicontrol('Style','togglebutton','Units','normalized','Position',[0.9775 0 0.0225 0.03],'String','','Callback','EEGAnalyzer(''jumpevent'',1)','Enable','off','Tag','eventctrl','CData',guieega.icons.event,'TooltipString','Jump the middle of the window to the next event');    
    
    %information line (double click in the plots)
    guieega.sel=line([NaN NaN],[0 1],'Parent',guieega.ax,'Color','k','Visible','off','Tag','selinfo');
    guieega.seltxt=text(0,1,'','Parent',guieega.ax,'Color','k','VerticalAlignment','Top','HorizontalAlignment','left','Visible','off','Tag','selinfo');
    
    %menu "File"
    guieega.menu.file=uimenu(guieega.fig,'Label','File');
    guieega.menu.openfile=uimenu(guieega.menu.file,'Label','Open a SPM EEG File','Callback','EEGAnalyzer(''open'')','Accelerator','O');    
    guieega.menu.infofile=uimenu(guieega.menu.file,'Label','File information','Callback','EEGAnalyzer(''info'')','Accelerator','I','Enable','off');    
    uimenu(guieega.menu.file,'Label','Exit','Callback','closefig','Accelerator','Q','Separator','on');
    %menu "Options"
    guieega.menu.options=uimenu(guieega.fig,'Label','Options');
    guieega.menu.viewlegend=uimenu(guieega.menu.options,'Label','View legends','Callback','EEGAnalyzer(''viewlegend'',''menu'')','Accelerator','L','Checked','on');
    guieega.menu.viewlegendtype=uimenu(guieega.menu.options,'Label','View channels type on legends','Callback','EEGAnalyzer(''viewlegendtype'',''menu'')','Accelerator','T','Checked','on');
    guieega.menu.invy=uimenu(guieega.menu.options,'Label','Inverse voltage axe','Callback','EEGAnalyzer(''invy'',''menu'')','Accelerator','Y','Checked','on');    
    guieega.menu.viewevents=uimenu(guieega.menu.options,'Label','Show events','Callback','EEGAnalyzer(''viewevents'',''menu'')','Accelerator','E','Checked','off','Separator','off','Enable','off');
    guieega.menu.division=uimenu(guieega.menu.options,'Label','Number of visible channels','Callback','EEGAnalyzer(''changedivision'',''menu'')','Accelerator','D');
    guieega.menu.refresh=uimenu(guieega.menu.options,'Label','Display refresh delay','Callback','EEGAnalyzer(''changedelaytimer'',''menu'')','Accelerator','P','Separator','on');
    guieega.menu.showtoolbar=uimenu(guieega.menu.options,'Label','Hide toolbar','Callback','EEGAnalyzer(''showtoolbar'',0)','Separator','on','Enable','on','Accelerator','B');
    %menu "Filters"
    guieega.menu.filters=uimenu(guieega.fig,'Label','Filters','Enable','off');
    guieega.menu.savefilters=uimenu(guieega.menu.filters,'Label','Save filters','Callback','EEGAnalyzer(''savefilters'')','Accelerator','S','Separator','off');
    guieega.menu.loadfilters=uimenu(guieega.menu.filters,'Label','Load filters','Callback','EEGAnalyzer(''loadfilters'')','Accelerator','F','Separator','off');
    guieega.menu.clearfilters=uimenu(guieega.menu.filters,'Label','Clear filters','Callback','EEGAnalyzer(''clearfilters'')','Accelerator','R','Separator','off');
    guieega.menu.zerofilter=uimenu(guieega.menu.filters,'Label','Zero Phase Filter','Callback','EEGAnalyzer(''zerophasefilter'',''menu'')','Accelerator','Z','Checked','on','Separator','on');
    %menu "Help"
    guieega.menu.help=uimenu(guieega.fig,'Label','Help');
    guieega.menu.manual=uimenu(guieega.menu.help,'Label','Open manual','Callback','EEGAnalyzer(''help'')','Accelerator','H');
    guieega.menu.about=uimenu(guieega.menu.help,'Label','About','Callback','EEGAnalyzer(''About'')','Separator','on');
    
    try %try catch because ResizeFcn can be removed in future Matlab version
        set(guieega.fig,'ResizeFcn','EEGAnalyzer(''resizedlg'')');
    catch
    end    
    
    %Toolbar based on the figure toolbar 
    guieega.tool.bar=[];     
    try %a try catch because uitoolfactory might not be supported anymore (seems ok for Matalb R2007a to R2016a)
        if exist('uitoolfactory','file') %uitoolfactory (not documented ...)
            guieega.tool.bar=uitoolbar('parent',guieega.fig);
            guieega.tool.open=uitoolfactory(guieega.tool.bar,'Standard.FileOpen');        
            set(guieega.tool.open,'ClickedCallback','EEGAnalyzer(''open'')','TooltipString','Open a SPM EEG File');
            guieega.tool.print=uitoolfactory(guieega.tool.bar,'Standard.PrintFigure');
            guieega.tool.zoomin=uitoolfactory(guieega.tool.bar,'Exploration.ZoomIn');        
            set(guieega.tool.zoomin,'Separator','on');
            guieega.tool.zoomout=uitoolfactory(guieega.tool.bar,'Exploration.ZoomOut');
            guieega.tool.pan=uitoolfactory(guieega.tool.bar,'Exploration.Pan');
            guieega.tool.datacursor=uitoolfactory(guieega.tool.bar,'Exploration.DataCursor');                        
        end
    catch
        delete(guieega.tool.bar);
        guieega.tool.bar=[];                
        set(guieega.fig,'Toolbar','figure');
    end 
    
else
    %CALLBACKs
    switch varargin{1}
        %open a SPM EEG file
        case 'open'
            [filename, pathname, filterindex] = uigetfile({'*.mat','SPM Mat EEG File (*.mat)'},'Open an EEG File');
            if (filename)
                fname=[pathname filename];                
                D = spm_eeg_load(fname);
                if isempty(D)
                    return;
                end
                trial=1;
                if D.ntrials>1
                    prompt= {['Enter the trial number you want to display between 1 and ' num2str(D.ntrials)]};
                    title = 'EEG Analyzer can only display one trial !';
                    answer = inputdlg(prompt,title,1,{'1'});
                    if isempty(answer)
                        return
                    end
                    trial=str2double(answer{1});
                    if isnan(trial) || trial>D.ntrials || floor(trial)~=trial
                        return;
                    end
                end
                %conversion of the SPM MEEG object to a data structure eeg                
                eeg=[];
                eeg.label=D.chanlabels';
                eeg.chantype=D.chantype';
                eeg.rate=D.fsample;
                eeg.npnt=D.nsamples;
                eeg.nchan=D.nchannels;
                eeg.time=D.time;
                eeg.data=D(:,:,trial);
                eeg.filename=fname;
                eeg.events=events(D,trial);
                eeg.trialonset=D.trialonset(trial);
                eeg.trial=trial;
                eeg.ntrials=D.ntrials;
                EEGAnalyzer('initfilt');
                %set main figure title with the filename
                set(guieega.fig,'Name',[guieega.figtitle ' - ' fname]);
                %axes initilization
                guieega.xstart=eeg.time(1);
                guieega.xend=eeg.time(end);
                set([guieega.ax guieega.mainax],'XLim',[guieega.xstart guieega.xend]);
                m=ceil(eeg.time(end));
                n=floor(eeg.time(1));
                guieega.sig=[];
                guieega.plotcolor=lines(eeg.nchan);
                set(guieega.listsig,'String',eeg.label','Value',[]);
                set(findobj('Enable','off'),'Enable','on');
                set(guieega.timeslider,'Min',n,'Max',m,'SliderStep',[1/(m-n) 1/(m-n)],'Enable','off','Value',n);
                set(findobj('Tag','play'),'Enable','off');                           
                EEGAnalyzer('initevents');                
                EEGAnalyzer('selectsig');
            end
            
            %show some information on the current SPM file
        case 'info'
            msg={['SPM file : ' eeg.filename], ...
                ['Number of trials: ' num2str(eeg.ntrials)], ...
                ['Trial number displayed: ' num2str(eeg.trial)], ...
                ['Number of channels: ' num2str(eeg.nchan)], ...                
                ['Number of events: ' num2str(numel(eeg.events))], ...
                ['Number of samples: ' num2str(eeg.npnt)], ...
                ['Frequency sampling: ' num2str(eeg.rate) ' Hz'], ...                                                 
                ['Length: ' num2str(eeg.npnt/eeg.rate) ' sec'], ...             
                ['Time from ' num2str(eeg.time(1)) ' sec to ' num2str(eeg.time(end)) ' sec'] };               
            msgbox(msg,['File information'],'help','modal');
            
            %refresh signals display after a few seconds (with timer)
        case 'delayselectsig'
            stop(guieega.refreshtimer);
            start(guieega.refreshtimer);
            
            %refresh signals display by updating the axes
        case 'selectsig'
            guieega.sig=get(guieega.listsig,'Value');
            delete(guieega.axes);            
            if ~isempty(guieega.sig) && isfield(eeg,'time')
                figure(guieega.fig);
                lg=length(guieega.sig);
                guieega.axes=repmat(-1,1,lg);
                guieega.hplot=repmat(-1,1,lg);
                guieega.legend=repmat(-1,1,lg);
                %divisions of the axes
                if lg>guieega.division %if the number of signal to display is above a fix division
                    pas=1/lg;
                    h=lg/guieega.division;
                    dd=lg-guieega.division;
                    set(guieega.panelslider,'Visible','on','SliderStep',[1/dd 1/dd],'Min',0,'Max',h-1,'Value',h-1);
                    set(guieega.axpanel,'Position',[0 1-h 1 h]);
                    set(guieega.ax,'YLim',[0 lg],'YTick',[0:lg]);
                else
                    pas=1/guieega.division;
                    set(guieega.panelslider,'Visible','off');
                    set(guieega.axpanel,'Position',[0 0 1 1]);
                    set(guieega.ax,'YLim',[0 guieega.division],'YTick',[0:guieega.division]);
                end
                %signal filtering on display !
                if (filters.a==1) & (filters.b==1)
                    buffer=eeg.data(guieega.sig,:)';
                else
                    if (filters.zero)
                        buffer=filtfilt(filters.b,filters.a,eeg.data(guieega.sig,:)'); %zero phase filtering
                    else
                        buffer=filter(filters.b,filters.a,eeg.data(guieega.sig,:)');
                    end
                end
                t=eeg.time';
                for i=1:lg
                    guieega.axes(i)=axes('Parent',guieega.axpanel,'Units','normalized','Position',[0 1-i*pas 1 pas],'YLimMode','auto','Visible','off','XLim',[t(1) t(end)]);
                    guieega.hplot(i)=line(t,buffer(:,i),'Parent',guieega.axes(i),'ButtonDownFcn','EEGAnalyzer(''clickax'')','Color',guieega.plotcolor(i,:));
                    if guieega.legtyp
                        guieega.legend(i)=legend([eeg.chantype{guieega.sig(i)} ': ' eeg.label{guieega.sig(i)}]);
                    else
                        guieega.legend(i)=legend(eeg.label{guieega.sig(i)});
                    end
                end
                guieega.ymax=max(buffer,[],1);
                guieega.ymin=min(buffer,[],1);
                guieega.ymean=mean(buffer);
                EEGAnalyzer('changewindow','edit');
                EEGAnalyzer('changescale','edit');
                EEGAnalyzer('goto');
                EEGAnalyzer('invy');
                EEGAnalyzer('viewlegend');                
                EEGAnalyzer('viewevents');
                set([guieega.sel guieega.seltxt],'Visible','off');
            else
                 set(guieega.events,'Visible','off');
                 guieega.axes=[];
                 guieega.hplot=[];
                 guieega.legend=[];                 
            end
            
            %create/init events
        case 'initevents'
            delete(guieega.events);
            guieega.events=[];
            nb=numel(eeg.events);
            if nb>0
                [eeg.evtype,eeg.indevtype,eeg.indtype]=unique([{eeg.events.type}']);
                nbevents=length(eeg.indevtype);
                col=jet(nbevents);
                ylim=[0 max(eeg.nchan,guieega.division)];
                tt=eeg.trialonset+[eeg.events.time]';
                x=[tt tt]';
                y=repmat(ylim,[nb 1])';
                guieega.events=line(x,y,'Parent',guieega.ax,'Color','m','Tag','eventline','ButtonDownFcn','EEGAnalyzer(''clickevent'')','Visible','off');
                for i=1:nbevents
                    set(guieega.events(eeg.indtype==eeg.indevtype(i)),'Color',col(i,:));
                end
                set([guieega.preveventbt guieega.nexteventbt guieega.listevent],'Enable','on');
                set(guieega.listevent,'String',{'event',eeg.evtype{:}});
                set(guieega.menu.viewevents,'Enable','on','Checked','on');                    
            else
                set([guieega.preveventbt guieega.nexteventbt guieega.listevent],'Enable','off');
                set(guieega.menu.viewevents,'Enable','off','Checked','off');                    
            end            
            
            %jump to the previous/next event
        case 'jumpevent'
            if strcmp(get(guieega.timeslider,'Enable'),'on')
                xlim=get(guieega.ax,'XLim');
                w=diff(xlim);
                tmiddle=xlim(1)+w/2;
                eps=0.0001; %1/10 ms
                tt=eeg.trialonset+[eeg.events.time]';
                typ=get(guieega.listevent,'Value')-1;
                if varargin{2} %forward move (next event)
                    if typ
                        ind=find((tt>tmiddle+eps) & (eeg.indtype==typ));
                    else
                        ind=find(tt>tmiddle+eps);
                    end                    
                    if ~isempty(ind)
                        EEGAnalyzer('movewindow',tt(ind(1))-w/2);
                    end
                else %backward move (previous event)
                    if typ
                        ind=find((tt<tmiddle-eps) & (eeg.indtype==typ));
                    else
                        ind=find(tt<tmiddle-eps);
                    end
                    if ~isempty(ind)
                        EEGAnalyzer('movewindow',tt(ind(end))-w/2);
                    end
                end    
                
            end
            
            %show/hide events
        case 'viewevents'
            if nargin>1
                if strcmp(get(guieega.menu.viewevents, 'Checked'),'on')
                    set(guieega.menu.viewevents, 'Checked', 'off');
                else
                    set(guieega.menu.viewevents, 'Checked', 'on');
                end
            end
            if strcmp(get(guieega.menu.viewevents, 'Checked'),'on')                
                set(guieega.events,'Visible','on');
            else                
                set(guieega.events,'Visible','off');
            end
            
            %action when clicking on an event
        case 'clickevent'
            h=gco;
            ind=find(guieega.events==h);
            if length(ind)==1
                typ=tostr(eeg.events(ind).type);
                value=tostr(eeg.events(ind).value);
                duration=tostr(eeg.events(ind).duration);
                t=tostr(eeg.trialonset+eeg.events(ind).time);
                tstart=tostr(eeg.events(ind).time);
                msg={['Type: ' typ],['Value: ' value],['Start at: ' tstart 'sec'],['Time index: ' t 'sec']};
                if ~isempty(duration)
                    msg{end+1}=['Duration: ' duration 'sec'];
                end
                msgbox(msg,[typ ' event'],'help','modal');
            end
            
            %change the temporal axe (x)
        case 'changewindow'
            if strcmp(varargin{2},'list')
                w=guieega.window.value(get(guieega.window.list,'Value'));
                set(guieega.window.list,'Value',1);
                set(guieega.window.edit,'String',num2str(w));
            else
                w=str2double(get(guieega.window.edit,'String'));
            end
            if ~isempty(guieega.sig)
                if ~isnan(w) && w>0
                    xlim=get(guieega.ax,'XLim');
                    set([guieega.ax guieega.mainax guieega.axes],'XLim',[xlim(1) xlim(1)+w]);
                    m=ceil(eeg.time(end));
                    n=floor(eeg.time(1));
                    set(guieega.timeslider,'SliderStep',[1/(m-n) w/(m-n)/2],'Enable','on');
                    set(findobj('Tag','play'),'Enable','on');
                else
                    m=eeg.time(end);
                    n=eeg.time(1);
                    set([guieega.ax guieega.mainax guieega.axes],'XLim',[n m]);
                    set(findobj('Tag','play'),'Enable','off');
                end
            end
            
            %change voltage scale (axe y)
        case 'changescale'
            if strcmp(varargin{2},'list')
                sc=guieega.scale.value(get(guieega.scale.list,'Value'));
                set(guieega.scale.list,'Value',1);
                set(guieega.scale.edit,'String',num2str(sc));
            else
                sc=str2double(get(guieega.scale.edit,'String'));
            end
            if ~isempty(guieega.sig)
                %automatic scaling
                if isnan(sc) || sc<0
                    set(guieega.axes,'YLimMode','auto')
                else
                    %manual scaling
                    lg=length(guieega.ymean);
                    if sc==0 %adaptative scale on all signal length
                        miny=guieega.ymin;
                        maxy=guieega.ymax;
                        ind=find(maxy<=miny);
                        if ~isempty(ind)
                            maxy(ind)=miny(ind)+1;
                        end
                        ylim=[miny' maxy'];
                    else
                        ylim=[guieega.ymean'-sc guieega.ymean'+sc];
                    end
                    set(guieega.axes,{'YLim'},mat2cell(ylim,ones(lg,1),2));
                end
            end
            
            %temporal window moving
        case 'movewindow'
            if nargin==2
                val=varargin{2};
                m=max(eeg.time(1),min(eeg.time(end),val));
                set(guieega.timeslider,'Value',m);
            else
                m=get(guieega.timeslider,'Value');
            end
            set(guieega.gotoedit,'String',num2str(m));
            w=str2double(get(guieega.window.edit,'String'));
            if (w>0)
                set([guieega.ax guieega.mainax guieega.axes],'XLim',[m m+w]);
            end
            pause(0.01);
            refresh(guieega.fig);
            
            %filter initialization
        case 'initfilt'
            filters=[];
            filters.zero=strcmp(get(guieega.menu.zerofilter, 'Checked'),'on');
            filters.nb=1;
            filters.name={'Filter 1'};
            filters.a=1;
            filters.b=1;                        
            filters.filt(1).a=1;
            filters.filt(1).b=1;
            filters.filt(1).lc=0;
            filters.filt(1).hc=0;
            filters.filt(1).order=guieega.filtdefaultorder;
            filters.filt(1).type='all';
            set(guieega.filt.list,'String',filters.name,'Value',1);
            EEGAnalyzer('changefilt');
            
            %current filter change or current filter reset values
        case 'changefilt'
            s=get(guieega.filt.list,'Value');
            set(guieega.filt.lowcut.edit,'String',num2str(filters.filt(s).lc));
            set(guieega.filt.highcut.edit,'String',num2str(filters.filt(s).hc));
            set(guieega.filt.order.edit,'String',num2str(filters.filt(s).order));
            if strcmp(filters.filt(s).type,'stop')
                set(guieega.filt.type.list,'Value',2);
            else
                set(guieega.filt.type.list,'Value',1);
            end
            
            %add a new filter
        case 'addfilt'
            if strcmp(filters.filt(end).type,'all')
                set(guieega.filt.list,'Value',filters.nb);
            else
                filters.nb=filters.nb+1;
                s=filters.nb;
                filters.name{end+1}=sprintf('Filter %d',s);
                filters.filt(s).a=1;
                filters.filt(s).b=1;
                filters.filt(s).lc=0;
                filters.filt(s).hc=0;
                filters.filt(s).order=guieega.filtdefaultorder;
                filters.filt(s).type='all';
                set(guieega.filt.list,'String',filters.name,'Value',s);
            end
            EEGAnalyzer('changefilt');
            
            %remove the current filter
        case 'rmfilt'
            if filters.nb>1
                s=get(guieega.filt.list,'Value');
                sel=[1:s-1 s+1:filters.nb];
                filters.name={filters.name{sel}};
                filters.filt=filters.filt(sel);
                filters.nb=filters.nb-1;
                set(guieega.filt.list,'String',filters.name,'Value',1);
                EEGAnalyzer('changefilt');
                EEGAnalyzer('filtab');
                EEGAnalyzer('selectsig');
            end
            
            %filter modification (lc, hc frequency or order)
        case 'changecutoff'
            s=get(guieega.filt.list,'Value');
            switch varargin{2}
                case 'listlowcut'
                    val=guieega.filt.lowcut.value(get(guieega.filt.lowcut.list,'Value'));
                    set(guieega.filt.lowcut.list,'Value',1);
                    set(guieega.filt.lowcut.edit,'String',num2str(val));
                case 'listhighcut'
                    val=guieega.filt.highcut.value(get(guieega.filt.highcut.list,'Value'));
                    set(guieega.filt.highcut.list,'Value',1);
                    set(guieega.filt.highcut.edit,'String',num2str(val));
                case 'listorder'
                    val=guieega.filt.order.value(get(guieega.filt.order.list,'Value'));
                    set(guieega.filt.order.list,'Value',1);
                    set(guieega.filt.order.edit,'String',num2str(val));
            end
            lc=str2double(get(guieega.filt.lowcut.edit,'String'));
            hc=str2double(get(guieega.filt.highcut.edit,'String'));
            order=round(str2double(get(guieega.filt.order.edit,'String')));
            if order<1 || isnan(order)
                order=guieega.filtdefaultorder;
            end
            set(guieega.filt.order.edit,'String',num2str(order));
            if isnan(hc)
                hc=0;
            end
            if isnan(lc)
                lc=0;
            end
            if (lc>hc) && lc~=0 && hc~=0
                msgbox('You have to set the low cutoff frequency below the high cutoff frequency !','Filters error','error','modal');
                EEGAnalyzer('changefilt');
            else                
                fs=eeg.rate;                                
                if (lc<fs/2) && (hc<fs/2)
                    filters.filt(s).lc=lc;
                    filters.filt(s).hc=hc;
                    filters.filt(s).order=order;
                    EEGAnalyzer('filtcoeff',s,get(guieega.filt.type.list,'Value'));
                    EEGAnalyzer('filtab');
                    EEGAnalyzer('selectsig');
                else                    
                    msgbox(['You have to set the low/high frequency cutoff below the half frequency sampling (i.e. ' num2str(fs) 'Hz/2) !'],'Filters error','error','modal');
                    EEGAnalyzer('changefilt');
                end
            end
            
        %compute the filter coefficients for the filter number varargin{2}
        %(butterworth filter) and varargin{3}=1 if passband
        case 'filtcoeff'                        
            ok=0;
            if nargin==3
                s=varargin{2}; %selected filter
                fs=eeg.rate;
                lc=filters.filt(s).lc;
                hc=filters.filt(s).hc;
                order=filters.filt(s).order;
                if (lc<fs/2) && (hc<fs/2)
                    if hc && lc
                        w=[lc hc]/(fs/2);
                        if varargin{3}==1
                            [filters.filt(s).b,filters.filt(s).a]=butter(order,w);
                            filters.filt(s).type='band';
                        else
                            [filters.filt(s).b,filters.filt(s).a]=butter(order,w,'stop');
                            filters.filt(s).type='stop';
                        end
                    else
                        if lc
                            [filters.filt(s).b,filters.filt(s).a]=butter(order,lc/(fs/2),'high');
                            filters.filt(s).type='high';
                        elseif hc
                            [filters.filt(s).b,filters.filt(s).a]=butter(order,hc/(fs/2),'low');
                            filters.filt(s).type='low';
                        else
                            filters.filt(s).a=1;filters.filt(s).b=1;
                            filters.filt(s).type='all';
                        end
                    end
                    ok=1;
                else
                    ok=0;
                end
            end
            if nargout
                varargout{1}=ok;
            end            
            
            %compute the global filter coeffcients (from a filters cascade)
        case 'filtab'
            filters.a=1;filters.b=1;
            for i=1:filters.nb
                filters.a=conv(filters.filt(i).a,filters.a);
                filters.b=conv(filters.filt(i).b,filters.b);
            end
            
            %display frequency response of the filters (need signal
            %processing toolbox for freqz !)
        case 'showfilter'
            if ~isfield(eeg,'rate')
                return
            end            
            if nargin==1
                if exist('freqz','file')==0 %test if the function freqz exists.
                    msgbox('The Matlab signal processing toolbox should be installed in order to display the frequency response with "freqz" !','Frequency response','error','modal');
                    return;
                end                
                close(findobj('Tag','eegafreq')); %close the frequency response figure if already opened                
                scr=get(0,'ScreenSize'); %get the screen size
                figure('Name',[guieega.figtitle '- Frequency response of filters'] ,'Position',[scr(3)/2-400 scr(4)/2-300 800 600],'Units','pixels','MenuBar','none','NumberTitle','off','DoubleBuffer','on','Color',guieega.defcol,'ToolBar','figure','Tag','eegafreq');
                s={};
                s{1}='Global frequency response of the filters';
                for i=1:filters.nb
                    s{i+1}=[filters.name{i} ' - type : ' filters.filt(i).type ' - bandwidth : ' num2str(filters.filt(i).lc)  'Hz to ' num2str(filters.filt(i).hc) 'Hz' ' - order : ' num2str(filters.filt(i).order)];
                end
                uicontrol('Style','popup','Units','normalized','Position',[0 0.97 1 0.03],'String',s,'Callback','EEGAnalyzer(''showfilter'',''sel'')','Enable','on','Tag','filtresponse');
                freqz(filters.b,filters.a,2048,eeg.rate);
            else
                val=get(gco,'Value');
                delete(findobj('Parent',gcf,'Type','axes'));
                hold on
                if val==1
                    freqz(filters.b,filters.a,2048,eeg.rate);
                else
                    val=val-1;
                    freqz(filters.filt(val).b,filters.filt(val).a,2048,eeg.rate);
                end
            end
            
            %Save the butterworth filters
        case 'savefilters'
            [filename, pathname, filterindex] = uiputfile({'*.mat','Mat filters file (*.mat)'},'Save filters');
            if filename
                fname=[pathname filename];
                filters.fs=eeg.rate; %save the frequency sampling
                save(fname,'filters','-v7');
            end
            
            %Load the butterworth filters
        case 'loadfilters'
            [filename, pathname, filterindex] = uigetfile({'*.mat','Mat filters file (*.mat)'},'Load filters');
            if filename
                fname=[pathname filename];
                load(fname);
                set(guieega.filt.list,'String',filters.name,'Value',1);
                if eeg.rate ~= filters.fs
                    filters.a=1;filters.b=1;
                    for i=1:filters.nb
                        ok=EEGAnalyzer('filtcoeff',i,strcmp(filters.filt(i).type,'band'));
                        if ~ok
                            msgbox('The loaded filter is not compatible with the current signal frequency sampling !','Filter error','error','modal');
                            EEGAnalyzer('clearfilters');
                            return
                        else
                            filters.a=conv(filters.filt(i).a,filters.a);
                            filters.b=conv(filters.filt(i).b,filters.b);                        
                        end
                    end                    
                end
                EEGAnalyzer('changefilt');
                EEGAnalyzer('selectsig');
            end
            
            %Reset filters i.e. remove all filters
        case 'clearfilters'
            EEGAnalyzer('initfilt');
            EEGAnalyzer('selectsig');            
            
            %show/hide legend i.e. channel name 
        case 'viewlegend'
            if nargin>1
                if strcmp(get(guieega.menu.viewlegend, 'Checked'),'on')
                    set(guieega.menu.viewlegend, 'Checked', 'off');
                    set(guieega.legend,'visible','off');
                else
                    set(guieega.menu.viewlegend, 'Checked', 'on');
                    set(guieega.legend,'visible','on');
                end
            else
                if strcmp(get(guieega.menu.viewlegend, 'Checked'),'on')
                    set(guieega.legend,'visible','on');
                else
                    set(guieega.legend,'visible','off');
                end
            end
            
            %include channel type in the legend of the channel name
        case 'viewlegendtype'
            if strcmp(get(guieega.menu.viewlegendtype, 'Checked'),'on')
                set(guieega.menu.viewlegendtype, 'Checked', 'off');
                guieega.legtyp=0;
            else
                set(guieega.menu.viewlegendtype, 'Checked', 'on');
                guieega.legtyp=1;
            end
            lg=numel(guieega.sig);
            for i=1:lg
                if guieega.legtyp
                    set(guieega.legend(i),'String',{[eeg.chantype{guieega.sig(i)} ': ' eeg.label{guieega.sig(i)}]});
                else
                    set(guieega.legend(i),'String',{eeg.label{guieega.sig(i)}});
                end
            end
            
            %voltage axe inversion
        case 'invy'
            if nargin>1
                if strcmp(get(guieega.menu.invy, 'Checked'),'on')
                    set(guieega.menu.invy, 'Checked', 'off');
                    mode='normal';
                else
                    set(guieega.menu.invy, 'Checked', 'on');
                    mode='reverse';
                end
            else
                if strcmp(get(guieega.menu.invy, 'Checked'),'on')
                    mode='reverse';
                else
                    mode='normal';
                end
            end
            if strcmp(mode,'normal')
                set(guieega.ylabel,'String',guieega.ytext.normal);
            else
                set(guieega.ylabel,'String',guieega.ytext.reverse);
            end
            set(guieega.axes,'YDir',mode);
            
            %select a zero phase filter
        case 'zerophasefilter'
            if nargin>1
                if strcmp(get(guieega.menu.zerofilter, 'Checked'),'on')
                    set(guieega.menu.zerofilter, 'Checked', 'off');
                    filters.zero=0;
                else
                    set(guieega.menu.zerofilter, 'Checked', 'on');
                    filters.zero=1;
                end
                EEGAnalyzer('selectsig');
            else
                if strcmp(get(guieega.menu.zerofilter, 'Checked'),'on')
                    filters.zero=1;
                else
                    filters.zero=0;
                end
            end
            
            %playing the signals in time
        case 'play'
            guieega.play=1;
            maxst=get(guieega.timeslider,'Max');
            st=get(guieega.timeslider,'Value')+guieega.stepplay;
            while (st<=maxst) && (guieega.play==1)
                set(guieega.timeslider,'Value',st);
                st=st+guieega.stepplay;
                EEGAnalyzer('movewindow');
                pause(guieega.stepplay);
            end
            guieega.play=0;
            
            %stop playing the signal
        case 'stop'
            guieega.play=0;
            
            %jump to a specific time in seconds in the window (at begin)
        case 'goto'
            val=str2double(get(guieega.gotoedit,'String'));
            if (val>=get(guieega.timeslider,'Min'))&&(val<=get(guieega.timeslider,'Max'))
                set(guieega.timeslider,'Value',round(val));
                EEGAnalyzer('movewindow');
            end
            
            %change the incrementation step between each update when playing
        case 'changestep'
            val=str2double(get(guieega.stepedit,'String'));
            if (val>=0)
                guieega.stepplay=val;
            end
            
            %callback by clicking on axes and signal plots (double click only)
        case 'clickax'
            cur=get(guieega.ax,'CurrentPoint');
            set([guieega.sel guieega.seltxt],'Visible','off');
            if strcmp(get(guieega.fig,'SelectionType'),'open') %double click
                ylim=get(guieega.ax,'YLim');
                tt=cur(1);
                ind=find(tt<=eeg.time);
                if ~isempty(ind)
                    ind=ind(1);                    
                    txt=[' t=' num2str(round(eeg.time(ind)*1000)) 'ms\newline '];
                    lg=length(guieega.sig);
                    for i=1:lg
                        datay=get(guieega.hplot(i),'YData');
                        txt=[txt eeg.label{guieega.sig(i)} '=' num2str(round(datay(ind))) '\muV\newline '];
                    end
                    set([guieega.sel guieega.seltxt],'Visible','on');
                    set(guieega.sel,'XData',[cur(1) cur(1)],'YData',ylim);
                    set(guieega.seltxt,'Position',[cur(1) ylim(2) 0],'String',txt);
                end
            end
            refresh(guieega.fig);            
 
            %move the signal panel verticaly (if more than guieega.division signals)
        case 'movepanel'
            val=get(guieega.panelslider,'Value');
            pos=get(guieega.axpanel,'Position');
            pos(2)=-val;
            set(guieega.axpanel,'Position',pos);
            
            %display/hide EEG channels list
        case 'showhide'
            if strcmp(get(guieega.listsig,'Visible'),'on')
                set(guieega.listsig,'Visible','off');
                set([guieega.mainax guieega.mainpanel],'Position',[0.02 0.1 0.96 0.85]);
                set(guieega.showsigbt,'TooltipString','Show the channels list','String','>','CData',guieega.icons.sig);
            else
                set(guieega.listsig,'Visible','on');
                set([guieega.mainax guieega.mainpanel],'Position',[0.18 0.1 0.8 0.85]);
                set(guieega.showsigbt,'TooltipString','Hide the channels list','String','<','CData',guieega.icons.sig(:,end:-1:1,:));
            end
            
            %show/hide the toolbar
        case 'showtoolbar'
            if varargin{2} %show toolbar
                if ~isempty(guieega.tool.bar) %custom toolbar                                        
                    set(guieega.tool.bar,'Visible','on');
                else %figure toolbar
                    set(guieega.fig,'Toolbar','figure');
                end
                set(guieega.menu.showtoolbar,'Label','Hide toolbar','Callback','EEGAnalyzer(''showtoolbar'',0)');
            else %hide toolbar
                if ~isempty(guieega.tool.bar)                                        
                    set(guieega.tool.bar,'Visible','off');
                else
                    set(guieega.fig,'Toolbar','none');
                end
                set(guieega.menu.showtoolbar,'Label','Show toolbar','Callback','EEGAnalyzer(''showtoolbar'',1)');
            end      
            
            %change the number of divisions in the display axes
        case 'changedivision'
            prompt= {'Enter the maximum number of channels you want to display together'};
            title = 'Number of channels divisions';
            answer = inputdlg(prompt,title,1,{num2str(guieega.division)});
            if isempty(answer)
                return
            end
            d=str2double(answer{1});
            if isnan(d) || d<1 || floor(d)~=d
                return;
            end
            guieega.division=d;
            EEGAnalyzer('selectsig');
            
            %change the delay after selecting channels/signals
        case 'changedelaytimer'
            prompt= {'Enter the display refresh delay after selecting channels'};
            title = 'Refresh delay';
            answer = inputdlg(prompt,title,1,{num2str(guieega.timerdelay)});
            if isempty(answer)
                return
            end
            d=str2double(answer{1});
            if isnan(d) || d<1 || floor(d)~=d
                return;
            end
            guieega.timerdelay=d;
            set(guieega.refreshtimer,'StartDelay',guieega.timerdelay);
            
            %open the manual
        case 'help'
            try
                open('EEGAnalyzer.pdf');
            catch
                msgbox('The manual cannot be opened. Please check if a pdf reader is installed on the system and if the pdf file is present in the toolbox folder !','Error opening the manual','error','modal');
            end
            
            %display the "About" dialog
        case 'About'
            msg={'The "EEG Analyzer" toolbox for SPM provides a user-friendly interface for M/EEG visualization. It reads SPM M/EEG files and also offers basic M/EEG filtering options. If present, events are also shown.', ...
                'Version 1 - 4 May 2018', ...                
                'Author : Rudy ERCEK (rercek@ulb.ac.be)', ...
                'Website : https://bitbucket.org/ulbeeg/eeganalyzer', ...
                'License : GPL v2, see https://www.gnu.org/licenses/gpl-2.0.txt', ...
                'Copyright © 2013-2018 - Université Libre de Bruxelles' };                
            msgbox(msg,'About','help','modal');
            
            %Function called when the dialog is resized 
        case 'resizedlg'
            pos=get(guieega.fig,'Position');
            if pos(3)<640 || pos(4)<480
                scr=get(0,'ScreenSize');
                %by default, reset the figure to its original position
                set(guieega.fig,'Position',[scr(3)/2-512 scr(4)/2-360 1024 720]);
            end                        
            
            %close EEGAnalyzer
        case 'close'
            guieega.play=0;
            pause(0.01);
            close(findobj('Tag','eegafreq'));
            closereq;
            
            %show the callback name if it doesn't exist
        otherwise
            disp(['Unknown callback for EEGAnalyzer : ' varargin{1}]);
    end
    
end

%number conversion to string if v is not a string
function str=tostr(v)
str=v;
if isnumeric(str)
    str=num2str(str);
end




