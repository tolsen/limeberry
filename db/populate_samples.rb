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

require 'config/environment'

limeberry = Principal.limeberry
dir = Collection.mkcol_p("/dir", limeberry)

src = Resource.create!(:displayname => 'this is my displayname')
dir.bind_and_set_acl_parent(src, 'src', limeberry)
Body.make('text/plain', src, 'content')

src.properties.create!(:xml => '<N:randomname1 xmlns:N="randomns1">randomvalue1</N:randomname1>')
src.properties.create!(:xml => '<N:randomname2 xmlns:N="randomns2">randomvalue2</N:randomname2>')

joe = User.make(:name => 'joe', :password => 'joe')

Collection.mkcol_p("/dir1", limeberry)
dir2 = Collection.mkcol_p("/dir2", limeberry)
Collection.mkcol_p("/dir2/dir3", limeberry)

res = Resource.create!(:displayname => "res")
dir2.bind_and_set_acl_parent(res, "res", limeberry)

# for bind unit tests
bindroot = Collection.mkcol_p("/bind", limeberry)
Collection.mkcol_p("/bind/a", limeberry)
r = Resource.create!(:displayname => 'r')
bindroot.bind(r, 'r', limeberry)
j = Collection.mkcol_p("/bind/j", limeberry)
j.bind bindroot, 'bind', limeberry

# for bind functional tests
bindroot2 = Collection.mkcol_p("/bind2", limeberry)
a = Collection.mkcol_p("/bind2/a", limeberry)
r = Resource.create!(:displayname => 'r')
bindroot2.bind(r, 'r', limeberry)
b = Resource.create!(:displayname => 'b')
a.bind(b, 'b', limeberry)


# for body tests
def put_new(parent, name, content, creator = Principal.limeberry)
  res = Resource.create!(:displayname => name, :creator => creator)
  parent.bind_and_set_acl_parent(res, name, creator)
  Body.make("text/plain", res, content)
  res
end

bodyroot = Collection.mkcol_p("/body", limeberry)
r = Resource.create!(:displayname => 'r')

put_new(bodyroot, 'r', 'hello world')
put_new(bodyroot, 'from', 'abc')
put_new(bodyroot, 'to', 'abcd')

Group.make(:name => 'alpha', :displayname => 'alpha',
           :creator => limeberry, :owner => joe)

Lock.create!(:lock_root => '/locknull',
             :owner => limeberry,
             :scope => 'X',
             :depth => 'I',
             :expires_at => Time.gm(2030))

# for lock tests

lockrootdir = Collection.mkcol_p("/lock", limeberry)

a = Resource.create!(:displayname => 'a')
lockrootdir.bind(a, 'a', limeberry)

owner_info = "<href>http://dav.limedav.com/principals/limeberry</href>"
lock_a = Lock.create!( :owner => limeberry,
                       :scope => 'X',
                       :depth => '0',
                       :expires_at => Time.gm(2030),
                       :owner_info => owner_info,
                       :lock_root => '/lock/a' )

b = Resource.create!(:displayname => 'b')
lockrootdir.bind(b, 'b', limeberry)

lock_b = Lock.create!( :owner => limeberry,
                       :scope => 'X',
                       :depth => '0',
                       :expires_at => Time.gm(2030),
                       :lock_root => '/lock/b' )


c = Collection.mkcol_p('/lock/c', limeberry)

put_new(lockrootdir, 'd', 'd content')

z = Resource.create!(:displayname => 'z')
c.bind(z, 'z', limeberry)

e = Collection.mkcol_p('/lock/e', limeberry)
f = Resource.create!(:displayname => 'f')
e.bind(f, 'f', limeberry)
g = Collection.mkcol_p('/lock/e/g', limeberry)
h = Resource.create!(:displayname => 'h')
g.bind(h, 'h', limeberry)
i = Resource.create!(:displayname => 'i')
e.bind(i, 'i', limeberry)


Principal.make(:name => "principal",
               :displayname => "principal")

# for property tests
proproot = Collection.mkcol_p '/prop', limeberry
resource = put_new(proproot, 'test', 'test')

resource.properties.create!(:xml => '<N:testprop xmlns:N="http://example.org/namespaces/test">testvalue</N:testprop>')

bob = Principal.make(:name => 'bob', :displayname => 'bob',
                     :quota => 5)
Privilege.priv_bind.grant proproot, bob
put_new(proproot, 'bobs', '', bob)

# for deltav-related tests
deltavroot = Collection.mkcol_p '/deltav', limeberry

put_new deltavroot, 'res', 'res'
put_new deltavroot, 'vcr', 'vcr'
Resource.version_control '/deltav/vcr', limeberry

put_new deltavroot, 'vcr2', 'vcr2'
Resource.version_control '/deltav/vcr2', limeberry
vcr2 = Bind.locate '/deltav/vcr2'
vcr2.checkout limeberry
Body.make('text/plain', vcr2, 'randomcontent')
vcr2.properties.create!(:xml => '<N:name xmlns:N="ns">value</N:name>')
vcr2.checkin limeberry

Privilege.priv_bind.grant deltavroot, joe
vcr3 = put_new deltavroot, 'vcr3', 'vcr3', joe
vcr3.properties.create!(:xml => '<N:name xmlns:N="ns">value</N:name>')
joe.reload
Resource.version_control '/deltav/vcr3', joe

ren = User.make(:name => 'ren', :password => 'ren')
stimpy = User.make(:name => 'stimpy', :password => 'stimpy')

# for http controller tests
Collection.mkcol_p '/http', limeberry

# for webdav controller tests
webdavroot = Collection.mkcol_p '/webdav', limeberry
foo = put_new webdavroot, 'foo', 'test'
foo.properties.create!(:xml => '<N:randomname1 xmlns:N="randomns1">randomvalue1</N:randomname1>')
foo.properties.create!(:xml => '<N:randomname2 xmlns:N="randomns2">randomvalue2</N:randomname2>')

dir1 = Collection.mkcol_p '/webdav/dir1', limeberry
dir2 = Collection.mkcol_p '/webdav/dir1/dir2', limeberry
bar = put_new dir2, 'bar', 'barcontent'

dir3 = Collection.mkcol_p '/webdav/dir3', limeberry

[[dir1, 1], [dir2, 3], [bar, 5], [dir3, 7]].each do |r, m|
  [m, m+1].each do |n|
    r.properties.create!(:xml => "<N:prop#{n} xmlns:N=\"ns#{n}\">value#{n}</N:prop#{n}>")
  end
end

a, b, c = %w( a b c ).map do |name|
  col = Collection.mkcol_p "/webdav/dir3/#{name}", limeberry
  [1, 2].each do |n|
    p = "#{name}#{n}"
    col.properties.create!(:xml => "<N:prop#{p} xmlns:N=\"ns#{p}\">value#{p}</N:prop#{p}>")
  end
  col
end


{ a => %w( d e f ),
  b => %w( g h i ),
  c => %w( j k l ) }.each do |dir, files|
  files.each do |file|
    r = put_new dir, file, "#{file}_content"
    [1, 2].each do |n|
      p = "#{file}#{n}"
      r.properties.create!(:xml => "<N:prop#{p} xmlns:N=\"ns#{p}\">value#{p}</N:prop#{p}>")
    end
  end
end

# for acl controller tests

aclroot = Collection.mkcol_p '/acl', limeberry
Privilege.priv_all.grant aclroot, ren
put_new aclroot, 'res', 'res', ren
dir = Collection.mkcol_p '/acl/dir', ren
Privilege.priv_all.grant dir, stimpy
put_new dir, 'inherits', 'inherits', stimpy
disowned = Resource.create :displayname => 'disowned', :creator => stimpy
dir.bind disowned, 'disowned', stimpy  # acl parent *not* set

# for http_lock integration tests
httplockroot = Collection.mkcol_p '/httplock', limeberry
Privilege.priv_all.grant httplockroot, ren
put_new httplockroot, 'a', 'a', ren

owner_info = "<href>http://dav.limedav.com/principals/ren</href>"
Lock.create!( :owner => ren,
              :scope => 'X',
              :depth => '0',
              :expires_at => Time.gm(2030),
              :owner_info => owner_info,
              :lock_root => '/httplock/a' )

put_new httplockroot, 'b', 'b', ren

Collection.mkcol_p '/httplock/hr/recruiting/resumes', ren
Collection.mkcol_p '/httplock/hr/archives', ren
