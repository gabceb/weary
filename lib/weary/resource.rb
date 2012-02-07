require 'addressable/template'

module Weary
  class Resource
    UnmetRequirementsError = Class.new(StandardError)

    def initialize(method, uri)
      @method = method
      @uri = Addressable::Template.new(uri)
    end

    def url(uri=nil)
      @uri = Addressable::Template.new(uri) unless uri.nil?
      @uri
    end

    def optional(*params)
      @optional = params unless params.empty?
      @optional ||= []
    end

    def required(*params)
      @required = params unless params.empty?
      @required ||= []
    end

    def defaults(hash=nil)
      @defaults = hash unless hash.nil?
      @defaults ||= {}
    end

    def headers(hash=nil)
      @headers = hash unless hash.nil?
      @headers ||= {}
    end

    def user_agent(agent)
      headers.update 'User-Agent' => agent
    end

    def basic_auth!(user = :username, pass = :password)
      @authenticates = true
      @credentials = [user, pass]
    end

    def authenticates?
      !!@authenticates
    end

    def expected_params
      optional.map(&:to_s) | required.map(&:to_s)
    end

    def expects?(param)
      expected_params.include? param.to_s
    end

    def requirements
      required.map(&:to_s) | url.keys
    end

    def meets_requirements?(params)
      requirements.reject {|k| params.keys.map(&:to_s).include? k.to_s }.empty?
    end

    def request(params={})
      params.update(defaults)
      raise UnmetRequirementsError, "Required parameters: #{requirements}" \
        unless meets_requirements? params
      credentials = pull_credentials params if authenticates?
      mapping = url.keys.map {|k| [k, params.delete(k) || params.delete(k.to_sym)] }
      request = Weary::Request.new url.expand(Hash[mapping]), @method do |r|
        r.headers headers
        if !expected_params.empty?
          r.params params.reject {|k,v| !expects? k }
        end
        r.basic_auth *credentials if authenticates?
      end
      yield request if block_given?
      request
    end
    alias build request


    private

    def pull_credentials(params)
      (@credentials || []).map do |credential|
        params.delete(credential) || params.delete(credential.to_s)
      end.compact
    end


  end
end