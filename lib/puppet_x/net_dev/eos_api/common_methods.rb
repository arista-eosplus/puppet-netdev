# encoding: utf-8

module PuppetX
  module NetDev
    ##
    class EosApi
      ##
      # CommonMethods implements common methods, such as returning the running
      # config.  This separation makes it easier to provide documentation and
      # introspect where methods come from given an api instance.
      module CommonMethods
        ##
        #
        # @api private
        #
        # @return [String] the text of the running configuration
        def running_config
          prefix = %w(enable)
          cmd = 'show running-config'
          msg = 'show running configuration'
          result = eapi_action([*prefix, cmd], msg, format: 'text')
          result.last['output']
        end
      end
    end
  end
end
