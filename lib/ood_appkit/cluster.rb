require 'yaml'

module OodAppkit
  # An object that describes a given cluster of nodes used by an HPC center
  class Cluster
    # YAML configuration version
    VERSION = :v1

    # Title of the cluster
    # @return [String] title of cluster
    attr_reader :title

    # Hash of validators this cluster validates against
    # @return [Hash<#valid?>] hash of validators
    attr_reader :validators

    # Hash of servers this cluster supports
    # @return [Hash<Server>] hash of servers
    attr_reader :servers

    # A list of accessible clusters for the currently running user
    # @param file [String] yaml file with cluster configurations
    # @param force [Boolean] whether we force invalid clusters to be included as well
    # @return [Hash<Cluster>] list of clusters user has access to
    def self.all(file: File.expand_path('../../../config/clusters.yml', __FILE__), force: false)
      parse_config(file).each_with_object({}) do |(k, v), h|
        c = Cluster.new v
        h[k] = c if c.valid? || force
      end
    end

    # @param title [String] title of cluster
    # @param validators [Hash] hash of validations that describe the validators
    # @param servers [Hash] hash of servers with corresponding server info
    # @param hpc_cluster [Boolean] whether this is an hpc-style cluster
    def initialize(title:, validators: {}, servers: {}, hpc_cluster: true)
      # Set title of cluster
      @title = title

      # Generate hash of validations
      @validators = validators.each_with_object({}) do |(k, v), h|
        h[k] = v[:type].constantize.new(v)
      end

      # Generate hash of servers
      @servers = servers.each_with_object({}) do |(k, v), h|
        h[k] = v[:type].constantize.new(v)
      end

      # Is this an hpc-style cluster?
      @hpc_cluster = hpc_cluster
    end

    # Whether this is a valid cluster
    # @example Whether I have access to this cluster
    #   my_cluster.valid?
    #   #=> true
    # @return [Boolean] whether user has access to this cluster
    def valid?
      !@validators.any? {|name, validator| !validator.valid?}
    end

    # Whether this is an hpc-style cluster (i.e., meant for heavy computation)
    # @return [Boolean] whether this an hpc-style cluster
    def hpc_cluster?
      @hpc_cluster
    end

    # Grab object from {@servers} hash or check if it exists
    # @param method_name the method name called
    # @param arguments the arguments to the call
    # @param block an optional block for the call
    def method_missing(method_name, *arguments, &block)
      if /^(.+)_server$/ =~ method_name.to_s
        @servers.fetch($1.to_sym, nil)
      elsif /^(.+)_server\?$/ =~ method_name.to_s
        @servers.has_key? $1.to_sym
      else
        super
      end
    end

    # Check if method ends with custom *_server or *_server?
    # @param method_name the method name to check
    # @return [Boolean]
    def respond_to_missing?(method_name, include_private = false)
      method_name.to_s.end_with?('_server', '_server?') || super
    end

    private
      # Parse the config file
      def self.parse_config(file)
        YAML.load(File.read(file)).deep_symbolize_keys.fetch(VERSION, {})
      end
  end
end
