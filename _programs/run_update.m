function result = run_update(varargin)
%RUN_UPDATE Download data, estimate the bridge and build the local report.
% Example: setup_itnow; run_update('download',false,'vintage','20261009')
% Website staging is optional. This function never commits or publishes.

cfg = pipeline_config(varargin{:});
if cfg.download
    if strlength(string(cfg.vintage)) > 0
        error('run_update:Vintage', ...
            'To reuse a saved vintage, also set download to false.');
    end
    get_data(cfg);
    vintage = string(cfg.run_date,'yyyyMMdd');
else
    vintage = string(cfg.vintage);
    if strlength(vintage) == 0
        vintage = latest_vintage(cfg.base_path);
    end
end

result = estimate_nowcasts(cfg,vintage);
root = fileparts(fileparts(mfilename('fullpath')));
script = fullfile(root,'scripts','build_report.py');
args = [string(cfg.python), script, "--base-path", string(cfg.base_path), ...
    "--vintage", vintage];
if cfg.update_website
    if strlength(string(cfg.website_root)) == 0
        error('run_update:WebsitePath', ...
            'Set website_root to the local website checkout.');
    end
    args = [args, "--website-root", string(cfg.website_root)];
end
% POSIX single quoting also protects paths containing spaces or apostrophes.
quoted = shell_quote(args);
[status,message] = system(strjoin(quoted,' '));
fprintf('%s',message);
if status ~= 0
    error('run_update:Report','Report generation failed; forecasts were saved.');
end
end
