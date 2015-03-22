require 'yaml'
require 'require_all'

Cuba.settings[:banhammer] = YAML.load_file 'config.yaml'


require_all 'src/**/*.rb'