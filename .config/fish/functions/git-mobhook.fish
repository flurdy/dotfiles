function git-mobhook
  wget https://raw.githubusercontent.com/findmypast-oss/git-mob/master/hook-examples/prepare-commit-msg-nodejs
  mv prepare-commit-msg-nodejs .git/hooks/prepare-commit-msg
  chmod +x .git/hooks/prepare-commit-msg
end
