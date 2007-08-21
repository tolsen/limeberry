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

require 'digest/md5'

class User < Principal

  acts_as_proxy :for => :user_record, :foreign_key => "principal_id"

  unless defined?(USERS_COLLECTION_PATH)
    USERS_COLLECTION_PATH = "/users"
    HOME_COLLECTION_PATH = "/home"
    DEFAULT_QUOTA = 1.gigabyte
  end

  def self.users_collection_path
    "/users"
  end

  def self.users_collection
    Bind.locate(USERS_COLLECTION_PATH)
  end

  def self.home_collection
    Bind.locate(HOME_COLLECTION_PATH)
  end

  def home_collection
    Bind.locate(home_collection_path)
  end

  def home_collection_path
    File.join(HOME_COLLECTION_PATH, self.name)
  end

  def before_destroy
    super
    home = home_collection
    home.destroy if home.empty?
  end

  def after_proxied_create
    super
    User.users_collection.bind(self, name, Principal.limeberry)
    Group.authenticated.add_member(self)

    # Creating home-folder for user.
    Collection.mkcol_p(home_collection_path, Principal.limeberry)
    home_collection.owner = self
    Privilege.priv_all.grant(home_collection, self, true)

    # Granting Write+Read+Read-acl privilege to self
    # We don't want users to be able to change the acl
    Privilege.priv_write.grant(self, self, true)
    Privilege.priv_read.grant(self, self, true)
    Privilege.priv_read_acl.grant(self, self, true)
  end

  # options: name (required)
  #          password (required)
  #          displayname
  #          quota (defaults to DEFAULT_QUOTA)
  def self.make(options)
    raise BadRequestError unless (options.has_key?(:name) && options.has_key?(:password))
    self.transaction do
      user = create!(:displayname => options[:displayname])
      PrincipalRecord.create!(:name => options[:name],
                              :total_quota => options[:quota] ||
                              DEFAULT_QUOTA,
                              :principal => user)
      UserRecord.create!(:pwhash =>
                         digest_auth_hash(options[:name],
                                          options[:password]),
                         :user => user)
      user.owner = user
      user.reload
    end
  end

  # PUT User (create or modify user)
  def self.put(options)
    user = find_by_name(options[:name])
    if user.nil?
      make(options)
      response = DavResponse::PutWebdavResponse.new Status::HTTP_STATUS_CREATED
      return response
    end

    self.transaction do
      user.displayname=options[:displayname] if !options[:displayname].nil?
      user.password=options[:password] if !options[:password].nil?
      user.save!
      response=DavResponse::PutWebdavResponse.new Status::HTTP_STATUS_NO_CONTENT
      return response
    end
  end

  # reading the password gives empty string
  def password
    ""
  end

  def password= password
    self.pwhash = User.digest_auth_hash(self.name, password)
  end


  def password_matches? password
    pwhash == User.digest_auth_hash(name, password)
  end

  # Authenticate the user, returning the User object on success, or false on
  # failure.
  #
  # Example:
  #   @user = User.authenticate(params[:username], params[:password])
  def self.authenticate(username, password)
    user = find_by_name(username)

    return false if user.nil?
    return false unless user.password_matches?(password)
    user
  end

  def self.digest_auth_hash name, password
    # for compatibility with HTTP Digest Auth (RFC 2617),
    # pwhash is MD5 of <name>:users@limedav.com:<password>

    # example: timmay:users@limedav.com:swordfish
    # the md5sum is: 6ff09aed096e324fb2686aef620fe009

    Digest::MD5.hexdigest("#{name}:#{AppConfig.authentication_realm}:#{password}")
  end

  def principal_url(xml)
    xml.D(:href, File.join(USERS_COLLECTION_PATH, self.name))
  end

  def getetag(xml)
    super + "-#{lock_version}"
  end
  
end


