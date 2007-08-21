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

#@ns

#implements the redirect resource model, refer: http://greenbytes.de/tech/webdav/draft-ietf-webdav-redirectref-protocol-latest.html
#target could be of 2 types: Absolute/Relative
#for target syntax refer URI syntax http://www.ietf.org/rfc/rfc3986.txt

class RedirectRecord < ActiveRecord::Base

  set_table_name "redirects"
  set_primary_key "resource_id"
  belongs_to :resource


  validates_presence_of :target
  #rest_of_url is everything after the target in the request
  #parent_url is everything before the target in the request(makes sense only for relative targets)
  attr_reader :rest_of_url,:parent_url
  attr_writer :rest_of_url,:parent_url


  protected
  def validate
    errors.add(:lifetime,"should be either 'T' or 'P'") unless (lifetime=='T' || lifetime=='P' || lifetime.nil?)
  end


  #returns the target + the following inner links
  def get_target

    @parent_url  ||= ""
    @rest_of_url ||= ""

    if (absolute_target? || relative_target? || @parent_url == "")
      target + ((@rest_of_url == "")?(""):("/" + @rest_of_url))
    else #must be a relative reference to the current directory
      (@parent_url + "/" + target) +
        ((@rest_of_url == "")?(""):("/" + @rest_of_url))
    end
  end


  def permanent?
    lifetime == 'P'
  end

  #returns the header depending on whether the redirect is temporary or
  #permanent
  def get_header
    if permanent?
      "301 Moved Permanently"
    else
      "302 Moved Temporarily"
    end
  end

  #updates a redirect ref.
  #Args:resource_id,lifetime,target
  def self.update args
    self.transaction do
      redirect = find(args[:resource_id])
      #no update if lifetime/target is null
      redirect.lifetime = args[:lifetime] unless (args[:lifetime].nil? || args[:lifetime] == "")
      redirect.target = args[:target] unless (args[:target].nil? || args [:target] == "")
      redirect.save!
      redirect
    end
  end


  #Args: corresponding resource object , lifetime,target
  #  def self.make_old args
  #    self.transaction do
  #      resource = args[:resource]

  #      redirect_args = Hash.new

  #      redirect_args[:lifetime] = args[:lifetime].nil?? 'T' : args[:lifetime]
  #      redirect_args[:target] = args[:target]

  #      redirect = Redirect.new(redirect_args)
  #      resource.redirect = redirect
  #      resource.save!
  #      redirect.save!
  #      redirect
  #    end
  #  end

  #Args: resource object params, principal: user that is creating the redirect, lifetime,target
  def self.make args
    self.transaction do
      principal = args[:principal]

      #first the resource fields
      resource_args = Utility.retrieve_params(args,:resource)
      resource_args[:type_name] = "Redirect"

      #if the redirect name is invalid fail with status code 415
      if(!Utility.valid_file_name? resource_args[:displayname])
        raise BadRequestError
      end

      #create the resource object. => not needed done in make_redirect at resource

      resource = Resource.make(resource_args)

      #now the redirect fields
      #default lifetime is 'T'
      redirect_args = Hash.new
      redirect_args[:lifetime] = args[:lifetime].nil?? 'T' : args[:lifetime]
      redirect_args[:target] = args[:target]

      redirect = Redirect.new(redirect_args)
      resource.redirect = redirect
      resource.save!
      redirect.save!
      redirect

    end
  end

  #methods which find the target type.
  #Checks if there is a match with an absolute URI syntax
  def absolute_target?
    !target.match(/\A[A-Za-z]*:\/\/*/).nil?
  end

  #begins with /, relative to the root.
  def relative_target?
    target[0,1] == "/"
  end

  #if not absolute or relative to root.
  def relative_to_current_target?
    if (!absolute_target?) && (!relative_target?)
      true
    else
      false
    end
  end

end
