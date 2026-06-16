function status = DeployITNOWWebsite(varargin)
%DeployITNOWWebsite Stage website artifacts from existing ITNOW outputs.
%
% This does not run GetData.m or GetHistFcast.m.
%
% Examples:
%   setup_itnow; DeployITNOWWebsite
%   setup_itnow; DeployITNOWWebsite("vintage", "20260509")

setup_itnow("quiet", true)
cfg = ITNOWConfig(varargin{:});

if isfield(cfg, "vintage") && strlength(string(cfg.vintage)) > 0
    vintage = string(cfg.vintage);
else
    vintage = ITNOWLatestPredictionVintage(cfg.base_path);
end

fprintf("\n");
fprintf("============================================================\n");
fprintf(" ITNOW website staging from existing outputs\n");
fprintf("============================================================\n");
fprintf("Vintage:         %s\n", vintage);
fprintf("Evaluation end:  %s\n", string(cfg.eval_end));
fprintf("Website root:    %s\n", string(cfg.website_root));
fprintf("------------------------------------------------------------\n");

ITNOWAssertWebsiteCleanForDeploy(cfg.website_root);
ITNOWAssertExistingOutputs(cfg.base_path, vintage);

scriptPath = fullfile(cfg.base_path, "scripts", "build_current_nowcast.py");
cmd = sprintf(['python3 "%s" --base-path "%s" --vintage "%s" ' ...
    '--eval-end "%s" --website-root "%s"'], ...
    scriptPath, cfg.base_path, vintage, string(cfg.eval_end), cfg.website_root);

[code, out] = system(cmd);
disp(out)
if code ~= 0
    error("DeployITNOWWebsite:ReportFailed", ...
        "Website staging from existing outputs failed.");
end

status = struct();
status.vintage = vintage;
status.eval_end = string(cfg.eval_end);
status.website_root = string(cfg.website_root);

fprintf("Website artifacts staged from vintage %s.\n", vintage);
end

function ITNOWAssertExistingOutputs(basePath, vintage)
prediction = fullfile(basePath, "HISTORY", "PREDICTION", vintage + "_fcasts_covid.csv");
gdp = fullfile(basePath, "DATA", "GDP_History", "GDP" + vintage + ".csv");
missing = strings(0, 1);
if ~isfile(prediction)
    missing(end + 1) = prediction;
end
if ~isfile(gdp)
    missing(end + 1) = gdp;
end
if ~isempty(missing)
    error("DeployITNOWWebsite:MissingOutputs", ...
        "Cannot stage website because required existing outputs are missing:\n%s", ...
        strjoin(missing, newline));
end
end

function ITNOWAssertWebsiteCleanForDeploy(websiteRoot)
websiteRoot = string(websiteRoot);
if strlength(websiteRoot) == 0
    error("DeployITNOWWebsite:WebsiteRootMissing", ...
        "website_root is empty.");
end
if ~isfolder(websiteRoot)
    error("DeployITNOWWebsite:WebsiteRootMissing", ...
        "Website checkout not found: %s", websiteRoot);
end
if ~isfolder(fullfile(websiteRoot, ".git"))
    fprintf("Website path is not a git checkout; dirty-check skipped: %s\n", websiteRoot);
    return
end

cmd = sprintf('git -C "%s" status --porcelain', websiteRoot);
[code, out] = system(cmd);
if code ~= 0
    error("DeployITNOWWebsite:WebsiteStatusFailed", ...
        "Could not inspect website checkout status: %s", out);
end
if strlength(strtrim(string(out))) > 0
    error("DeployITNOWWebsite:WebsiteDirty", ...
        "Website checkout has uncommitted changes. Commit, stash, or discard changes in %s before staging ITNOW website files.", ...
        websiteRoot);
end
fprintf("Website checkout is clean: %s\n", websiteRoot);
end
