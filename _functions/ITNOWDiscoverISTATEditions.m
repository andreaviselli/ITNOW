function [edition, preliminaryEd, metadata] = ITNOWDiscoverISTATEditions(cfg)
%ITNOWDiscoverISTATEditions Select newest working final and preliminary editions.

if nargin == 0 || isempty(cfg)
    cfg = ITNOWConfig();
end

if isfield(cfg, "istat_probe_timeout")
    probeTimeout = cfg.istat_probe_timeout;
else
    probeTimeout = cfg.web_timeout;
end
options = weboptions("Timeout", probeTimeout);
candidates = ITNOWCandidateEditions(cfg.run_date, cfg.istat_lookback_months);

edition = "";
preliminaryEd = "";
metadata = struct();
metadata.candidates = candidates;
metadata.final = [];
metadata.preliminary = [];
metadata.final_failures = repmat(struct("edition", "", "message", ""), numel(candidates), 1);
metadata.preliminary_failures = repmat(struct("edition", "", "message", ""), numel(candidates), 1);

fprintf("ISTAT probe timeout: %d seconds per candidate.\n", probeTimeout);
fprintf("Candidate editions: %s.\n", strjoin(candidates, ", "));

for i = 1:numel(candidates)
    fprintf("  Final GDP [%d/%d]: probing %s... ", i, numel(candidates), candidates(i));
    [ok, info] = ITNOWProbeISTATEdition("final", candidates(i), ...
        "1990-01-01", options);
    if ok
        edition = candidates(i);
        metadata.final = info;
        fprintf("ok, latest observation %s.\n", info.latest_observation);
        break
    end
    metadata.final_failures(i).edition = candidates(i);
    metadata.final_failures(i).message = info.message;
    fprintf("not available (%s).\n", ITNOWShortMessage(info.message));
end

if strlength(edition) == 0
    lastMessage = ITNOWLastFailureMessage(metadata.final_failures);
    error("ITNOWDiscoverISTATEditions:FinalNotFound", ...
        "No usable ISTAT final GDP edition found through the SDMX endpoint. Last failure: %s\nIf the IstatData web UI shows the edition, this is likely an API/network/IP issue. Bypass discovery with: RunITNOWUpdate('update_website', false, 'edition', '2026M5', 'preliminary_ed', '2026M4')", ...
        lastMessage);
end

for i = 1:numel(candidates)
    fprintf("  Preliminary GDP [%d/%d]: probing %s... ", i, numel(candidates), candidates(i));
    [ok, info] = ITNOWProbeISTATEdition("preliminary", candidates(i), ...
        "1990-01-01", options);
    if ok
        preliminaryEd = candidates(i);
        metadata.preliminary = info;
        fprintf("ok, latest observation %s.\n", info.latest_observation);
        break
    end
    metadata.preliminary_failures(i).edition = candidates(i);
    metadata.preliminary_failures(i).message = info.message;
    fprintf("not available (%s).\n", ITNOWShortMessage(info.message));
end
if strlength(preliminaryEd) == 0
    lastMessage = ITNOWLastFailureMessage(metadata.preliminary_failures);
    error("ITNOWDiscoverISTATEditions:PreliminaryNotFound", ...
        "No usable ISTAT preliminary GDP edition found through the SDMX endpoint. Last failure: %s\nIf the IstatData web UI shows the edition, this is likely an API/network/IP issue. Bypass discovery with: RunITNOWUpdate('update_website', false, 'edition', '%s', 'preliminary_ed', '2026M4')", ...
        lastMessage, edition);
end
end

function msg = ITNOWShortMessage(message)
msg = replace(string(message), newline, " ");
msg = strip(msg);
if strlength(msg) == 0
    msg = "no diagnostic";
end
maxLength = 120;
if strlength(msg) > maxLength
    msg = extractBefore(msg, maxLength) + "...";
end
end

function msg = ITNOWLastFailureMessage(failures)
for i = numel(failures):-1:1
    if strlength(string(failures(i).message)) > 0
        msg = ITNOWShortMessage(failures(i).message);
        return
    end
end
msg = "no diagnostic";
end
