require_relative '../../spec_helper'
require_relative '../../shared/queue/deque'
require_relative '../../shared/types/rb_num2dbl_fails'

describe "SizedQueue#pop" do
  it_behaves_like :queue_deq, :pop, -> { SizedQueue.new(10) }
end

describe "SizedQueue operations with timeout" do
  it_behaves_like :rb_num2dbl_fails, nil, -> v { q = SizedQueue.new(10); q.push(1); q.pop(timeout: v) }
end
