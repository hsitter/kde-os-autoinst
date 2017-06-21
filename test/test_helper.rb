require 'json'

begin
  require 'simplecov'
  SimpleCov.start do
    formatter SimpleCov::Formatter::MultiFormatter[SimpleCov::Formatter::HTMLFormatter]
  end
rescue LoadError
  warn 'not gathering coverage'
end

require 'minitest/autorun'
