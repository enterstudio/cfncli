require 'cfncli/cloudformation'
require 'active_support/hash_with_indifferent_access'

describe CfnCli::CloudFormation do
  subject(:cfn) do
    cfn = CfnCli::CloudFormation.new
    cfn.stub_responses = true
    cfn
  end

  describe '#create_or_update_stack' do
    let(:opts) { Hash.new }
    subject { cfn.create_or_update_stack(opts) }

    let(:stack) { double CfnCli::Stack }

    before do
      expect(cfn).to receive(:create_stack_obj).and_return(stack)
      allow(stack).to receive(:exists?).and_return(exists)
    end

    context 'when the stack does not exist' do
      let(:exists) { false }
      it 'is expected to call stack.create' do
        expect(stack).to receive(:create).with(opts)
        subject
      end
    end

    context 'when the stack exists' do
      let(:exists) { true }
      it 'is expected to call stack.update' do
        expect(stack).to receive(:update).with(opts)
        subject
      end
      context 'and the opts contain create only options' do
        let(:opts) { { 'stack_name' => 'test', 'on_failure' => 'DELETE' } }
        it 'strips out options that are only supported on create' do
          expect(stack).to receive(:update).with('stack_name' => 'test')
          subject
        end
      end
    end
  end

  describe '#delete_stack' do
    subject { cfn.delete_stack('stack_name', {}) }

    let(:stack) { double CfnCli::Stack }

    before do
      allow(cfn).to receive(:create_stack_obj).and_return(stack)
      allow(stack).to receive(:exists?).and_return(exists)
      allow(stack).to receive(:stack_id).and_return('stack_id')
      allow(stack).to receive(:stack_name).and_return('stack_name')
      allow(stack).to receive(:list_events).and_return('stack_name')
    end

    context 'when the stack exists' do
      let(:exists) { true }
      it 'is expected to call stack.delete' do
        expect(stack).to receive(:delete).with('stack_id', {})
        subject
      end
    end
  end
end
