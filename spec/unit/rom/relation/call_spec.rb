require 'rom/relation'

RSpec.describe ROM::Relation, '#call' do
  subject(:relation) do
    relation_class.new(data)
  end

  context 'without read types in schema' do
    let(:relation_class) do
      Class.new(ROM::Relation[:memory]) do
        schema do
          attribute :id, ROM::Types::Int
          attribute :name, ROM::Types::String
        end
      end
    end

    let(:data) do
      [{ id: '1', name: 'Jane' }, { id: '2', name: 'John'} ]
    end

    it 'has noop read_schema' do
      expect(relation.read_schema).to be(ROM::Relation::NOOP_READ_SCHEMA)
    end

    it 'returns loaded relation with data' do
      expect(relation.call.collection).
        to eql(data)
    end
  end

  context 'with read types in schema' do
    let(:relation_class) do
      Class.new(ROM::Relation[:memory]) do
        schema do
          attribute :id, ROM::Types::String, read: ROM::Types::Coercible::Int
          attribute :name, ROM::Types::String
        end
      end
    end

    let(:data) do
      [{ id: '1', name: 'Jane' }, { id: '2', name: 'John'} ]
    end

    it 'returns loaded relation with coerced data' do
      expect(relation.call.collection).
        to eql([{ id: 1, name: 'Jane' }, { id: 2, name: 'John'} ])
    end
  end
end
