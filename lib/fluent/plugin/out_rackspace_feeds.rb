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

class Fluent::RackspaceCloudFeedsOutput < Fluent::Output
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

  def emit(tag, es, chain)
    chain.next
    es.each {|time, record|
      # take the data, put it in to an abdera envelope
    }
  end

end