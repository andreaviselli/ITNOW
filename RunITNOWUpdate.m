function status = RunITNOWUpdate(varargin)
%RunITNOWUpdate Run the ITNOW data, forecast, and reporting pipeline.
%
% Example:
%   setup_itnow; RunITNOWUpdate
%   setup_itnow; RunITNOWUpdate("update_website", false)

setup_itnow("quiet", true)
cfg = ITNOWConfig(varargin{:});

runTimer = tic;
ITNOWPrintHeader(cfg);

stepTimer = ITNOWStartStep(1, 5, "Running preflight checks");
try
    ITNOWPreflight(cfg);
catch ME
    ITNOWFailStep(1, 5, stepTimer);
    rethrow(ME)
end
ITNOWDoneStep(1, 5, stepTimer);

stepTimer = ITNOWStartStep(2, 5, "Discovering ISTAT GDP editions");

if cfg.auto_discover_istat && ...
        (strlength(string(cfg.edition)) == 0 || strlength(string(cfg.preliminary_ed)) == 0)
    try
        [cfg.edition, cfg.preliminary_ed, cfg.istat_metadata] = ITNOWDiscoverISTATEditions(cfg);
    catch ME
        ITNOWFailStep(2, 5, stepTimer);
        rethrow(ME)
    end
end

ITNOWDoneStep(2, 5, stepTimer);
fprintf("Using ISTAT GDP edition %s and preliminary edition %s.\n", ...
    cfg.edition, cfg.preliminary_ed);

stepTimer = ITNOWStartStep(3, 5, "Building data vintage");
try
    ITNOWRunGetData(cfg);
catch ME
    ITNOWFailStep(3, 5, stepTimer);
    rethrow(ME)
end
ITNOWDoneStep(3, 5, stepTimer);

vintage = string(datetime(cfg.run_date, "Format", "uuuuMMdd"));
stepTimer = ITNOWStartStep(4, 5, "Running historical nowcast models");
try
    ITNOWRunGetHistFcast(cfg, vintage, cfg.eval_end);
catch ME
    ITNOWFailStep(4, 5, stepTimer);
    rethrow(ME)
end
ITNOWDoneStep(4, 5, stepTimer);

scriptPath = fullfile(cfg.base_path, "scripts", "build_current_nowcast.py");
cmd = sprintf(['python3 "%s" --base-path "%s" --vintage "%s" ' ...
    '--eval-end "%s" --website-root "%s"'], ...
    scriptPath, cfg.base_path, vintage, string(cfg.eval_end), cfg.website_root);
if ~cfg.update_website
    cmd = cmd + " --no-update-website";
end

stepTimer = ITNOWStartStep(5, 5, "Building current nowcast artifacts");
[code, out] = system(cmd);
disp(out)
if code ~= 0
    ITNOWFailStep(5, 5, stepTimer);
    error("RunITNOWUpdate:ReportFailed", ...
        "Current nowcast report generation failed.");
end
ITNOWDoneStep(5, 5, stepTimer);

status = struct();
status.vintage = vintage;
status.eval_end = string(cfg.eval_end);
status.edition = cfg.edition;
status.preliminary_ed = cfg.preliminary_ed;
status.website_updated = cfg.update_website;

fprintf("\nITNOW update completed for vintage %s in %s.\n", ...
    vintage, ITNOWElapsed(runTimer));
fprintf("Website update: %s.\n", string(logical(cfg.update_website)));
end

function ITNOWPrintHeader(cfg)
fprintf("\n");
fprintf("============================================================\n");
fprintf(" ITNOW automated update\n");
fprintf("============================================================\n");
fprintf("Run date:        %s\n", string(cfg.run_date));
fprintf("Evaluation end:  %s\n", string(cfg.eval_end));
fprintf("Website update:  %s\n", string(logical(cfg.update_website)));
fprintf("Base path:       %s\n", string(cfg.base_path));
fprintf("------------------------------------------------------------\n");
end

function ITNOWRunGetData(cfg)
itnow_cfg = cfg; %#ok<NASGU>
run("GetData.m")
end

function ITNOWRunGetHistFcast(cfg, vintage, Eval_End)
itnow_cfg = cfg; %#ok<NASGU>
scriptInputs = {vintage, Eval_End}; %#ok<NASGU>
run("GetHistFcast.m")
end

function ITNOWPreflight(cfg)
if cfg.update_website
    ITNOWAssertWebsiteClean(cfg.website_root);
else
    fprintf("Website update disabled; skipping website checkout preflight.\n");
end
end

function ITNOWAssertWebsiteClean(websiteRoot)
websiteRoot = string(websiteRoot);
if strlength(websiteRoot) == 0
    error("RunITNOWUpdate:WebsiteRootMissing", ...
        "Website update is enabled but website_root is empty.");
end
if ~isfolder(websiteRoot)
    error("RunITNOWUpdate:WebsiteRootMissing", ...
        "Website checkout not found: %s", websiteRoot);
end
if ~isfolder(fullfile(websiteRoot, ".git"))
    fprintf("Website path is not a git checkout; dirty-check skipped: %s\n", websiteRoot);
    return
end

cmd = sprintf('git -C "%s" status --porcelain', websiteRoot);
[code, out] = system(cmd);
if code ~= 0
    error("RunITNOWUpdate:WebsiteStatusFailed", ...
        "Could not inspect website checkout status: %s", out);
end
if strlength(strtrim(string(out))) > 0
    error("RunITNOWUpdate:WebsiteDirty", ...
        "Website checkout has uncommitted changes. Commit, stash, or discard changes in %s before running with update_website=true.", ...
        websiteRoot);
end
fprintf("Website checkout is clean: %s\n", websiteRoot);
end

function timerValue = ITNOWStartStep(step, total, label)
timerValue = tic;
fprintf("\n%s [%d/%d] %s...\n", ITNOWProgressBar(step - 1, total), ...
    step, total, label);
end

function ITNOWDoneStep(step, total, timerValue)
fprintf("%s [%d/%d] Done in %s.\n", ITNOWProgressBar(step, total), ...
    step, total, ITNOWElapsed(timerValue));
end

function ITNOWFailStep(step, total, timerValue)
fprintf("%s [%d/%d] Failed after %s.\n", ITNOWProgressBar(step - 1, total), ...
    step, total, ITNOWElapsed(timerValue));
end

function bar = ITNOWProgressBar(step, total)
width = 24;
filled = floor(width * step / total);
bar = "[" + string(repmat('=', 1, filled)) + ...
    string(repmat('.', 1, width - filled)) + "]";
end

function elapsed = ITNOWElapsed(timerValue)
elapsed = string(duration(0, 0, toc(timerValue), "Format", "hh:mm:ss"));
end
