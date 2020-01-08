function trimfishuserpaths 
   set -U fish_user_paths $argv (string match -v $argv $fish_usern_paths)
end
