# frozen_string_literal: true

RSpec.describe Redis::HourlyCounter do
  let(:mock_class) do
    Class.new do
      include Redis::Objects

      hourly_counter :pv, expiration: 86_400 # about a day

      def id
        1
      end
    end
  end

  let(:homepage) { Homepage.new }

  before do
    stub_const 'Homepage', mock_class
    Timecop.travel(Time.local(2021, 4, 1, 10))
    homepage.pv.increment(10)
    Timecop.travel(Time.local(2021, 4, 1, 11))
    homepage.pv.increment(11)
    Timecop.travel(Time.local(2021, 4, 1, 12))
    homepage.pv.increment(12)
  end

  context 'with global: true' do
    let(:mock_class) do
      Class.new do
        include Redis::Objects

        hourly_counter :pv, global: true
      end
    end

    let(:homepage) { Homepage }

    it 'supports class-level increment/decrement of global counters' do
      expect(homepage.redis.get('homepage::pv:2021-04-01T10').to_i).to eq 10
      expect(homepage.redis.get('homepage::pv:2021-04-01T11').to_i).to eq 11
      expect(homepage.redis.get('homepage::pv:2021-04-01T12').to_i).to eq 12
    end
  end

  describe 'timezone' do
    before { Timecop.travel(Time.local(2021, 4, 1, 13)) }

    context 'when Time class is extended by Active Support' do
      it do
        allow(Time).to receive(:current).and_return(Time.now)
        homepage.pv.increment(13)
        expect(Time).to have_received(:current).with(no_args)
      end
    end

    context 'when Time class is not extended by Active Support' do
      it do
        allow(Time).to receive(:now).and_return(Time.now)
        homepage.pv.increment(13)
        expect(Time).to have_received(:now).with(no_args)
      end
    end
  end

  describe 'keys' do
    it 'appends new counters automatically with the current date' do
      expect(homepage.redis.get('homepage:1:pv:2021-04-01T10').to_i).to eq 10
      expect(homepage.redis.get('homepage:1:pv:2021-04-01T11').to_i).to eq 11
      expect(homepage.redis.get('homepage:1:pv:2021-04-01T12').to_i).to eq 12
    end
  end

  describe '#value' do
    it 'returns the value counted today' do
      expect(homepage.pv.value).to eq 12
    end
  end

  describe '#[]' do
    context 'with date' do
      let(:date) { Time.local(2021, 4, 1, 10) }

      it 'returns the value counted the day' do
        expect(homepage.pv[date]).to eq 10
      end
    end

    context 'with date and length' do
      let(:date) { Time.local(2021, 4, 1, 11) }

      it 'returns the values counted within the duration' do
        expect(homepage.pv[date, 2]).to eq [11, 12]
      end
    end

    context 'with range' do
      let(:range) do
        Time.local(2021, 4, 1, 10)..Time.local(2021, 4, 1, 11)
      end

      it 'returns the values counted within the duration' do
        expect(homepage.pv[range]).to eq [10, 11]
      end
    end
  end

  describe '#delete' do
    it 'deletes the value on the day' do
      date = Time.local(2021, 4, 1, 11)
      expect { homepage.pv.delete(date) }
        .to change { homepage.pv.at(date) }
        .from(11).to(0)
    end
  end

  describe '#range' do
    let(:start_date) { Time.local(2021, 4, 1, 10) }
    let(:end_date) { Time.local(2021, 4, 1, 11) }

    it 'returns the values counted within the duration' do
      expect(homepage.pv.range(start_date, end_date)).to eq [10, 11]
    end
  end

  describe '#at' do
    let(:date) { Time.local(2021, 4, 1, 11) }

    it 'returns the value counted the day' do
      expect(homepage.pv.at(date)).to eq 11
    end
  end
end
