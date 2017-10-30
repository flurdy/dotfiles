function appendpath 
	contains -- $argv $fish_user_paths
      or set -U fish_user_paths $fish_user_paths $argv
end

