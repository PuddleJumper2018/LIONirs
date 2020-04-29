function nirs_boxy_write_vhdr(OutputFile,DataFile,MarkerFile,...
    CreatingFunction,ChannelResolution,ChannelUnits,...
    ChannelLabels,SamplingInterval,varargin)
%Modifier Julie remplacement de la fonction original nirs_boxy_write_header
%Permet la sauvegarde de 
%info required
%DataFile
%MarkerFile
%NumberOfChannels
%SamplingInterval
%Channel Names, given as a column of cells
%infodatapoint = varargin{1}
info = [];
if numel(varargin)>=1
    info.datapoint = varargin{1};
end
NumberOfChannels=numel(ChannelLabels);

fid = fopen(OutputFile,'wt'); %write
%first 5 lines
fprintf(fid,'%s\n%s%s\n\n%s\n%s\n',... % 
'Brain Vision Data Exchange Header File Version 1.0',...
'; Data created by ',CreatingFunction,...
'[Common Infos]',...
'Codepage=UTF-8');

%names of the files associated with the header
fprintf(fid,'%s%s\n%s%s\n',... %
'DataFile=',DataFile,'MarkerFile=',MarkerFile);
%more text
fprintf(fid,'%s\n%s\n%s\n%s\n%s%s\n',... %
'DataFormat=BINARY',...
'; Data orientation: VECTORIZED=ch1,pt1, ch1,pt2..., MULTIPLEXED=ch1,pt1, ch2,pt1 ...',...
'DataOrientation=MULTIPLEXED','DataType=TIMEDOMAIN',...
'NumberOfChannels=',int2str(NumberOfChannels));
%%JT
if isfield(info,'datapoint')
    fprintf(fid,'%s\n',['DataPoints=',num2str(info.datapoint)]);
end
fprintf(fid,'%s\n%s\n%s%s\n\n',... %
'; Sampling interval in microseconds if time domain (convert to Hertz:',...
'; 1000000 / SamplingInterval) or in Hertz if frequency domain:',...
'SamplingInterval=',int2str(SamplingInterval));
%more text
%fprintf(fid,'%s\n%s\n%s\n%s\n\n',... %
%'Averaged=NO','SegmentDataPoints=0','SegmentationType=NOTSEGMENTED',...
%'DataPoints=0');
%more text
% fprintf(fid,'%s\n%s\n%s\n%s\n%s\n%s\n%s\n\n',... %
% '[ASCII Infos]',...
% '; Decimal symbol for floating point numbers: the header file always uses a dot (.),',...
% '; however the data file might use a different one',...
% 'DecimalSymbol=.',...
% '; SkipLines, SkipColumns: leading lines and columns with additional informations.',...
% 'SkipLines=0','SkipColumns=0');
%more text
fprintf(fid,'%s\n%s\n\n',... %
 '[BINARY Infos]',...
 'BinaryFormat=IEEE_FLOAT_32'); %INT_16'); %IEEE_FLOAT_32');

%more text
fprintf(fid,'%s\n%s\n%s\n%s\n%s\n',... %
'[Channel Infos]',...
'; Each entry: Ch<Channel number>=<Name>,<Reference channel name>,',...
'; <Resolution in "Unit">,<Unit>,<Future extentions...',...
'; Fields are delimited by commas, some fields might be omitted (empty).',...
'; Commas in channel names are coded as "\1".'); 

%channel info
ch_str=[',,' ChannelResolution ',' ChannelUnits];
for Cidx=1:NumberOfChannels
    fprintf(fid,'%s%s%s%s%s\n',...
        'Ch',num2str(Cidx),'=',ChannelLabels{Cidx,1},ch_str);
end
fclose(fid);
end