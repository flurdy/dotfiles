function prependfunctionpath 
	contains -- $argv $fish_function_path
      or set -U fish_function_path $argv $fish_function_path
end

