require 'spec_helper'

require 'fluent/test'
require 'fluent/plugin/out_rackspace_cloud_feeds'


require 'webmock/rspec'
require 'rexml/document'
require 'json'


WebMock.disable_net_connect!

RSpec.describe('Rackspace Cloud Feeds output plugin') do

  FEED_URL = 'https://www.feed.com/the/best/feed'
  IDENTITY_URL = 'https://www.identity.com/authenticate/token'

  before :example do
    Fluent::Test.setup
    @driver = nil

    $log.out.logs
  end

  def driver(tag='test', conf='')
    @driver ||= Fluent::Test::OutputTestDriver.new(Fluent::RackspaceCloudFeedsOutput, tag).configure(conf)
  end

  def simple_sample_payload
    <<EOF
{ "GUID" : "87669264-3fc2-4e6e-b225-2f79f17d14c9", "ServiceCode" : "", "Region" : "", "DataCenter" : "", "Cluster" : "cluster", "Node" : "node", "RequestorIp" : "127.0.0.1", "Timestamp" : "1429546010984", "CadfTimestamp" : "2015-04-20T11:06:50.984-05:00", "Request" : { "Method" : "GET", "MethodLabel" : "", "CadfMethod" : "read/get", "URL" : "", "TargetHost" : "", "QueryString" : "", "Parameters" : {  }, "UserName" : "", "ImpersonatorName" : "", "DefaultProjectID" : "", "ProjectID" : [  ], "Roles" : [  ], "UserAgent" : "" }, "Response" : { "Code" : 200, "CadfOutcome" : "success", "Message" : "OK" } }
EOF
  end

  def encoded_payload
    {'message' => simple_sample_payload}
  end

  def less_simple_payload
    <<EOF
{ "GUID" : "9b2ac70c-16c9-493e-85be-d26a39319c2b", "ServiceCode" : "repose", "Region" : "USA", "DataCenter" : "DFW", "Timestamp" : "1429546468047", "Request" : { "Method" : "GET", "URL" : "http://localhost:10006/", "QueryString" : "", "Parameters" : {  }, "UserName" : "", "ImpersonatorName" : "", "ProjectID" : [  ], "Roles" : [  ], "UserAgent" : "deproxy 0.21" }, "Response" : { "Code" : 200, "Message" : "OK" }, "MethodLabel" : "" }
EOF
  end

  def stub_atom_post(content = "")
    stub_request(:post, FEED_URL).with do |request|
      assert_proper_atom_payload(request.body, content)
    end
  end

  def assert_proper_atom_payload(payload, content)
    doc = REXML::Document.new(payload)

    expect(REXML::XPath.first(doc, "/entry/id")).not_to be_nil
    title = REXML::XPath.first(doc, "/entry/title").text
    expect(title).to eq("User Access Event")

    expect(REXML::XPath.first(doc, "/entry/author/name").text).to eq("Repose")
    expect(REXML::XPath.first(doc, "/entry/updated").text).to match(/\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d.\d\d\dZ/)
    expect(REXML::XPath.first(doc, "/entry/content").text).to eq(content)
  end

  def print_logs
    $log.out.logs.each do |l|
      puts l
    end
  end

  def stub_identity_auth_post(token)
    stub_request(:post, IDENTITY_URL).with do |request|
      payload = JSON.parse(request.body)

      # NOTE: the header matching is case sensitive!
      payload['auth']['passwordCredentials']['username'] != nil and
          payload['auth']['passwordCredentials']['password'] != nil and
          request.headers['Content-Type'] == 'application/json' and
          request.headers['Accept'] == 'application/json'
    end.to_return do |request|
      {:body => {'access' => {'token' => {'id' => token}}}.to_json}
    end
  end


  context 'a record from fluentd to cloud feeds' do

    it "should register as rackspace_cloud_feeds" do
      driver.configure("feeds_endpoint #{FEED_URL}")
      expect($log.out.logs).to include(/.*registered output plugin 'rackspace_cloud_feeds'.*/)
    end

    it "authenticates with identity and posts a payload to feeds" do
      driver.configure(<<EOF
identity_endpoint #{IDENTITY_URL}
identity_username fakeuser
identity_password best_password
feeds_endpoint #{FEED_URL}
EOF
      )
      driver.run

      token = SecureRandom.uuid.to_s

      stub_identity_auth_post(token)
      stub_atom_post(simple_sample_payload)

      driver.emit(encoded_payload)

      expect(a_request(:post, IDENTITY_URL).with do |req|
               parsed = JSON.parse(req.body)
               parsed['auth']['passwordCredentials']['username'] == 'fakeuser' and
                   parsed['auth']['passwordCredentials']['password'] == 'best_password'
             end).to have_been_made.once

      expect(a_request(:post, FEED_URL).with do |req|
               req.headers['X-Auth-Token'] == token
             end).to have_been_made.once
    end

    it "will fail the post if the response is 4xx clearing the auth token" do
      driver.configure(<<EOF
identity_endpoint #{IDENTITY_URL}
identity_username fakeuser
identity_password best_password
feeds_endpoint #{FEED_URL}
EOF
      )
      driver.run

      token = "FIRST TOKEN"
      stub_identity_auth_post(token)

      stub_atom_post(simple_sample_payload)
      driver.emit(encoded_payload)


      expect(a_request(:post, FEED_URL).with do |req|
               req.headers['X-Auth-Token'] == token
             end).to have_been_made.once


      #set up feeds with a 403 failure
      stub_request(:post, FEED_URL).with do |request|
        assert_proper_atom_payload(request.body, simple_sample_payload)
      end.to_return do |req|
        {:status => 403}
      end

      new_token = "SECOND TOKEN"

      # simulate behavior from the bufferize plugin, which will retry the call eventually
      expect {
        driver.emit(encoded_payload)
      }.to raise_exception(/NOT AUTHORIZED TO POST TO FEED ENDPOINT.+/)

      #expect another request to identity
      stub_identity_auth_post(new_token)
      stub_atom_post(simple_sample_payload)

      #simulate the thing being called again
      driver.emit(encoded_payload)

      expect(a_request(:post, IDENTITY_URL).with do |req|
               parsed = JSON.parse(req.body)
               parsed['auth']['passwordCredentials']['username'] == 'fakeuser' and
                   parsed['auth']['passwordCredentials']['password'] == 'best_password'
             end).to have_been_made.twice

      expect(a_request(:post, FEED_URL).with do |req|
               req.headers['X-Auth-Token'] == new_token
             end).to have_been_made.once

    end

    it "raises an exception if unable to authenticate with identity" do
      driver.configure(<<EOF
identity_endpoint #{IDENTITY_URL}
identity_username fakeuser
identity_password best_password
feeds_endpoint #{FEED_URL}
EOF
      )
      driver.run

      stub_request(:post, IDENTITY_URL).with do |request|
        payload = JSON.parse(request.body)

        # NOTE: the header matching is case sensitive!
        payload['auth']['passwordCredentials']['username'] != nil and
            payload['auth']['passwordCredentials']['password'] != nil and
            request.headers['Content-Type'] == 'application/json' and
            request.headers['Accept'] == 'application/json'
      end.to_return do |request|
        {:status => 400}
      end

      expect {
        driver.emit(encoded_payload)
      }.to raise_exception(/Unable to authenticate with identity at.+/)

      expect(WebMock).not_to have_requested(:post, FEED_URL)
    end

    it "should publish the event using the time given when it entered fluentd" do
      driver.configure(<<EOF
identity_endpoint #{IDENTITY_URL}
identity_username fakeuser
identity_password best_password
feeds_endpoint #{FEED_URL}
EOF
      )
      driver.run

      token = "loltoken"
      #stub an identity
      stub_identity_auth_post(token)

      # just a basic stub for the post to feeds
      stub_request(:post, FEED_URL)


      current_time = Time.now - 10000


      driver.emit(encoded_payload, current_time)

      expect(a_request(:post, FEED_URL).with do |req|
               doc = REXML::Document.new(req.body)

               updated = REXML::XPath.first(doc, "/entry/updated").text
               expected_time = DateTime.strptime(current_time.to_i.to_s, '%s').strftime("%FT%T.%LZ")
               updated == expected_time
             end).to have_been_made.once

    end
  end
end