function out = nirs_run_step_artefact_detection(job)
% Automatic step detection following a threshold set by the user. Bad
% points indice, duration and related channel are written in the .vmrk
% file. Work on normalise data

%filename prefix 
prefix = 'a'; %for "artifact"
DelPreviousData  = job.DelPreviousData;


%Test 1 ROLL AVERAGE TO DETECT HIGH INTENSITY JUMP
difference_of_means = job.b_meandiff.m_meandiff;
thr_min_val = 0 ; %job.b_meandiff.thresholdmin;

printreportthreshold = job.b_meandiff.printreportthreshold;

%Test 2 correlation entre les artefacts
corr_thr = job.b_corr.corr_thr;
option_find_correlation = job.b_corr.m_corr;

%Test 3 dur�e minimal de signal continue sans artefact 
m_min_subinterval  = job.b_min_subinterval.m_min_subinterval;
min_subinterval =  job.b_min_subinterval.min_subinterval;
too_small_step_dur  =2; 

%Test 4 nombre de canaux minimaux � avoir un artefact en m�me temps
minpourcentage = job.b_minpourcentagebad.minpourcentagebad;
option_minpourcentage = job.b_minpourcentagebad.m_minpourcentagebad;

   
   h=figure;
   set(h,'visible','off');
   fprintf('%s\n','File processed');
for filenb=1:size(job.NIRSmat,1) %Loop over all subjects
        tic
        NIRS = [];
        load(job.NIRSmat{filenb,1});      
        [dirmat,~,~]= fileparts(job.NIRSmat{filenb,1});
        min_sub = ceil(min_subinterval*NIRS.Cf.dev.fs); %minimum duration of a subinterval 
       
  
        %use last step of preprocessing 
        lst = length(NIRS.Dt.fir.pp);
        rDtp = NIRS.Dt.fir.pp(lst).p; % path for files to be processed
        NC = NIRS.Cf.H.C.N;  
        fs = NIRS.Cf.dev.fs;
        step  = ceil(job.b_meandiff.movingaverage_nbpoint ./(1/fs)); %nb of point for moving average
        thr_ind =job.b_meandiff.thresholdstep;       
        indconsecutifthreshold = ceil(job.b_meandiff.too_small_step_dur./(1/fs));
        for f=1:size(rDtp,1) %Loop over all files of a NIRS.mat
                d = fopen_NIR(rDtp{f,1},NC);           
                samp_length = size(d,2);
                time = 1/NIRS.Cf.dev.fs:1/NIRS.Cf.dev.fs:samp_length*1/NIRS.Cf.dev.fs;
                stepmat = zeros(size(d,1),size(d,2)); %Matrix for storage of bad steps
                stepmat_temp = [];
                rho = [];                
                ind_dur_ch = [];
                
                                 
                
                [pathstr, name, ext] = fileparts(NIRS.Dt.fir.pp(lst).p{f});
                if job.PrintReport
                    if  ~isdir([dirmat,filesep,'ArtifactDetection_Report',filesep])
                        mkdir([dirmat,filesep,'ArtifactDetection_Report',filesep,'EachCh',filesep,name]);
                    end
                end 
                threshold_all = zeros(NC,1);
                %TEST 1 diff mean roll average
                for Idx = 1:NC %Loop over all channels except noisy one    
                    if NIRS.Cf.H.C.ok(Idx, f)==1                                 
                        meantot = [];
                        mean_diff = [];
                        stepmat_temp = stepmat(Idx,:); %Remember already found steps to avoid passing through correlation again               
                        if difference_of_means %Moving window average
                           
                            %Etape 1 Moving window average moyenne tournante
                            for i = 1:step %first point all same value
                                meantot(i) = mean(d(Idx,1:step));
                            end
                            for i = 1+step:samp_length-step %window between
                                meantot(i) = mean(d(Idx,i-step:i+step));
                            end
                            for i = samp_length-step:(samp_length+1) %end of the window all same value
                               meantot(i) = mean(d(Idx,samp_length-step:samp_length)); 
                            end 
                            mean_diff = diff(meantot); 

                            zsc = zscore(mean_diff);      
                            mean_diff = zsc;
                            ind = find(abs(zsc) >thr_ind); 
                            threshold = thr_ind;

                            %Etape 3 Garder les intervals de plus de
                            %indconsecutifthreshold point consecutif
                            inddiff = diff(ind);
                            compte = 0;
                            indconsecutif  = [];
                            addid = [];
                            for i = 1:numel(inddiff) 
                                if inddiff(i) == 1
                                    compte = compte + 1;
                                    if compte >= indconsecutifthreshold; 
                                        indconsecutif = [indconsecutif,addid,ind(i)];
                                        addid = [];
                                    else
                                        addid = [addid,ind(i)]; %store the first in memory in case it will be use
                                    end
                                else 
                                    addid = [];
                                    compte = 0;
                                end    
                            end     
                            idbad = [];
                            for i=1:numel(indconsecutif)
                            idbad = [idbad, (indconsecutif(i)-(round(step)+round(step/2))):(indconsecutif(i)+(round(step/2)))];
                            idtolong =  find(idbad> size(stepmat,2));
                            if ~isempty(idtolong)
                                idbad(idtolong)=[]; 
                            end
                            idtoshort =   find(idbad<= 0);
                            if ~isempty(idtoshort)
                                 idbad(idtoshort)=[];                                   
                            end
                  
                            stepmat(Idx, idbad)=1; 
                            mean_all(Idx) = threshold; 
                            mean_d(Idx) = mean(d(Idx,:));
                           
                            end           
                                             
                       if printreportthreshold 
                                h=figure;
                                set(h,'visible','on') ;                          
                                subplot(2,1,1)
                                cla 
                                hold on
                                plot(time,mean_diff)             
                                xval= mean_diff;
                                plot([time(1),time(end)],[threshold,threshold],'r');
                                plot([time(1),time(end)],[-threshold, -threshold],'r');
                                plot([time(1),time(end)],[0,0],'k');
                                bad = find(stepmat(Idx,:));
                                plot(time(bad),xval(bad),'xy');
                                ylabel('Mean diff (zscore)','fontsize',12)
                                title(['Artifact detection moving average difference of ',num2str(step),' points ch:', num2str(Idx)],'fontsize',12)
                                set(gca,'fontsize',12)
                                subplot(2,1,2)
                                cla
                                hold on
                                plot(time,d(Idx,:))   
                                plot(time(bad),d(Idx,bad),'xy');
                                title(['Suspecting noise marked in yellow'])     
                                set(gca,'fontsize',12)

                                if ~isdir([dirmat,filesep,'ArtifactDetection_Report',filesep,'EachCh',filesep,name])
                                    mkdir([dirmat,filesep,'ArtifactDetection_Report',filesep,'EachCh',filesep,name]);
                                end                     
                                xlabel('Time (s)')
                                ylabel('Original data (a.u.)')
                                set(gca,'fontsize',12)
                                saveas(h,[dirmat,filesep,'ArtifactDetection_Report',filesep,'EachCh',filesep,name,filesep,name,'_ch_',num2str(Idx),'tr',num2str(thr_ind),'.jpg'],'jpg')                  
                                saveas(h,[dirmat,filesep,'ArtifactDetection_Report',filesep,'EachCh',filesep,name,filesep,name,'_ch_',num2str(Idx),'tr',num2str(thr_ind),'.fig'],'fig')                  
                                close(h)
                           
                       end         
                    end
                    end
                end
                if difference_of_means
                if job.PrintReport
                    hsummary = figure;
                    set(hsummary,'unit','pixel','position',[1 1 800 600]);
                   % set(hsummary,'visible','off')   
                    subplot(3,1,[1,2])
                    imagesc(time,1:size(d,1),stepmat)
                    xlim([time(1),time(end)])
                    ylabel('Channel id number','fontsize',12)              
                    title(['Summary of bad interval from artifact detection apply on:', name ,' tr ',num2str(thr_ind)],'fontsize',12 )                    
                    set(gca,'fontsize',12)
                    subplot(3,1,3)
                    perc_criterion1 = sum(stepmat)/size(stepmat,1)*100;
                    plot(time, sum(stepmat)/size(stepmat,1)*100)
                    xlabel('Time (s)','fontsize',12)
                    ylabel('Noisy channels (%)','fontsize',12)
                    title('Percentage of channel noisy in function of time','fontsize',12)
                    set(gca,'fontsize',12)
                    xlim([time(1),time(end)])
                    ylim([1,100])
                    saveas(hsummary,[dirmat,filesep,'ArtifactDetection_Report',filesep,'Report', name,'__01zscore_','tr',num2str(thr_ind),'.jpg'],'jpg')  
                    saveas(hsummary,[dirmat,filesep,'ArtifactDetection_Report',filesep,'Report', name,'__01zscore_','tr',num2str(thr_ind),'.fig'],'fig')  
                    close(hsummary);

                end
                end
                 stepmat_temp = stepmat;
                % Update stepmat to remove long_bad_step and add
                % long_bad_sub
                % Look for minimum duration of bad interval

           %   figure;plot(sum(stepmat)/size(stepmat,1)*100)
              
                  %TEST 2 Find min pourcentage min channel
                  if option_minpourcentage
                    indbad= find(sum(stepmat)/size(stepmat,1)>minpourcentage*0.01);
                    matgood = ones(size(stepmat,2),1);
                    if ~isempty(indbad)
                    matgood(indbad) = 0;
                    end
                    indgood = find(matgood);
                    %stepmat(:,indbad) = 1;
                    stepmat(:,indgood)=0;
                   if job.PrintReport
                        hsummary = figure;
                        set(hsummary,'unit','pixel','position',[1 1 800 600]);

                       % set(hsummary,'visible','off');
                        subplot(3,1,[1,2])
                        imagesc(time,1:size(d,1),stepmat)
                        xlim([time(1),time(end)])
                        ylabel('Channel id number','fontsize',12)              
                        title(['Summary Minimal percentage of bad channels to be marked apply on :', name ,' min = ',num2str(minpourcentage)] ,'fontsize',12)
                        set(gca,'fontsize',12)
                        subplot(3,1,3)
                        plot(time, sum(stepmat)/size(stepmat,1)*100)
                        perc_criterion3 = sum(stepmat)/size(stepmat,1)*100;
                        xlabel('Time (s)','fontsize',12)
                        ylabel('Noisy channels (%)','fontsize',12)
                        title('Percentage of channel noisy in function of time','fontsize',12)
                        set(gca,'fontsize',12)

                        xlim([time(1),time(end)])
                        ylim([1,100])
                        saveas(hsummary,[dirmat,filesep,'ArtifactDetection_Report',filesep,'Report' name,'__02percentagemin_',num2str(minpourcentage),'.jpg'],'jpg')  
                        saveas(hsummary,[dirmat,filesep,'ArtifactDetection_Report',filesep,'Report' name,'__02percentagemin_',num2str(minpourcentage),'.fig'],'fig')  
                        close(hsummary);
                   end   
                  end
                  
                  
                  %TEST 3 min time subinterval
                  if m_min_subinterval
                    for Idx = 1:NC 
                            step_dur = 0;
                            count_sub_dur = false;
                            sub_dur = 1;
                            stepmat_ch = stepmat(Idx,:);
                            stepmat_ch(1) = 1; %To mark subintervals starting with the beginning of the signal
                            stepmat_ch(end) = 1;
                            for i = 1:numel(stepmat_ch)
                                if stepmat_ch(i) > 0 %All non-zero positive elements signifies step
                                    step_dur = step_dur + 1;
                                    if count_sub_dur
                                        count_sub_dur = false;
                                        if sub_dur < min_sub %long_bad_sub
                                            stepmat(Idx,i-sub_dur:i) = 1;
                                        end
                                        sub_dur = 1;
                                    end
                                else
                                    if step_dur~=0 %&& step_dur < max_dur  %bad_step
                                        count_sub_dur = true; %we now want to know if the following interval is not long enough to be a long_sub
                                    else
                                        stepmat(Idx,i-step_dur:i) = 0; %long_bad_step are not to be considered
                                    end
                                    step_dur = 0;
                                    if count_sub_dur
                                        sub_dur = sub_dur + 1;
                                    end
                                end
                            end
                    end
       
                  
                          id = find( sum(stepmat));
                          if ~isempty(id)
                              stepdif = id(2:end)-id(1:end-1);
                              idstep = find(stepdif>1);
                             start= [1,id(idstep+1)] ;
                              stop   = [id(idstep),id(end)];
                             interval=[start;stop];
                              for idinterval = 2:size(interval,2)                              
                               idch = find(sum(stepmat(:,[interval(1,idinterval):interval(2,idinterval)] ),2)); 
                               stepmat(idch,[interval(1,idinterval):interval(2,idinterval)])=1;
                              end
                              clear interval idinterval
                          end
                          
                end
                if  m_min_subinterval
                    if job.PrintReport
                        hsummary = figure;
                        set(hsummary,'unit','pixel','position',[1 1 800 600]);
                        subplot(3,1,[1,2])
                        imagesc(time,1:size(d,1),stepmat)
                        xlim([time(1),time(end)])
                        ylabel('Channel id number','fontsize',12)
                        title(['Summary of Minimal subinterval apply on:', name ,' min: ',num2str(min_subinterval)],'fontsize',12)
                        set(gca,'fontsize',12)

                        subplot(3,1,3)
                        plot(time, sum(stepmat)/size(stepmat,1)*100)
                        perc_criterion2 = sum(stepmat)/size(stepmat,1)*100;
                        xlabel('Time (s)','fontsize',12)
                        ylabel('Noisy channels (%)','fontsize',12)
                        title('Percentage of channel noisy in function of time','fontsize',12)
                        set(gca,'fontsize',12)
                        xlim([time(1),time(end)])
                        ylim([1,100])
                        saveas(hsummary,[dirmat,filesep,'ArtifactDetection_Report',filesep,'Report' name,'__03minsubinterval_',num2str(min_subinterval),'.jpg'],'jpg')  
                        saveas(hsummary,[dirmat,filesep,'ArtifactDetection_Report',filesep,'Report' name,'__03minsubinterval_',num2str(min_subinterval),'.fig'],'fig')  
                        close(hsummary);
                    end 
                end
                  

                 
                 %TEST 4 Correlation between channels
                 if option_find_correlation 
                 compte = 1;
                 for Idx = 1:NC %find_correlation
                     largernpoint = 10;
                    try
                        indbad = find(stepmat(Idx,:));
                        inddiff = diff(indbad);
                        inddiff(end+1) = 0;
                        step_dur = 0;                        
                        for i = 1:numel(indbad) %For all steps just found
                            if inddiff(i) == 1
                                step_dur = step_dur+1;
                            else
                                temp_ind = indbad(i)-step_dur;
                                temp_dur = step_dur+1;
                                step_dur = 0; %reinitialisation 
                                interval = [temp_ind temp_ind+temp_dur]; % interval = [ind_start ind_end]
                                if interval(2) >= (size(d,2)-largernpoint)
                                    interval(2)=size(d,2)-largernpoint;
                                end
                                 if interval(1)-largernpoint < 1
                                        interval(1) = 1+largernpoint;
                                 end
                                   % ; interval(2) = size(d,2)-1; end;
                                
                                 if numel(find(stepmat_temp(interval(1):interval(2)))) < 0.9*temp_dur %In the case of a non- before identified step
                                  
                                   
                                    stepmat(Idx,interval(1):interval(2)) = 1;                                    
                                    d1 = d(Idx, interval(1)-largernpoint:interval(2)+largernpoint)';
                        
                                    for Ich = 1:NC   %Run through all the channels to find correlation for the selected interval
                                        if Ich~=Idx;   %Select a valid channel
                                            d2 = d(Ich, interval(1)-largernpoint:interval(2)+largernpoint)';
                                            if corr(d1,d2)>= corr_thr
                                                stepmat(Ich,interval(1):interval(2)) = 1;
                                            end
                                        end
                                    end
                                end 

                            end  
                        end   
                    catch
                           disp('Failed to use correlation between channels.');
                    end
                 end
                 end
                 if option_find_correlation 

                 if job.PrintReport
                    hsummary = figure;
                    set(hsummary,'unit','pixel','position',[1 1 800 600]);

                   % set(hsummary,'visible','off');
                    subplot(3,1,[1,2])
                    imagesc(time,1:size(d,1),stepmat)
                    xlim([time(1),time(end)])
                    ylabel('Channel id number','fontsize',12)              
                    title(['Summary of bad interval correlation apply on :', name ,' tr ',num2str(corr_thr)],'fontsize',12)
                    set(gca,'fontsize',12)
                    subplot(3,1,3)
                    plot(time, sum(stepmat)/size(stepmat,1)*100)
                    perc_criterion4 = sum(stepmat)/size(stepmat,1)*100;

                    xlabel('Time (s)','fontsize',12)
                    ylabel('Noisy channels (%)','fontsize',12)
                    title('Percentage of channel noisy in function of time','fontsize',12)
                    set(gca,'fontsize',12)
                    xlim([time(1),time(end)])
                    ylim([1,100])
                    saveas(hsummary,[dirmat,filesep,'ArtifactDetection_Report',filesep,'Report' name,'__04correlation_',num2str(corr_thr),'.jpg'],'jpg')  
                    saveas(hsummary,[dirmat,filesep,'ArtifactDetection_Report',filesep,'Report' name,'__04correlation_',num2str(corr_thr),'.fig'],'fig')  
                    close(hsummary);
                end
                 end
            
               
          
                                


                %WRITE DATA
                %save steps info in ind_dur_ch (same code as above)
                stepmat = (copy_channel_noise(stepmat'))';
                a=1; 
                for Idx = 1:NC
                    indbad = find(stepmat(Idx,:));
                    inddiff = diff(indbad);
                    
                    inddiff(end+1) = 0;
                    step_dur = 0;
                    for i = 1:numel(indbad) %For all steps just found
                        if inddiff(i) == 1
                            step_dur = step_dur+1;
                        else
                            if step_dur > too_small_step_dur % Neglect too small steps
                                ind_dur_ch(a,1) = indbad(i)-step_dur;
                                ind_dur_ch(a,2) = step_dur+1;
                                ind_dur_ch(a,3) = Idx;
                                ind_dur_ch(a,4) = 0; %bad step
                                a = a+1;
                            end
                            step_dur = 0;
                        end
                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if ~isempty(ind_dur_ch)
                    [ind_dur_ch] = detect_subintervals_dur(ind_dur_ch);
                    %Writing bad points and sufficient step intervals in
                    %.wmrk file
                    [dir1,fil1,ext1] = fileparts(rDtp{f});
                    infilewmrk = fullfile(dir1,[fil1 '.vmrk']);
                    outfilevmrk = fullfile(dirmat,[prefix fil1 '.vmrk']);
                    copyfile(infilewmrk,outfilevmrk);
                    description = ['thr_ind',num2str(thr_ind)];
                    write_vmrk(outfilevmrk,'bad_step',description,ind_dur_ch(ind_dur_ch(:,4)==0,1:3));
                    infilevhdr = fullfile(dir1,[fil1 '.vhdr']);
                    outfilevhdr = fullfile(dirmat,[prefix fil1 '.vhdr']);
                    copyfile(infilevhdr,outfilevhdr);    
                    %write_vmrk(outfilevmrk,'bad_step',description,ind_dur_ch(ind_dur_ch(:,4)==2,1:3));
                else
                    disp(['No steps found for Subject ',int2str(filenb),', file ',int2str(f),'.']);
                    [dir1,fil1,ext1] = fileparts(rDtp{f});
                    infilewmrk = fullfile(dir1,[fil1 '.vmrk']);
                    outfilevmrk = fullfile(dirmat,[prefix fil1 '.vmrk']);
                    copyfile(infilewmrk,outfilevmrk);         
                    infilevhdr = fullfile(dir1,[fil1 '.vhdr']);
                    outfilevhdr = fullfile(dirmat,[prefix fil1 '.vhdr']);
                    copyfile(infilevhdr,outfilevhdr);    
                end

                %%%%%%%%%%%%%%%
                [dir1,fil1,ext1] = fileparts(rDtp{f});
              
                if ~exist(dirmat,'dir'), mkdir(dirmat); end; 
                outfile = fullfile(dirmat,[prefix fil1 ext1]);
           
                if DelPreviousData
                    delete(rDtp{f,1});
                end
                fwrite_NIR(outfile,d);                                
                %add outfile name to NIRS
                if f == 1
                    NIRS.Dt.fir.pp(lst+1).pre = 'Artifact Detection';
                    NIRS.Dt.fir.pp(lst+1).job = job;
                end
                NIRS.Dt.fir.pp(lst+1).p{f,1} = outfile; 
                fprintf('%s\n',outfile);
                toc
        end       
             
               save(fullfile(dirmat,'NIRS.mat'),'NIRS');            
          
end
out.NIRSmat = job.NIRSmat;