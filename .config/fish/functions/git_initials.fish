function git_initials --description 'Print the initials for who I am currently pairing with'
  set -lx initials (git mob-print --initials)
  if test -n "$initials"
    printf ' [%s]' $initials
  end
end
