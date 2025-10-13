function code
  if test "$argv" = "/"
    echo Hello root
    command code .
  else 
    command code $argv
  end
end
