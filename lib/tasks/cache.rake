# -*- rake -*-

namespace :cache do
  desc "Clears custom cache directories."
  task :clear do
    FileUtils.rm(Dir['tmp/cache/[^.]*/[^.]*'])
  end

  desc "Removes custom cache directories."
  task :remove do
    FileUtils.rm_rf(Dir['tmp/cache/[^.]*'])
  end

  desc "Creates custom cache directories."
  task :create do
    FileUtils.mkdir_p(%w( tmp/cache/thumb ))
  end
end
