function cfg = ITNOWConfig(varargin)
%ITNOWConfig Central configuration for automated ITNOW runs.

root = fileparts(fileparts(mfilename('fullpath')));

cfg = struct();
cfg.base_path = string(root);
cfg.website_root = "/path/to/website";
cfg.run_date = datetime("today", "Format", "uuuu-MM-dd");
cfg.eval_end = ITNOWPreviousCompletedMonth(cfg.run_date);

cfg.edition = "";
cfg.preliminary_ed = "";
cfg.auto_discover_istat = true;
cfg.istat_lookback_months = 12;
cfg.istat_probe_timeout = 15;

cfg.interactive = false;
cfg.ftsemib_mode = "stooq";
cfg.allow_stale_ftsemib = false;
cfg.web_timeout = 60;
cfg.stooq_downloader = fullfile(root, "scripts", "download_stooq.py");
cfg.ftsemib_fallback_file = fullfile(root, "DATA", "FTSEMIB.csv");

cfg.est_start = datetime("1996-05-01");
cfg.est_end = datetime("2006-04-01");
cfg.remove_covid = 0;
cfg.h_max = 0;
cfg.save_fcast = 1;
cfg.update_website = true;

if mod(numel(varargin), 2) ~= 0
    error("ITNOWConfig:InvalidArguments", ...
        "Override arguments must be name-value pairs.");
end

for k = 1:2:numel(varargin)
    name = string(varargin{k});
    cfg.(char(name)) = varargin{k + 1};
end

if ~isdatetime(cfg.run_date)
    cfg.run_date = datetime(cfg.run_date);
end
cfg.run_date.Format = "uuuu-MM-dd";

if ~isdatetime(cfg.eval_end)
    cfg.eval_end = datetime(cfg.eval_end);
end
cfg.eval_end.Format = "uuuu-MM-dd";

cfg.stooq_url = "https://stooq.com/q/d/l/?s=^fmib&i=d";
end
