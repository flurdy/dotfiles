function removefishpaths 
   set -U fish_function_path (string match -v $argv $fish_function_path)
end
