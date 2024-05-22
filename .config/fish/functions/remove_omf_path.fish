function remove_omf_path

   set fish_function_path_size (count $fish_function_path)

	echo Fish function path contains $fish_function_path_size paths

	set new_function_path
	set owf_function_path
	set slice_size 5000
	set slice_min (math $slice_size + 2)

	if test $fish_function_path_size -lt $slice_min
		set partial_path $fish_function_path
		set rest_path
   else 
	   set partial_path $fish_function_path[1..$slice_size]
	   set rest_path $fish_function_path[$slice_size..-1]
   end

	for path in $partial_path
      if string match -q "$OMF_PATH*" "$path"
    	  if not contains $path $owf_function_path
		    set owf_function_path $owf_function_path $path
		  end
		else
	      set new_function_path $new_function_path $path
		end
	end

	set -g fish_function_path $new_function_path $owf_function_path $rest_path
	set -U fish_function_path $new_function_path $owf_function_path $rest_path

end
