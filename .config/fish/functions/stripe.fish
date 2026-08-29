function stripe 
  command docker run --rm -it -v ~/.config/stripe:/root/.config/stripe stripe/stripe-cli $argv
end
