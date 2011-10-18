require 'bundler/setup'
require 'minitest/autorun'
require 'rack/test'
require 'thin/async/test'
require './lib/meerkat'

describe 'Meerkat' do
  include Rack::Test::Methods

  def app
    Meerkat.backend = Meerkat::Backend::InMemory.new
    Rack::Builder.new {
      map "/" do
        meerkat = Meerkat::RackAdapter.new do |m|
          m.keep_alive = 0.1
        end

        run Thin::Async::Test.new(meerkat)
      end
    }.to_app
  end

  it 'should return status 200 and content-type text/event-stream' do
    get '/'
    assert_equal 200, last_response.status
    assert_equal 'text/event-stream', last_response.headers['Content-Type']
  end

  it 'first return a retry value' do
    get '/'
    assert_equal "retry: 3000\n", last_response.body.lines.first
  end
  it 'should periodically emit a comment to keep alive the connection' do
    get '/'
    assert_equal ":", last_response.body.split("\n")[1]
  end
  
  it 'should publish messages' do
    get '/'
    Meerkat.publish('/', 'foo')
    assert_equal "foo", last_response.body.split("\n")[2]
  end
end