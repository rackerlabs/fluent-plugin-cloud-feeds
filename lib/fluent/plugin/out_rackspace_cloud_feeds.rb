=begin

  Copyright (C) 2015 Rackspace

  Licensed to the Apache Software Foundation (ASF) under one
  or more contributor license agreements.  See the NOTICE file
  distributed with this work for additional information
  regarding copyright ownership.  The ASF licenses this file
  to you under the Apache License, Version 2.0 (the
  "License"); you may not use this file except in compliance
  with the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an
  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  KIND, either express or implied.  See the License for the
  specific language governing permissions and limitations
  under the License.
=end

require 'date'

class Fluent::RackspaceCloudFeedsOutput < Fluent::Output
  include Fluent::PluginLoggerMixin

  Fluent::Plugin.register_output('rackspace_cloud_feeds', self)

  config_param :identity_endpoint, :string, :default => nil
  config_param :identity_username, :string, :default => nil
  config_param :identity_password, :string, :default => nil

  config_param :feeds_endpoint, :string, :default => nil


  def configure(conf)
    super
    $log.debug("   Identity endpoint: #{@identity_endpoint}")
    $log.debug("   Identity username: #{@identity_username}")
    $log.debug("Cloud Feeds endpoint: #{@feeds_endpoint}")
  end

  def start
    super
    require 'net/http/persistent'

    @feeds_uri = URI @feeds_endpoint
    @feeds_http = Net::HTTP::Persistent.new 'fluent-feeds-output'

  end

  def shutdown
    super
  end

  ##
  # either get a token back from identity, or poop the pants
  # noinspection RubyStringKeysInHashInspection
  def authenticate_user
    uri = URI @identity_endpoint
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
    end
    req = Net::HTTP::Post.new(uri.path)
    content = {
        'auth' => {
            'passwordCredentials' => {
                'username' => @identity_username,
                'password' => @identity_password
            }
        }
    }
    req.body = content.to_json
    req['content-type'] = 'application/json'
    req['accept'] = 'application/json'
    res = http.request(req)

    case res
      when Net::HTTPSuccess
        # Get the token
        JSON.parse(res.body)['access']['token']['id']
      else
        raise "Unable to authenticate with identity at #{@identity_endpoint} as #{@identity_username}"
    end
  end

  ##
  # putting content into an atom entry document
  def atomic_wrapper(content, time)
    # date format
    now = DateTime.strptime(time.to_s, '%s').strftime("%FT%T.%LZ")

    <<EOF
<?xml version="1.0" encoding="UTF-8" ?>
<entry xmlns="http://www.w3.org/2005/Atom">
    <id>#{SecureRandom.uuid.to_s}</id>
    <title type="text">User Access Event</title>
    <author><name>Repose</name></author>
    <updated>#{now}</updated>
    <content type="application/xml">#{content}</content>
</entry>
EOF
  end


  def emit(tag, es, chain)
    es.each { |time, record|
      http = Net::HTTP.new(@feeds_uri.host, @feeds_uri.port)
      if @feeds_uri.scheme == 'https'
        http.use_ssl = true
      end

      # take the data, put it in to an abdera envelope
      post = Net::HTTP::Post.new @feeds_uri.path

      post.body = atomic_wrapper(record['message'], time)
      unless @auth_token
        #get new auth token
        @auth_token = authenticate_user
      end
      post['x-auth-token'] = @auth_token
      post['content-type'] = 'application/atom+xml'

      begin
        response = http.request(post)

        if response.code !~ /2\d\d/
          @auth_token = nil
          raise "NOT AUTHORIZED TO POST TO FEED ENDPOINT #{@feeds_endpoint}"
        end
        $log.debug "FEEDS RESPONSE CODE #{response.code}"
        $log.error "FEEDS RESPONSE BODY: #{response.body}" if response.code !~ /2\d\d/
      end
    }

    chain.next
  end

end
