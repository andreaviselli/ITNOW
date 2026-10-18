function cfg = pipeline_config(varargin)
%PIPELINE_CONFIG Paths, fixed timing rules and source-download settings.
root = string(fileparts(fileparts(mfilename('fullpath'))));
cfg = struct('base_path',root,'website_root',"", ...
    'run_date',datetime('today'),'eval_end',previous_completed_month(datetime('today')), ...
    'factor_start',datetime(1996,5,1),'first_forecast',datetime(2006,4,1), ...
    'vintage',"",'download',true,'update_website',false,'python',"python3", ...
    'edition',"",'preliminary_ed',"",'auto_discover_istat',true, ...
    'istat_lookback_months',12,'istat_probe_timeout',15,'source_notices',struct(), ...
    'oecd_confidence_mode',"auto",'interactive',false,'web_timeout',60, ...
    'ftsemib_mode',"stooq_yahoo",'ftsemib_yahoo_start',datetime(2026,9,1), ...
    'allow_stale_ftsemib',false,'stooq_url',"https://stooq.com/q/d/l/?s=^fmib&i=d");
if mod(numel(varargin),2); error('config:Arguments','Use name-value pairs.'); end
for k=1:2:numel(varargin)
    name=string(varargin{k});
    if ~isfield(cfg,name) && ~ismember(name,["oecd_confidence_csv","ftsemib_fallback_file","stooq_downloader"])
        error('config:UnknownSetting','Unknown setting: %s',name);
    end
    cfg.(name)=varargin{k+1};
end
cfg.run_date=datetime(cfg.run_date); cfg.eval_end=datetime(cfg.eval_end);
names=string(varargin(1:2:end));
if ~ismember("eval_end",names); cfg.eval_end=previous_completed_month(cfg.run_date); end
if cfg.eval_end~=dateshift(cfg.eval_end,'start','month') || ...
        cfg.eval_end>previous_completed_month(cfg.run_date)
    error('config:ReferenceMonth','eval_end must be a completed calendar month.');
end
if ~isfield(cfg,'oecd_confidence_csv')
    cfg.oecd_confidence_csv=struct('CCICP',fullfile(cfg.base_path,'DATA','OECD','ITCCI.csv'), ...
        'BCICP',fullfile(cfg.base_path,'DATA','OECD','ITCBC.csv'));
end
if ~isfield(cfg,'ftsemib_fallback_file'); cfg.ftsemib_fallback_file=fullfile(cfg.base_path,'DATA','FTSEMIB.csv'); end
if ~isfield(cfg,'stooq_downloader'); cfg.stooq_downloader=fullfile(cfg.base_path,'scripts','download_stooq.py'); end
end
