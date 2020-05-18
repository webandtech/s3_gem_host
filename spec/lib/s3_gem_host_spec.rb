# frozen_string_literal: true

require 'spec_helper'

RSpec.describe S3GemHost do
  it 'has the correct version' do
    expect(described_class::VERSION).to eq '1.0.0'
  end
end
