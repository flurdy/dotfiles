function git-mobremove
  git solo
  git --uninstallTemplate
  rm .git/hooks/prepare-commit-msg
end
