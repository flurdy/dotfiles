function git-mobremove
  git solo
  git mob --uninstallTemplate
  rm .git/hooks/prepare-commit-msg
end
