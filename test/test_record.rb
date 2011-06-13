require 'helper'
describe 'Record' do
  before do
    class Foo
      include  FightCSV::Record
    end
    @klass = Class.new.send(:include, FightCSV::Record)
  end

  describe 'create_attributes_hash' do
    it 'makes a active_record comptaible attributes hash' do
      @klass.csv_schema do field 'Foo',identifier: :foo  end
      instance = @klass.new(['bar'], data_source: FightCSV::DataSource.new(header: ['Foo']))
      instance.csv_set_attributes_hash
      assert_equal({'foo' => 'bar'}, instance.instance_variable_get(:@attributes))
    end
  end

  describe 'dynamic attributes' do
    before do
      @csv_schema = FightCSV::Schema.new
      @csv_schema.field('Foo', identifier: :foo)
      @csv_schema.field('Foz', identifier: :foz)
    end

    describe 'readers' do
      it 'works' do
        record = @klass.new(['Bar','Baz'], csv_schema: @csv_schema, data_source: FightCSV::DataSource.new(header: ['Foo', 'Foz']))
        assert_equal 'Bar', record.csv_foo
        assert_equal 'Baz', record.csv_foz
      end

      it 'returns nil if the attribute is not defined' do
        record = @klass.new(['Bar'], csv_schema: @csv_schema, data_source: FightCSV::DataSource.new(header: ['Foo']))
        assert_equal 'Bar', record.csv_foo
        assert_equal nil, record.csv_foz
      end

      it 'converts values if necessary' do
        @csv_schema.fields.find { |f| f.matcher == 'Foo' }.converter = proc { |value| value.downcase.to_sym }
        record = @klass.new(['Bar'], csv_schema: @csv_schema, data_source: FightCSV::DataSource.new(header: ['Foo']))
        assert_equal :bar, record.csv_foo
      end
    end
    describe 'writers' do
      it 'allow write access to attributes in the row' do
        record = @klass.new(['Bar'], csv_schema: @csv_schema, data_source: FightCSV::DataSource.new(header: ['Foo']))
        record.csv_foo = 4
        assert_equal 4, record.csv_foo
      end
    end
  end

  describe 'row' do
    it 'should zip the actual row and the header' do
      records = Foo.csv_from_parsed_data [{body: [%w{1 2 3},%w{2 3 4}], data_source: FightCSV::DataSource.new(header: ['a','b','c'])}]
      assert_equal Hash[[['a', '1'],['b','2'],['c','3']]], records.first.row
    end
  end

  describe 'from_files' do
    it 'reads in files, parses them and maps each row to a Record object' do
      records = Foo.csv_from_files [fixture('programming_languages.csv')]
      assert_equal Hash[[['Name', 'Ruby'],['Paradigms', 'object oriented,imperative,reflective,functional'],['Creator', 'Yukihiro Matsumoto']]], records.first.row
    end
  end

  describe 'from_parsed_data' do
    it 'maps each row of csv to a record model' do
      records = Foo.csv_from_parsed_data [{body: [%w{1 2 3},%w{2 3 4}], data_source: FightCSV::DataSource.new(header: ['a','b','c'])}]
      assert_equal Hash[[%w{a 1}, %w{b 2}, %w{c 3}]], records.first.row
    end
  end

  describe 'csv_schema csv_validation' do
    before do
      prog_lang_schema = fixture('prog_lang_schema.rb')
      @csv_schema = FightCSV::Schema.new
      @csv_schema.instance_eval { eval(File.read(prog_lang_schema)) }
      @prog_langs = Foo.csv_from_parsed_data FightCSV::Parser.from_files([fixture('programming_languages.csv')])
      @prog_langs.each { |prog_lang| prog_lang.csv_schema = @csv_schema }
    end

    describe 'csv_valid?' do
      it 'returns true if a record is csv_valid' do
        assert_equal true, @prog_langs.all?(&:csv_valid?)
      end
    end

    describe 'csv_validate' do
      it 'returns a hash includind csv_valid: true if the record is valid' do
        assert_equal({valid: true, errors: []}, @prog_langs.first.csv_validate)
      end

      it 'returns a hash inlcuding csv_valid: false and detailed error report' do
        data_source = FightCSV::DataSource.new(header: ['Name','Paradigms'])
        not_csv_valid_hash = {
          valid: false,
          errors: [
            ":creator is a required field"
        ]
        }
        assert_equal not_csv_valid_hash,
          Foo.new(['LOLCODE','lolfulness',nil], data_source: data_source, csv_schema: @csv_schema).csv_validate
      end
    end
  end

  describe 'csv_schema' do
    it 'accepts a file name' do
      @klass.csv_schema fixture('prog_lang_schema.rb')
      csv_schema = @klass.csv_schema
      assert_equal FightCSV::Schema, csv_schema.class
      assert_equal 'Name', csv_schema.fields.first.matcher
      assert_equal 'Creator', csv_schema.fields.last.matcher
    end

    it 'also responds to a block' do
      @klass.csv_schema do
        field 'Foo', required: true, identifier: :foo
      end

      csv_schema = @klass.csv_schema
      assert_equal 'Foo', csv_schema.fields.first.matcher
      assert_equal true, csv_schema.fields.first.required
    end
  end
end
