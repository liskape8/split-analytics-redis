require "split/helper"

module Split
  module Analytics
    def tracking_code(options={})
      # needs more options: http://code.google.com/apis/analytics/docs/gaJS/gaJSApi.html
      account = options.delete(:account)
      tracker_url = options.delete(:tracker_url)
      ssl_tracker_url = options.delete(:ssl_tracker_url)
      tracker_methods = options.delete(:tracker_methods)

      tracker_url = 'http://' + (tracker_url || 'www.google-analytics.com/ga.js')
      ssl_tracker_url = 'https://' + (ssl_tracker_url || 'ssl.google-analytics.com/ga.js')

      code = <<-EOF
        <script type="text/javascript">
          var _gaq = _gaq || [];
          _gaq.push(['_setAccount', '#{account}']);
          #{insert_tracker_methods(tracker_methods)}
          #{custom_variables}
          _gaq.push(['_trackPageview']);
          (function() {
            var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
            ga.src = ('https:' == document.location.protocol ? '#{ssl_tracker_url}' : '#{tracker_url}');
            var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
          })();
        </script>
      EOF
      code = raw(code)if defined?(raw)
      code
    end

    def custom_variables
      custom_variables_from_redis
    end

    private

      def custom_variables_from_redis
        arr = []
        default_indexes = (1..5).to_a
        # experiment with custom var: [name]_ga_var[index]

        ExperimentCatalog.all.select{ |e| not e.has_winner? }.each do |experiment|
          alternative = ab_user[experiment.key]

          if experiment.key.match(/.*_ga_var(.)/).present?
            index = experiment.key.match(/.*_ga_var(.)/).captures.first.to_i
          else
            index = default_indexes.shift
          end

          arr << "_gaq.push(['_setCustomVar', #{index}, '#{experiment.key}', '#{alternative}', 1]);"
        end
        arr.join("\n")
      end

      def insert_tracker_methods(tracker_methods)
        return nil if tracker_methods.nil?
        arr = []
        tracker_methods.each do |k,v|
          if v.class == String && v.empty?
            # No argument tracker method
            arr << "_gaq.push(['" + "_" + "#{k}']);"
          else
            case v
            when String
              # String argument tracker method
              arr << "_gaq.push(['" + "_" + "#{k}', '#{v}']);"
            when TrueClass
              # Boolean argument tracker method
              arr << "_gaq.push(['" + "_" + "#{k}', #{v}]);"
            when FalseClass
              # Boolean argument tracker method
              arr << "_gaq.push(['" + "_" + "#{k}', #{v}]);"
            when Array
              # Array argument tracker method
              values = v.map { |value| "'#{value}'" }.join(', ')
              arr << "_gaq.push(['" + "_" + "#{k}', #{values}]);"
            end
          end
        end
        arr.join("\n")
      end
  end
end

module Split::Helper
  include Split::Analytics
end

if defined?(Rails)
  class ActionController::Base
    ActionController::Base.send :include, Split::Analytics
    ActionController::Base.helper Split::Analytics
  end
end