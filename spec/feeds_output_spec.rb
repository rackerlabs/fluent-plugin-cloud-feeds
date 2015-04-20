require 'fluent/test'
require 'fluent/plugin/out_rackspace_feeds'

require 'webmock/rspec'


WebMock.disable_net_connect!

RSpec.describe('Rackspace Cloud Feeds output plugin') do

  before :example do
    Fluent::Test.setup
    @driver = nil
  end

  def driver(tag='test', conf='')
    @driver ||= Fluent::Test::OutputTestDriver.new(Fluent::RackspaceCloudFeedsOutput, tag).configure(conf)
  end

  def simple_sample_payload
    <<EOF
{ "GUID" : "87669264-3fc2-4e6e-b225-2f79f17d14c9", "ServiceCode" : "", "Region" : "", "DataCenter" : "", "Cluster" : "cluster", "Node" : "node", "RequestorIp" : "127.0.0.1", "Timestamp" : "1429546010984", "CadfTimestamp" : "2015-04-20T11:06:50.984-05:00", "Request" : { "Method" : "GET", "MethodLabel" : "", "CadfMethod" : "read/get", "URL" : "", "TargetHost" : "", "QueryString" : "", "Parameters" : {  }, "UserName" : "", "ImpersonatorName" : "", "DefaultProjectID" : "", "ProjectID" : [  ], "Roles" : [  ], "UserAgent" : "" }, "Response" : { "Code" : 200, "CadfOutcome" : "success", "Message" : "OK" } }
EOF
  end

  def less_simple_payload
    <<EOF
{ "GUID" : "9b2ac70c-16c9-493e-85be-d26a39319c2b", "ServiceCode" : "repose", "Region" : "USA", "DataCenter" : "DFW", "Timestamp" : "1429546468047", "Request" : { "Method" : "GET", "URL" : "http://localhost:10006/", "QueryString" : "", "Parameters" : {  }, "UserName" : "", "ImpersonatorName" : "", "ProjectID" : [  ], "Roles" : [  ], "UserAgent" : "deproxy 0.21" }, "Response" : { "Code" : 200, "Message" : "OK" }, "MethodLabel" : "" }
EOF
  end

  def stub_feeds(url="http://www.feeds.com")
    stub_request(:post, url).with do |req|
      puts "request is:"
      puts req
    end
  end

  context 'a record from fluentd to cloud feeds' do
    it "outputs a record to cloud feeds as an atom post" do
      driver.configure("feeds_endpoint http://www.feeds.com")

      driver.emit(simple_sample_payload)
      driver.run
      assert_requested(stub_feeds)
    end
    it "authenticates with identity to use the token in the header"
    it "will fail the post if the response is 4xx clearing the auth token"
    it "retries authentication if no auth token is set"
  end
end