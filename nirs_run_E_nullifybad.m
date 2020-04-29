function out = nirs_run_E_nullifybad(job)
% Nullify bad data points rejected by the step detection function.
%

prefix = 'null'; %for "nullify"
DelPreviousData  = job.DelPreviousData;


% if isfield(job,'NewDirCopyNIRSTRUE')
%     if isfield(job.NewDirCopyNIRSTRUE,'CreateNIRSCopy')
%         NewNIRSdir = job.NewDirCopyNIRSTRUE.CreateNIRSCopy.NewNIRSdir;
%         disp(['Create directory for condition ',NewNIRSdir])
%         NewDirCopyNIRS = 1;
%     else
%         NewDirCopyNIRS = 0;
%     end
% else
%     if isfield(job,'NewDirCopyNIRS')
%         if isfield(job.NewDirCopyNIRS,'CreateNIRSCopy')
%             NewNIRSdir = job.NewDirCopyNIRS.CreateNIRSCopy.NewNIRSdir;
%             disp(['Create directory for condition ',NewNIRSdir])
%             NewDirCopyNIRS = 1;
%         else
%             NewDirCopyNIRS = 0;
%         end
%     else
%         NewDirCopyNIRS = 0;
%     end
% end

%Markers for intervals to nullify
mrk_type = [];
% if job.markerstype.step_bad
    mrk_type = 'bad_step';
% end
% if job.markerstype.long_bad_step
%     mrk_type = [mrk_type; 'long_bad_step'];
% end
% if job.markerstype.long_sub_bad
%     mrk_type = [mrk_type; 'long_bad_sub '];
% end
% if job.markerstype.long_sub
%     mrk_type = [mrk_type; 'long_sub'];
% end
mrk_type_arr = cellstr(mrk_type);

for filenb=1:size(job.NIRSmat,1) %Loop over all subjects
    %Load NIRS.mat information
%     try
        NIRS = [];
        load(job.NIRSmat{filenb,1});
        [dir2,tmp,tmp] = fileparts(job.NIRSmat{filenb,1});
        fs = NIRS.Cf.dev.fs;
        padtime = round(job.paddingtime*fs);

        %use last step of preprocessing
        lst = length(NIRS.Dt.fir.pp);
        rDtp = NIRS.Dt.fir.pp(lst).p; % path for files to be processed
        NC = NIRS.Cf.H.C.N;
        fprintf('%s\n','File processed');
        for f=1:size(rDtp,1) %Loop over all files of a NIRS.mat
            d = fopen_NIR(rDtp{f,1},NC);            
            %erase previous matrices
            mrks = []; 
            ind = [];
            dur = [];

            [dir1,fil1,~] = fileparts(rDtp{f});
            vmrk_path = fullfile(dir1,[fil1 '.vmrk']);
            [ind_dur_ch] = read_vmrk_find(vmrk_path,mrk_type_arr);

            if ~isempty(ind_dur_ch)
                %hwaitbar = waitbar(0);
                for Idx = 1:NC %Loop over all channels
                   % waitbar(Idx/NC,hwaitbar,'Nullifying bad intervals...');
                    mrks = find(ind_dur_ch(:,3)==Idx | ind_dur_ch(:,3)==0);
                    
                    ind = ind_dur_ch(mrks,1);
                    indf = ind + ind_dur_ch(mrks,2);
                    
                    for i = 1:numel(ind)
                        if ind(i)-padtime < 1
                            ind(i) = padtime+1;
                        end
                        if indf(i)+padtime > size(d,2)
                            indf(i) = size(d,2)-padtime;
                        end
                        d(Idx,ind(i)-padtime:indf(i)+padtime) = NaN;
                    end
                end
                %close(hwaitbar);
             else
                disp(['Failed to nullify bad intervals for Subject ',int2str(filenb),', file ',int2str(f),'. No markers found in the .vmrk file. If you have already used the Step Detection function, your data may have no bad steps in it.']);
            end
            


                [dir1,fil1,ext1] = fileparts(rDtp{f});
                 infilevmrk = fullfile(dir1,[fil1 '.vmrk']);
                 infilevhdr = fullfile(dir1,[fil1 '.vhdr']);
                %if NewDirCopyNIRS
                 %   dir2 = [dir1 filesep NewNIRSdir];
                    if ~exist(dir2,'dir'), mkdir(dir2); end 
                    outfile = fullfile(dir2,[prefix fil1 ext1]);   
                    outfilevmrk = fullfile(dir2,[prefix fil1 '.vmrk']);
                    outfilevhdr = fullfile(dir2,[prefix fil1  '.vhdr']);

%                 else
%                     outfile = fullfile(dir1,[prefix fil1 ext1]);
%                     outfilevmrk = fullfile(dir1,[prefix fil1 '.vmrk']);
%                     outfilevhdr = fullfile(dir1,[prefix fil1  '.vhdr']);
%                 end
                if DelPreviousData
                    delete(rDtp{f,1});
                end
                fwrite_NIR(outfile,d);                 
                copyfile(infilevmrk,outfilevmrk);
                try
                   copyfile(infilevhdr,outfilevhdr); 
                catch
                end
            
                %add outfile name to NIRS
                if f == 1
                    NIRS.Dt.fir.pp(lst+1).pre = 'Nullify Bad Intervals';
                    NIRS.Dt.fir.pp(lst+1).job = job;
                end 
                NIRS.Dt.fir.pp(lst+1).p{f,1} = outfile; 
                fprintf('%s\n',outfile);
        end
        
%        if NewDirCopyNIRS
            save(fullfile(dir2,'NIRS.mat'),'NIRS');   
            job.NIRSmat{filenb,1}=fullfile(dir2,'NIRS.mat');
%         else
%             save(job.NIRSmat{filenb,1},'NIRS');
%             job.NIRSmat{1} = fullfile(dir1,'NIRS.mat');
%         end
%     catch
%         disp(['Failed to nullify bad intervals for Subject ',int2str(filenb)]);
%     end
end
            
out.NIRSmat = job.NIRSmat;
