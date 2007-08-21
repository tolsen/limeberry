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

# $URL$
# $Id$
require 'constants'

class Principal < Resource

  unless defined?(LIMEBERRY_UUID)
    LIMEBERRY_UUID = "95a44c3fb7694e67b7822236765a2fec"
    PRINCIPALS_COLLECTION_PATH = "/principals"
    LIMEORPHANAGE_NAME = "limeorphanage"
    LIMEORPHANAGE_DISPLAYNAME = "LimeOrphanage"
  end

  acts_as_proxy :for => :principal_record, :foreign_key => "resource_id"

  def self.principals_collection
    Bind.locate(PRINCIPALS_COLLECTION_PATH)
  end

  def self.principals_collection_path
    PRINCIPALS_COLLECTION_PATH
  end

  def self.limeberry
    @@limeberry = find_by_uuid( LIMEBERRY_UUID ) unless defined? @@limeberry
    @@limeberry.reload
  end

  def self.limeorphanage
    find_by_name(LIMEORPHANAGE_NAME)
  end

  # options: name (required)
  #          displayname
  #          quota (default 0)
  #          creator (defaults to limeberry)
  #          owner (defaults to principal being made)
  def self.make(options)
    transaction do
      resource_options = {
        :displayname => options[:displayname],
        :creator => options[:creator] || Principal.limeberry
      }
      resource_options[:owner] = options[:owner] if options[:owner]

      principal = create!(resource_options)
      PrincipalRecord.create!(:name => options[:name],
                              :total_quota => options[:quota] || 0,
                              :principal => principal)

      unless options[:owner]
        principal.owner = principal
        principal.save
      end
      principal
    end
  end

  def self.unauthenticated
    find_by_name("unauthenticated")
  end

  def after_proxied_create
    reload # to pick up the proxied object
    Principal.principals_collection.bind(self, self.name, Principal.limeberry)
  end

  def resourcetype(xml)
    xml.D(:resourcetype) { xml.D :principal }
  end

  def copy(target_pathname, options)
    raise MethodNotAllowedError
  end

  @liveprops = { PropKey.get('DAV:', 'principal-URL') => LiveProps::LivePropInfo.new(:principal_url, true, true) }.merge(superclass.liveprops).freeze

  def principal_url(xml)
    if self == Principal.unauthenticated
      xml.D(:unauthenticated)
    else
      xml.D(:href, File.join(PRINCIPALS_COLLECTION_PATH, self.name))
    end
  end


  def replenish_quota(amount)
    self.used_quota -= amount
  end

  def deplete_quota(amount)
    self.used_quota += amount
  end

  def getetag(xml)
    "#{uuid}-#{lock_version}-#{principal_record.lock_version}"
  end

end

%w(user group).each { |f| require_dependency f }
