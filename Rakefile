require 'rake/testtask'
Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.options = '--pride'
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end
