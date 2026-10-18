function quoted = shell_quote(args)
%SHELL_QUOTE Protect POSIX shell arguments, including spaces and apostrophes.
quoted = "'" + replace(string(args),"'","'""'""'") + "'";
end
