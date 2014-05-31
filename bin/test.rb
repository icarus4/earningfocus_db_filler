prj_root = File.expand_path('../../', __FILE__)
array = IO.readlines("#{prj_root}/tmp/test").map(&:chomp)

puts array