require 'test/unit'
require 'fileutils'
require 'yaml'

class Test::Unit::TestCase
  
  def self.key_to_sym(hash)
    hash.inject({}) do |h, p|
      if p[1].kind_of? Hash
        h[p[0].intern] = self.key_to_sym p[1]
      else
        h[p[0].intern] = p[1]
      end
      h
    end
  end
  
  def self.fixtures(name)
    dir = File.dirname(__FILE__) + '/fixtures'
    File.open(dir + '/' + name.to_s + '.yml') do |f|
      class_variable_set "@@#{name}", self.key_to_sym(YAML::load(f.read))
    end
  end
  
  protected
  
  def tmpdir
    File.expand_path(File.dirname(__FILE__) + '/tmp')
  end
  
  def create_tmpdir
    FileUtils.mkdir tmpdir
  end
  
  def remove_tmpdir
    FileUtils.rm_rf [tmpdir]
  end
end
