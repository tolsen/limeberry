# Copyright (c) 2007 Lime Spot LLC

# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

module HttpMethodMaker

  module Functional
    def self.http_method_body(name)
      name.gsub!(/-/, '_')
      <<-EOV
        def #{name}(path, username = nil)
          @request.env['REQUEST_METHOD'] = "#{name.upcase}" if defined?(@request)
          path_a = path.split('/').reject { |n| n.blank? }
          process(:#{name}, { :path => path_a}, { :username => username })
        end
      EOV
    end
  end

  module Integration
    def self.http_method_body(name)
      name.gsub!(/-/, '_')
      <<-EOV
        def #{name}(path, parameters=nil, headers=nil)
          process(:#{name}, path, parameters, headers)
        end
      EOV
    end
  end

end

    
