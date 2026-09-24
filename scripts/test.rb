Dir[File.expand_path("../test/**/*_test.rb", __dir__)].sort.each { |file| require file }
