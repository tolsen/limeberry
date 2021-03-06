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

require 'test/test_helper'
require 'test/unit/dav_unit_test'

class IfHeaderParserTest < DavUnitTestCase

  def test_cond_new
    cond = IfHeaderParser::Cond.new(:state_token, '<locktoken:a-write-lock-token>')

    assert cond.lock_token?
    assert_equal('<locktoken:a-write-lock-token>', cond.value)
    assert(!cond.negated)
  end

  def test_cond_new_negated
    cond = IfHeaderParser::Cond.new(:entity_tag, '["I am an ETag"]', true)
    assert !cond.lock_token?
    assert_equal('["I am an ETag"]', cond.value)
    assert(cond.negated)
  end

  def test_cond_negate
    cond = IfHeaderParser::Cond.new(:state_token, '<locktoken:write1>')
    cond.negated = true
    assert(cond.negated)
  end
  
end


