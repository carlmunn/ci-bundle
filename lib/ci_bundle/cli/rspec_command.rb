module CiBundle::Cli
  class RspecCommand < BaseCommand
    def run

      files = @opts[:file].join(' ')

      dep_file = "deprecations.log"

      cmds = [].tap do |ary|
        # Because each command is going to be run separately we'll 
        # need to make sure we are in the correct dir.
        cd_path = _path ? "cd #{_path}" : nil
        
        ary.concat([*pre_run_commands(prefix: cd_path)])
        
        rspec_cmd = ["bundle exec rspec #{files} --deprecation-out #{dep_file} --format j"].tap do |ary|
          ary.insert(0, "#{cd_path}") if cd_path
        end.join(';')
        
        ary.concat([rspec_cmd])
      end

      _log("ALL CMDS: #{cmds.join(", ")}")

      results = cmds.map do |cmd|
        run_command(cmd)
      end
      
      # Want the last as it's the rspec JSON results
      stdout_result = results.last
      
      begin  

        _log("RESULT: #{stdout_result.inspect}")

        #write_to_file(result, postfix: 'before-before')

        json_result = get_json(stdout_result)

        # Get the last line
        #write_to_file(json_result)

        # Convert JSON to a ruby hash
        hash_result = parse(json_result, input_type: :json)

        check_for_failure(hash_result)

      rescue => exp
        # Write JSON to FS for analyse
        #write_to_file(stdout_result)
        raise exp
      end

      hash_result
    end

    private
    def check_for_failure(result)
      if has_failure?(result)
        notify(failure_email_hash(result), by: :email)
      else
        notify(success_email_hash, by: :email)
      end
    end

    # RSpec, when using --format j it won't return JSON as the last line if an
    # exception occurs.
    def get_json(result)
      #result.split("\n").select {|str| str.match(/^{version/) }.first
      result.split("\n").last
    end

    def failure_email_hash(body_hash)
      {
        subject:   email_subject("🔥 Test Results: #{body_hash['summary_line']}"),
        body_hash: body_hash
      }
    end

    def success_email_hash
      {
        subject:   email_subject("✔ All tests passed")
      }
    end

    def email_subject(subject)
      [].tap do |ary|
        ary << "[#{@opts[:namespace]}]" if @opts[:namespace]
        ary <<subject
      end.join(" ")
    end

    def has_failure?(result)
      result['examples'].any? {|example| example['status'] == 'failed' }
    end

    def _log(msg)
      CiBundle::Cli.log(msg)
    end

    def write_to_file(result, postfix: 'results')
      timestamp = Time.now.strftime("%Y%m%d_%H-%M-%S")
      File.open("test-report-#{timestamp}.#{postfix}", 'w') {|file| file.write(result) }
    end
  end
end
