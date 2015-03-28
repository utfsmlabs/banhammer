require 'yaml'
require 'require_all'

Cuba.settings[:banhammer] = YAML.load_file 'config.yaml'
Cuba.use Rack::Session::EncryptedCookie,
    :secret => Cuba.settings[:banhammer]["Cookie-Key"],
    :key => 'banhammer'
Cuba.plugin Cuba::Safe

require_all 'src/**/*.rb'