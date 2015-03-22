require 'cuba'
require 'cuba/render'
require 'haml'
require 'tilt/haml'
require 'data_mapper'
require 'net/ldap'
require 'reform'
require 'reform/form'
require 'token_phrase'

Cuba.plugin Cuba::Render

Cuba.settings[:render][:template_engine] = 'haml'
Cuba.settings[:production] = false #Make true when is in production

use Rack::Static, :urls => ['/static/']

Reform::Form.reform_2_0!


require './app'

run(Cuba)