require 'fluent/test'
require 'fluent/plugin/out_rackspace_feeds'

RSpec.describe('Rackspace Cloud Feeds output plugin') do
  context 'a record from fluentd to cloud feeds' do
    it "outputs a record to cloud feeds as an atom post"
    it "authenticates with identity to use the token in the header"
    it "will fail the post if the response is 4xx clearing the auth token"
    it "retries authentication if no auth token is set"
  end
end