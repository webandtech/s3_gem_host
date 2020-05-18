# frozen_string_literal: true

require 'rake'

module S3GemHost
  # Service used for S3 Gem Host rake tasks
  class TaskHelper
    include Rake::DSL
    extend Rake::DSL

    attr_accessor :aws_access_key_id, :aws_secret_access_key, :bucket_name, :aws_region

    CACHE_DIR = './s3_gem_host_cache'
    PACKAGE_DIR = './pkg'

    def initialize(aws_access_key_id:, aws_secret_access_key:, bucket_name:, aws_region:)
      self.aws_access_key_id = aws_access_key_id
      self.aws_secret_access_key = aws_secret_access_key
      self.bucket_name = bucket_name
      self.aws_region = aws_region
    end

    # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/BlockLength
    def self.install
      namespace :s3_gem_host do
        desc 'Publish a newly built gem version to S3. Run `rake build` first.'
        task :push do
          unless ENV['S3_GEM_HOST_BUCKET'] && ENV['S3_GEM_HOST_AWS_ACCESS_KEY_ID'] &&
              ENV['S3_GEM_HOST_AWS_SECRET_ACCESS_KEY']
            raise 'S3_GEM_HOST_BUCKET, S3_GEM_HOST_AWS_ACCESS_KEY_ID, and S3_GEM_HOST_AWS_SECRET_ACCESS_KEY '\
        'are required to be set in ENV'
          end

          helper = S3GemHost::TaskHelper.new(
            aws_access_key_id: ENV['S3_GEM_HOST_AWS_ACCESS_KEY_ID'],
            aws_secret_access_key: ENV['S3_GEM_HOST_AWS_SECRET_ACCESS_KEY'],
            bucket_name: ENV['S3_GEM_HOST_BUCKET'],
            aws_region: ENV['S3_GEM_HOST_AWS_REGION'] || 'us-east-1'
          )

          begin
            helper.bootstrap_directories!
            helper.clone_from_s3
            helper.copy_in_gem
            helper.create_index
            helper.upload_to_s3
          ensure
            helper.cleanup!
          end

          rake_output_message "#{helper.built_gem_file} pushed to S3 successfully."
        end

        desc 'Remove a previously published gem version from S3'
        task :yank, [:version] do |_t, args|
          raise ArgumentError, 'version is required' unless (version = args[:version])

          unless ENV['S3_GEM_HOST_BUCKET'] && ENV['S3_GEM_HOST_AWS_ACCESS_KEY_ID'] &&
              ENV['S3_GEM_HOST_AWS_SECRET_ACCESS_KEY']
            raise 'S3_GEM_HOST_BUCKET, S3_GEM_HOST_AWS_ACCESS_KEY_ID, and S3_GEM_HOST_AWS_SECRET_ACCESS_KEY '\
        'are required to be set in ENV'
          end

          helper = S3GemHost::TaskHelper.new(
            aws_access_key_id: ENV['S3_GEM_HOST_AWS_ACCESS_KEY_ID'],
            aws_secret_access_key: ENV['S3_GEM_HOST_AWS_SECRET_ACCESS_KEY'],
            bucket_name: ENV['S3_GEM_HOST_BUCKET'],
            aws_region: ENV['S3_GEM_HOST_AWS_REGION'] || 'us-east-1'
          )

          begin
            helper.bootstrap_directories!
            helper.clone_from_s3
            helper.delete_version!(version)
            helper.create_index
            helper.upload_to_s3
          ensure
            helper.cleanup!
          end

          rake_output_message "Yanked version #{version} from S3 successfully."
        end
      end
    end
    # rubocop:enable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/BlockLength

    def bootstrap_directories!
      cleanup!

      mkdir CACHE_DIR
      rake_output_message "created #{CACHE_DIR}"

      gem_base_dir = "#{CACHE_DIR}/#{gem_name}"
      mkdir gem_base_dir
      rake_output_message "created #{gem_base_dir}"

      gems_dir = "#{CACHE_DIR}/#{gem_name}/gems"
      mkdir gems_dir
      rake_output_message "created #{gems_dir}"

      true
    end

    def built_gem_file
      return @built_gem_file if @built_gem_file

      built_gem_file = File.join('./pkg', "#{gem_name}-#{gem_version}.gem")
      raise "Cannot find #{built_gem_file}" unless File.exist?(built_gem_file)

      @built_gem_file = File.basename(built_gem_file)
    end

    def clone_from_s3
      prefix = "#{gem_name}/gems/"
      bucket.objects(prefix: prefix, delimiter: '/').each do |s3_obj|
        next if s3_obj.key == prefix # skip the directory S3 object itself

        new_file = File.join(CACHE_DIR, s3_obj.key)
        s3_obj.download_file(new_file)
        rake_output_message "copied #{s3_obj.key} to #{new_file}"
      end

      true
    end

    def copy_in_gem
      # If the same gem file / version already exists in S3, stop release
      if File.exist?("#{CACHE_DIR}/#{gem_name}/gems/#{built_gem_file}")
        raise "This gem version already exists in the S3 bucket: #{self.bucket_name}"
      end

      # Copy the built gem into the s3 cache dir
      cp "./pkg/#{built_gem_file}", "#{CACHE_DIR}/#{gem_name}/gems"
      rake_output_message "copied #{built_gem_file} to #{CACHE_DIR}/#{gem_name}/gems"

      true
    end

    def delete_version!(version)
      file = "#{CACHE_DIR}/#{gem_name}/gems/#{gem_name}-#{version}.gem"
      raise "Gem #{File.basename(file)} could not be found" unless File.exist?(file)

      rm_f file
      obj = bucket.object(file.sub(%r{^#{CACHE_DIR}/}, ''))
      obj.delete

      true
    end

    def create_index
      sh "cd #{CACHE_DIR}/#{gem_name} && gem generate_index ."
      rake_output_message 'created gem version index'

      true
    end

    def upload_to_s3
      # Sync the local cache dir up to S3
      files_to_upload = Dir["#{CACHE_DIR}/**/*"]
      files_to_upload.each do |f|
        next if File.directory?(f)

        obj = bucket.object(f.sub(%r{^#{CACHE_DIR}/}, ''))

        # Don't re-upload existing gem versions
        next if File.extname(f) == '.gem' && obj.exists?

        obj.upload_file(f)
        rake_output_message "uploaded #{f} to S3"
      end

      true
    end

    def bucket
      @bucket ||= Aws::S3::Resource.new(
        credentials: Aws::Credentials.new(self.aws_access_key_id, self.aws_secret_access_key),
        region: self.aws_region
      ).bucket(self.bucket_name)
    end

    def gem_name
      gemspec.name
    end

    def gem_version
      gemspec.version
    end

    def cleanup!
      rm_rf(CACHE_DIR)
      rake_output_message "deleted #{CACHE_DIR}"

      true
    end

    def gemspec
      return @gemspec if @gemspec

      gemspecs = Dir[File.join(Dir.getwd, '{,*}.gemspec')]
      raise 'Unable to find gemspec' unless gemspecs.any?

      @gemspec = Bundler.load_gemspec(gemspecs.first)
    end
  end
end
