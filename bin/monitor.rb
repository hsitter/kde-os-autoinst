#!/usr/bin/env ruby

# Inifinity loop of a super simple gui app to display the last screenshot and
# refresh it every second. Useful to watch local runs.

loop do
  system 'feh', '-R', '1', "#{__dir__}/../wok/qemuscreenshot/last.png"
end
