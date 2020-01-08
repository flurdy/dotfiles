function trimfishpaths 
   set -U fish_function_path $argv (string match -v $argv $fish_function_path)
end
