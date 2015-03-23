function fish_prompt --description 'Write out the prompt'
	set -l last_status $status


  # User
  set_color $fish_color_user
  echo -n (whoami)
  set_color normal

  echo -n '@'

  # Host
  set_color $fish_color_host
  echo -n (hostname -s)
  set_color normal

  echo -n ':'

  # PWD
  set_color $fish_color_cwd
  set folder_name (pwd | sed -e "s|^$HOME|~|" -e "s|~/Dropbox|/dbox|")
  set folder_length (echo $folder_name | awk ' { print length } ')
  if test "$folder_length" -lt 60
	 echo -n "$folder_name"
  else if test "$folder_length" -lt 80
    echo -n (echo "$folder_name" | sed -e "s-\([^/][^/][^/][^/][^/][^/]\)[^/]*/-\1/-g")
  else if test "$folder_length" -lt 100
    echo -n (echo "$folder_name" | sed -e "s-\([^/][^/][^/][^/][^/]\)[^/]*/-\1/-g")
  else if test "$folder_length" -lt 120
    echo -n (echo "$folder_name" | sed -e "s-\([^/][^/][^/][^/]\)[^/]*/-\1/-g")
  else
    echo -n (echo "$folder_name" | sed -e "s-\([^/][^/][^/]\)[^/]*/-\1/-g")
  end
#  echo -n (prompt_pwd)

  set_color normal

  __terlar_git_prompt
  echo

  if not test $last_status -eq 0
    set_color $fish_color_error
  end

  # Time	
  set_color normal
  printf (date "+$c2%H$c0:$c2%M$c0-")

  if test $CMD_DURATION
    set_color $fish_color_error
	 echo -n $CMD_DURATION
  end

  echo -n '➤ '
  set_color normal
end
