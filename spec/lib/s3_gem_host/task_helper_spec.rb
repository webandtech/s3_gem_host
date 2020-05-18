# frozen_string_literal: true

require 'spec_helper'

RSpec.describe S3GemHost::TaskHelper do
  let(:aws_access_key_id) { 'access key id' }
  let(:aws_secret_access_key) { 'secret' }
  let(:bucket_name) { 'bucket name' }
  let(:aws_region) { 'aws region' }
  let(:instance) do
    described_class.new(
      aws_access_key_id: aws_access_key_id,
      aws_secret_access_key: aws_secret_access_key,
      aws_region: aws_region,
      bucket_name: bucket_name
    )
  end

  describe '#initialize' do
    it 'sets its attributes' do
      expect(instance.aws_access_key_id).to eq aws_access_key_id
      expect(instance.aws_secret_access_key).to eq aws_secret_access_key
      expect(instance.bucket_name).to eq bucket_name
      expect(instance.aws_region).to eq aws_region
    end
  end

  describe '.install' do
    describe 'defining tasks' do
      before do
        allow(described_class).to receive(:namespace).and_yield
        allow(described_class).to receive(:desc)
        allow(described_class).to receive(:task)
        described_class.install
      end

      it 'defines Rake task s3_gem_host:push' do
        expect(described_class).to have_received(:namespace).with(:s3_gem_host)
        expect(described_class).to have_received(:desc).with(
          'Publish a newly built gem version to S3. Run `rake build` first.'
        )
        expect(described_class).to have_received(:task).with(:push)
      end

      it 'defines Rake task s3_gem_host:yank' do
        expect(described_class).to have_received(:namespace).with(:s3_gem_host)
        expect(described_class).to have_received(:desc).with(
          'Remove a previously published gem version from S3'
        )
        expect(described_class).to have_received(:task).with(:yank, [:version])
      end
    end

    describe 'yielding tasks' do
      let(:instance) { instance_double(described_class) }
      let(:built_gem_file) { 'foo.gem' }
      let(:missing_env_error) do
        'S3_GEM_HOST_BUCKET, S3_GEM_HOST_AWS_ACCESS_KEY_ID, and S3_GEM_HOST_AWS_SECRET_ACCESS_KEY '\
        'are required to be set in ENV'
      end

      describe 's3_gem_host:push' do
        before do
          allow(described_class).to receive(:namespace).and_yield
          allow(described_class).to receive(:desc)
          allow(described_class).to receive(:task)
          allow(described_class).to receive(:task).with(:push).and_yield
          allow(ENV).to receive(:[]).with('S3_GEM_HOST_BUCKET').and_return bucket_name
          allow(ENV).to receive(:[]).with('S3_GEM_HOST_AWS_ACCESS_KEY_ID').and_return aws_access_key_id
          allow(ENV).to receive(:[]).with('S3_GEM_HOST_AWS_SECRET_ACCESS_KEY').and_return aws_secret_access_key
          allow(ENV).to receive(:[]).with('S3_GEM_HOST_AWS_REGION').and_return aws_region
          allow(described_class).to receive(:new).and_return instance
          allow(instance).to receive(:bootstrap_directories!)
          allow(instance).to receive(:clone_from_s3)
          allow(instance).to receive(:copy_in_gem)
          allow(instance).to receive(:create_index)
          allow(instance).to receive(:upload_to_s3)
          allow(instance).to receive(:cleanup!)
          allow(instance).to receive(:built_gem_file).and_return built_gem_file
          allow(described_class).to receive(:rake_output_message)
        end

        it 'executes task steps, in order' do
          described_class.install
          expect(described_class).to have_received(:new).with(
            aws_access_key_id: aws_access_key_id,
            aws_secret_access_key: aws_secret_access_key,
            bucket_name: bucket_name,
            aws_region: aws_region
          ).ordered
          expect(instance).to have_received(:bootstrap_directories!).ordered
          expect(instance).to have_received(:clone_from_s3).ordered
          expect(instance).to have_received(:copy_in_gem).ordered
          expect(instance).to have_received(:create_index).ordered
          expect(instance).to have_received(:upload_to_s3).ordered
          expect(instance).to have_received(:cleanup!).ordered
          expect(described_class).to have_received(:rake_output_message)
                                       .with("#{built_gem_file} pushed to S3 successfully.")
        end

        context 'missing S3_GEM_HOST_AWS_REGION' do
          let(:aws_region) { nil }

          it 'uses default region' do
            described_class.install
            expect(described_class).to have_received(:new).with(
              aws_access_key_id: aws_access_key_id,
              aws_secret_access_key: aws_secret_access_key,
              bucket_name: bucket_name,
              aws_region: 'us-east-1'
            ).ordered
          end
        end

        context 'missing bucket name' do
          let(:bucket_name) { nil }

          it 'raises error' do
            expect { described_class.install }.to raise_error missing_env_error
          end
        end

        context 'missing aws access key id' do
          let(:aws_access_key_id) { nil }

          it 'raises error' do
            expect { described_class.install }.to raise_error missing_env_error
          end
        end

        context 'missing aws secret access key' do
          let(:aws_secret_access_key) { nil }

          it 'raises error' do
            expect { described_class.install }.to raise_error missing_env_error
          end
        end
      end

      describe 's3_gem_host:yank' do
        let(:version) { '2.1.2' }

        before do
          allow(described_class).to receive(:namespace).and_yield
          allow(described_class).to receive(:desc)
          allow(described_class).to receive(:task)
          allow(described_class).to receive(:task).with(:yank, [:version]).and_yield('task', { version: version })
          allow(ENV).to receive(:[]).with('S3_GEM_HOST_BUCKET').and_return bucket_name
          allow(ENV).to receive(:[]).with('S3_GEM_HOST_AWS_ACCESS_KEY_ID').and_return aws_access_key_id
          allow(ENV).to receive(:[]).with('S3_GEM_HOST_AWS_SECRET_ACCESS_KEY').and_return aws_secret_access_key
          allow(ENV).to receive(:[]).with('S3_GEM_HOST_AWS_REGION').and_return aws_region
          allow(described_class).to receive(:new).and_return instance
          allow(instance).to receive(:bootstrap_directories!)
          allow(instance).to receive(:clone_from_s3)
          allow(instance).to receive(:delete_version!)
          allow(instance).to receive(:create_index)
          allow(instance).to receive(:upload_to_s3)
          allow(instance).to receive(:cleanup!)
          allow(described_class).to receive(:rake_output_message)
        end

        it 'executes task steps, in order' do
          described_class.install
          expect(described_class).to have_received(:new).with(
            aws_access_key_id: aws_access_key_id,
            aws_secret_access_key: aws_secret_access_key,
            bucket_name: bucket_name,
            aws_region: aws_region
          ).ordered
          expect(instance).to have_received(:bootstrap_directories!).ordered
          expect(instance).to have_received(:clone_from_s3).ordered
          expect(instance).to have_received(:delete_version!).with(version).ordered
          expect(instance).to have_received(:create_index).ordered
          expect(instance).to have_received(:upload_to_s3).ordered
          expect(instance).to have_received(:cleanup!).ordered
          expect(described_class).to have_received(:rake_output_message)
                                       .with("Yanked version #{version} from S3 successfully.")
        end

        context 'missing S3_GEM_HOST_AWS_REGION' do
          let(:aws_region) { nil }

          it 'uses default region' do
            described_class.install
            expect(described_class).to have_received(:new).with(
              aws_access_key_id: aws_access_key_id,
              aws_secret_access_key: aws_secret_access_key,
              bucket_name: bucket_name,
              aws_region: 'us-east-1'
            ).ordered
          end
        end

        context 'missing bucket name' do
          let(:bucket_name) { nil }

          it 'raises error' do
            expect { described_class.install }.to raise_error missing_env_error
          end
        end

        context 'missing aws access key id' do
          let(:aws_access_key_id) { nil }

          it 'raises error' do
            expect { described_class.install }.to raise_error missing_env_error
          end
        end

        context 'missing aws secret access key' do
          let(:aws_secret_access_key) { nil }

          it 'raises error' do
            expect { described_class.install }.to raise_error missing_env_error
          end
        end
      end
    end
  end

  describe 'bootstrap_directories!' do
    let(:gem_name) { 'the_gem' }

    before do
      allow(instance).to receive(:cleanup!)
      allow(instance).to receive(:rake_output_message)
      allow(instance).to receive(:mkdir)
      allow(instance).to receive(:gem_name).and_return gem_name
    end

    it 'cleans, then (re)creates directories' do
      expect(instance.bootstrap_directories!).to be true
      expect(instance).to have_received(:cleanup!).ordered
      expect(instance).to have_received(:mkdir).with('./s3_gem_host_cache').ordered
      expect(instance).to have_received(:mkdir).with("./s3_gem_host_cache/#{gem_name}").ordered
      expect(instance).to have_received(:mkdir).with("./s3_gem_host_cache/#{gem_name}/gems").ordered
    end
  end

  describe '#built_gem_file' do
    let(:file_exists) { true }
    let(:gem_name) { 'test_gem' }
    let(:gem_version) { '1.0.0' }
    let(:built_file) { './pkg/test_gem-1.0.0.gem' }

    before do
      allow(instance).to receive(:gem_name).and_return gem_name
      allow(instance).to receive(:gem_version).and_return gem_version
      allow(File).to receive(:exist?).with(built_file).and_return file_exists
    end

    it 'returns basename of gem file' do
      expect(instance.built_gem_file).to eq 'test_gem-1.0.0.gem'
      expect(instance.instance_variable_get(:@built_gem_file)).to eq 'test_gem-1.0.0.gem'
    end

    context 'file does not exist' do
      let(:file_exists) { false }

      it 'raises error' do
        expect { instance.built_gem_file }.to raise_error "Cannot find #{built_file}"
      end
    end

    context 'memoized' do
      before { instance.instance_variable_set(:@built_gem_file, 'foo') }

      it 'returns memoized' do
        expect(instance.built_gem_file).to eq 'foo'
      end
    end
  end

  describe 'clone_from_s3' do
    let(:bucket) { instance_double(Aws::S3::Bucket) }
    let(:existing_objects) { [base_dir_obj, gem_obj_1, gem_obj_2] }
    let(:base_dir_obj) { instance_double(Aws::S3::Object, key: 'gem_name/gems/') }
    let(:gem_obj_1) { instance_double(Aws::S3::Object, key: 'gem_name/gems/gem_name-1.0.0.gem') }
    let(:gem_obj_2) { instance_double(Aws::S3::Object, key: 'gem_name/gems/gem_name-2.0.0.gem') }
    let(:file_1_name) { './s3_gem_host_cache/gem_name/gems/gem_name-1.0.0.gem' }
    let(:file_2_name) { './s3_gem_host_cache/gem_name/gems/gem_name-2.0.0.gem' }
    let(:gem_name) { 'gem_name' }

    before do
      allow(instance).to receive(:bucket).and_return bucket
      allow(instance).to receive(:gem_name).and_return gem_name
      allow(bucket).to receive(:objects).with(prefix: 'gem_name/gems/', delimiter: '/').and_return existing_objects
      allow(gem_obj_1).to receive(:download_file)
      allow(gem_obj_2).to receive(:download_file)
    end

    it 'copies existing gem files from S3, returns true' do
      expect(instance.clone_from_s3).to be true
      expect(gem_obj_1).to have_received(:download_file).with(file_1_name)
      expect(gem_obj_2).to have_received(:download_file).with(file_2_name)
    end
  end

  describe '#copy_in_gem' do
    let(:duplicate_exists) { false }
    let(:gem_name) { 'test_gem' }
    let(:built_gem_file) { 'test_gem-1.0.0.gem' }
    let(:bucket_name) { 's3_bucket_name' }
    let(:duplicate_file_name) { './s3_gem_host_cache/test_gem/gems/test_gem-1.0.0.gem' }

    before do
      allow(instance).to receive(:gem_name).and_return gem_name
      allow(instance).to receive(:built_gem_file).and_return built_gem_file
      allow(instance).to receive(:cp)
      allow(File).to receive(:exist?).with(duplicate_file_name).and_return duplicate_exists
    end

    it 'returns true, copies built file to cache dir' do
      expect(instance.copy_in_gem).to be true
      expect(instance).to have_received(:cp)
                            .with("./pkg/#{built_gem_file}", './s3_gem_host_cache/test_gem/gems')
    end

    context 'file already exists in directory' do
      let(:duplicate_exists) { true }

      it 'raises error' do
        expect { instance.copy_in_gem }.to raise_error(
          'This gem version already exists in the S3 bucket: s3_bucket_name'
        )
      end
    end
  end

  describe '#delete_version!' do
    let(:bucket) { instance_double(Aws::S3::Bucket) }
    let(:file_obj) { instance_double(Aws::S3::Object) }
    let(:file_exists) { true }
    let(:version) { '2.1.2' }
    let(:gem_name) { 'test_gem' }
    let(:file_name) { './s3_gem_host_cache/test_gem/gems/test_gem-2.1.2.gem' }
    let(:s3_file_path) { 'test_gem/gems/test_gem-2.1.2.gem' }

    before do
      allow(File).to receive(:exist?).with(file_name).and_return file_exists
      allow(instance).to receive(:gem_name).and_return gem_name
      allow(instance).to receive(:rm_f)
      allow(instance).to receive(:bucket).and_return bucket
      allow(bucket).to receive(:object).with(s3_file_path).and_return file_obj
      allow(file_obj).to receive(:delete)
    end

    it 'deletes local file, deletes S3 file' do
      instance.delete_version!(version)
      expect(instance).to have_received(:rm_f).with(file_name)
      expect(file_obj).to have_received(:delete)
    end

    context 'file not found in cache dir' do
      let(:file_exists) { false }

      it 'raises error' do
        expect { instance.delete_version!(version) }.to raise_error "Gem #{File.basename(file_name)} could not be found"
      end
    end
  end

  describe '#create_index' do
    let(:gem_name) { 'test_gem' }

    before do
      allow(instance).to receive(:gem_name).and_return gem_name
      allow(instance).to receive(:sh)
    end

    it 'runs create_index gem command; returns true' do
      expect(instance.create_index).to be true
      expect(instance).to have_received(:sh).with('cd ./s3_gem_host_cache/test_gem && gem generate_index .')
    end
  end

  describe 'upload_to_s3' do
    let(:files_to_upload) { [file_name_1, file_name_2, file_name_3, file_name_4] }
    let(:file_name_1) { './s3_gem_host_cache/foo/bar.file' }
    let(:file_name_2) { './s3_gem_host_cache/bar' }
    let(:file_name_3) { './s3_gem_host_cache/another/gems/bar.gem' }
    let(:file_name_4) { './s3_gem_host_cache/another/gems/existing.gem' }
    let(:bucket) { instance_double(Aws::S3::Bucket) }
    let(:file_1_bucket_path) { 'foo/bar.file' }
    let(:file_3_bucket_path) { 'another/gems/bar.gem' }
    let(:file_4_bucket_path) { 'another/gems/existing.gem' }
    let(:file_1_s3_obj) { instance_double(Aws::S3::Object) }
    let(:file_3_s3_obj) { instance_double(Aws::S3::Object) }
    let(:file_4_s3_obj) { instance_double(Aws::S3::Object) }

    before do
      allow(instance).to receive(:bucket).and_return bucket
      allow(Dir).to receive(:[]).with('./s3_gem_host_cache/**/*').and_return files_to_upload
      allow(File).to receive(:directory?).with(file_name_1).and_return false
      allow(File).to receive(:directory?).with(file_name_2).and_return true
      allow(File).to receive(:directory?).with(file_name_3).and_return false
      allow(File).to receive(:directory?).with(file_name_4).and_return false
      allow(bucket).to receive(:object).with(file_1_bucket_path).and_return file_1_s3_obj
      allow(bucket).to receive(:object).with(file_3_bucket_path).and_return file_3_s3_obj
      allow(bucket).to receive(:object).with(file_4_bucket_path).and_return file_4_s3_obj
      allow(file_1_s3_obj).to receive(:upload_file)
      allow(file_1_s3_obj).to receive(:exists?).and_return true
      allow(file_3_s3_obj).to receive(:upload_file)
      allow(file_3_s3_obj).to receive(:exists?).and_return false
      allow(file_4_s3_obj).to receive(:upload_file)
      allow(file_4_s3_obj).to receive(:exists?).and_return true
    end

    it 'uploads only non-directory, non-existing gem files to s3; returns true' do
      expect(instance.upload_to_s3).to be true
      expect(file_1_s3_obj).to have_received(:upload_file).with(file_name_1)
      expect(file_3_s3_obj).to have_received(:upload_file).with(file_name_3)
      expect(file_4_s3_obj).not_to have_received(:upload_file)
    end
  end

  describe '#bucket' do
    let(:expected) { instance_double(Aws::S3::Bucket) }
    let(:resource) { instance_double(Aws::S3::Resource) }
    let(:credentials) { instance_double(Aws::Credentials) }

    before do
      allow(Aws::Credentials).to receive(:new).with(aws_access_key_id, aws_secret_access_key).and_return credentials
      allow(Aws::S3::Resource).to receive(:new).with(
        credentials: credentials,
        region: aws_region
      ).and_return resource
      allow(resource).to receive(:bucket).with(bucket_name).and_return expected
    end

    it 'returns S3 bucket from credentials resource; memoizes result' do
      expect(instance.bucket).to be expected
      expect(instance.instance_variable_get(:@bucket)).to be expected
    end

    context 'memoized' do
      before { instance.instance_variable_set(:@bucket, 'memoized') }

      it 'returns memoized' do
        expect(instance.bucket).to eq 'memoized'
      end
    end
  end

  describe '#gem_name' do
    let(:gemspec) { instance_double(Gem::Specification, name: 'test_gem') }

    before { allow(instance).to receive(:gemspec).and_return gemspec }

    it 'returns name from gemspec' do
      expect(instance.gem_name).to eq 'test_gem'
    end
  end

  describe '#gem_version' do
    let(:gemspec) { instance_double(Gem::Specification, version: '1.0.0') }

    before { allow(instance).to receive(:gemspec).and_return gemspec }

    it 'returns version from gemspec' do
      expect(instance.gem_version).to eq '1.0.0'
    end
  end

  describe '#gemspec' do
    let(:gemspecs) { [gemspec_file] }
    let(:gemspec_file) { 'foo.gemspec' }
    let(:gemspec) { instance_double(Gem::Specification) }

    before do
      allow(Dir).to receive(:[]).with('currentdir/{,*}.gemspec').and_return gemspecs
      allow(Dir).to receive(:getwd).and_return 'currentdir'
      allow(Bundler).to receive(:load_gemspec).with(gemspec_file).and_return gemspec
    end

    it 'returns gem name from gemspec; memoizes result' do
      expect(instance.gemspec).to be gemspec
      expect(instance.instance_variable_get(:@gemspec)).to be gemspec
    end

    context 'memoized' do
      before { instance.instance_variable_set(:@gemspec, 'memoized') }

      it 'returns memoized' do
        expect(instance.gemspec).to eq 'memoized'
      end
    end

    context 'no gemspecs found' do
      let(:gemspecs) { [] }

      it 'raises error' do
        expect { instance.gemspec }.to raise_error 'Unable to find gemspec'
      end
    end
  end

  describe '#cleanup!' do
    before { allow(instance).to receive(:rm_rf) }

    it 'returns true, deletes cache and package dirs' do
      expect(instance.cleanup!).to be true
      expect(instance).to have_received(:rm_rf).with('./s3_gem_host_cache')
    end
  end
end
