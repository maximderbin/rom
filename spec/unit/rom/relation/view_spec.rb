require 'rom'
require 'rom/memory'

RSpec.describe ROM::Relation do
  subject(:relation) { relation_class.new(ROM::Memory::Dataset.new([])) }

  shared_context 'relation with views' do
    before do
      relation << { id: 1, name: 'Joe' }
      relation << { id: 2, name: 'Jane' }
    end

    it 'uses projected schema for view schema' do
      expect(relation.schemas[:names].map(&:name)).to eql(%i[name])
    end

    it 'auto-projects the relation via schema' do
      new_rel = relation_class.new([{ name: 'Jane' }, { name: 'Joe' }])
      names_schema = relation_class.schemas[:names]

      expect(names_schema).to receive(:call).with(relation).and_return(new_rel)
      expect(relation.names).to eql(new_rel)
    end

    it 'auto-projects a restricted relation via schema' do
      new_rel = relation_class.new([{ id: 2 }])
      ids_schema = relation_class.schemas[:ids_for_names]

      expect(ids_schema).to receive(:call).with(relation.restrict(name: ['Jane'])).and_return(new_rel)
      expect(relation.ids_for_names(['Jane'])).to eql(new_rel)
    end
  end

  context 'with an explicit schema' do
    before do
      # this is normally called automatically during setup
      relation_class.finalize({}, relation)
    end

    include_context 'relation with views' do
      let(:relation_class) do
        Class.new(ROM::Memory::Relation) do
          schema(:users) do
            attribute :id, ROM::Types::Int
            attribute :name, ROM::Types::String
          end

          view(:names) do
            schema do
              project(:name)
            end

            relation do
              self
            end
          end

          view(:ids_for_names) do
            schema do
              project(:id)
            end

            relation do |names|
              restrict(name: names)
            end
          end
        end
      end
    end
  end

  context 'with an inferred schema' do
    before do
      # this is normally called automatically during setup
      relation_class.schema.finalize!
      relation_class.finalize({}, relation)
    end

    include_context 'relation with views' do
      let(:relation_class) do
        Class.new(ROM::Memory::Relation) do
          schema_inferrer -> dataset, gateway {
            [[ROM::Types::Int.meta(name: :id, source: :users),
             ROM::Types::String.meta(name: :name, source: :users)], []]
          }

          schema(:users, infer: true)

          view(:names) do
            schema do
              project(:name)
            end

            relation do
              self
            end
          end

          view(:ids_for_names) do
            schema do
              project(:id)
            end

            relation do |names|
              restrict(name: names)
            end
          end
        end
      end
    end
  end
end
